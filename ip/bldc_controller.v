// bldc_controller.v
// Top-level module for the complete BLDC Controller IP.
// This module instantiates and connects all sub-modules.

module bldc_controller #(
    // Parameter for the base address of this peripheral.
    // This will be passed down to the icb_interface.
    parameter BASE_ADDR = 32'h1001_4000 
) (
    // System-level signals
    input wire clk,   // Main system clock (for ICB and control logic)
    input wire rst_n, // Asynchronous active-low reset

    // ICB Bus Interface (to E203 SoC fabric)
    input wire        icb_cmd_valid,
    output wire       icb_cmd_ready,
    input wire [31:0] icb_cmd_addr,
    input wire        icb_cmd_read,
    input wire [31:0] icb_cmd_wdata,
    
    output wire       icb_rsp_valid,
    input wire        icb_rsp_ready,
    output wire[31:0] icb_rsp_rdata,

    // Physical I/O signals (to FPGA pins)
    input wire        hw_brake_pin_in,  // From external brake button/signal
    //output            brake_interrupt_out, not used anymore
    
    output wire       final_pwm_hs_u_out, // To 6PWM driver board
    output wire       final_pwm_ls_u_out,
    output wire       final_pwm_hs_v_out,
    output wire       final_pwm_ls_v_out,
    output wire       final_pwm_hs_w_out,
    output wire       final_pwm_ls_w_out
);

    localparam MODE_STATIC = 2'b00;
    localparam MODE_PWM    = 2'b01;
    localparam MODE_SPWM   = 2'b10;

    // --- Internal Wires for Connecting Modules ---

    // Wires between icb_interface and register_file
    wire       reg_write_en_wire;
    wire [2:0] reg_addr_sel_wire;
    wire [31:0] reg_write_data_wire;
    wire [31:0] reg_read_data_muxed_wire;

    // Control signals from register_file to other modules
    wire [1:0] op_mode_out_wire;
    wire       direction_out_wire;
    wire       enable_motor_out_wire;
    wire       soft_reset_internal_out_wire;
    wire       sw_brake_enable_out_wire;
    wire [1:0] sw_brake_pattern_out_wire;
    wire       hw_brake_pin_enable_out_wire;
    wire [15:0] pwm_carrier_period_out_wire;
    wire [3:0]  dead_zone_value_out_wire;
    wire [15:0] commutation_step_period_out_wire;
    wire [15:0] pwm_duty_value_generic_out_wire;
    wire [15:0] spwm_phase_increment_out_wire;
    wire [7:0]  spwm_amplitude_global_out_wire;

    // Status signals from hardware to register_file
    wire       brake_active_hw_out_wire;
    wire [2:0] current_comm_state_hw_out_wire;
    wire [15:0] current_spwm_phase_u_hw_out_wire;

    // Data path signals between waveform generator, dead zone, and brake logic
    wire       ideal_hs_u_wire, ideal_hs_v_wire, ideal_hs_w_wire;
    wire       dz_hs_u_wire, dz_ls_u_wire;
    wire       dz_hs_v_wire, dz_ls_v_wire;
    wire       dz_hs_w_wire, dz_ls_w_wire;

    // Connecting spwm_engine to pwm_waveform_generator
    wire [15:0] spwm_oc_u_wire;
    wire [15:0] spwm_oc_v_wire;
    wire [15:0] spwm_oc_w_wire;


    // --- Module Instantiations ---

    // 1. ICB Interface (The Front Door)
    icb_interface #(
        .BASE_ADDR(BASE_ADDR)
    ) icb_interface_inst (
        .clk(clk),
        .rst_n(rst_n),
        .icb_cmd_valid(icb_cmd_valid),
        .icb_cmd_ready(icb_cmd_ready),
        .icb_cmd_addr(icb_cmd_addr),
        .icb_cmd_read(icb_cmd_read),
        .icb_cmd_wdata(icb_cmd_wdata),
        .icb_rsp_valid(icb_rsp_valid),
        .icb_rsp_ready(icb_rsp_ready),
        .icb_rsp_rdata(icb_rsp_rdata),
        .reg_write_en(reg_write_en_wire),
        .reg_addr_sel(reg_addr_sel_wire),
        .reg_write_data(reg_write_data_wire),
        .reg_read_data_muxed(reg_read_data_muxed_wire)
    );

    // 2. Register File (The Control Center)
    register_file register_file_inst (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write_en(reg_write_en_wire),
        .reg_addr_sel(reg_addr_sel_wire),
        .reg_write_data(reg_write_data_wire),
        .reg_read_data_muxed(reg_read_data_muxed_wire),
        // Status Inputs
        .brake_active_hw_in(brake_active_hw_out_wire),
        .motor_enabled_actual_hw_in(enable_motor_out_wire),
        .current_op_mode_hw_in(op_mode_out_wire),
        .current_comm_state_hw_in(current_comm_state_hw_out_wire),
        .current_spwm_phase_u_hw_in(current_spwm_phase_u_hw_out_wire), // Tie to 0 until SPWM is implemented
        // Control Outputs
        .op_mode_out(op_mode_out_wire),
        .direction_out(direction_out_wire),
        .enable_motor_out(enable_motor_out_wire),
        .soft_reset_internal_out(soft_reset_internal_out_wire),
        .sw_brake_enable_out(sw_brake_enable_out_wire),
        .sw_brake_pattern_out(sw_brake_pattern_out_wire),
        .hw_brake_pin_enable_out(hw_brake_pin_enable_out_wire),
        //.interrupt_out(brake_interrupt_out) not needed anymore
        .pwm_carrier_period_out(pwm_carrier_period_out_wire),
        .dead_zone_value_out(dead_zone_value_out_wire), // 4-bit output
        .commutation_step_period_out(commutation_step_period_out_wire),
        .pwm_duty_value_generic_out(pwm_duty_value_generic_out_wire),
        .spwm_phase_increment_out(spwm_phase_increment_out_wire),
        .spwm_amplitude_global_out(spwm_amplitude_global_out_wire)
    );

    // 6. SPWM Engine (The Sine Wave Calculator)
    spwm_engine spwm_engine_inst (
        .clk(clk),
        .rst_n(rst_n),
        // Enable only when motor is on AND in SPWM mode
        .enable(enable_motor_out_wire && (op_mode_out_wire == MODE_SPWM)),
        // Assemble the 32-bit config register from register file outputs
        .spwm_config_in({spwm_amplitude_global_out_wire, 8'h00, spwm_phase_increment_out_wire}),
        .pwm_period_in(pwm_carrier_period_out_wire),
        // Outputs to pwm_waveform_generator
        .oc_value_u(spwm_oc_u_wire),
        .oc_value_v(spwm_oc_v_wire),
        .oc_value_w(spwm_oc_w_wire),
        // Status output to register file
        .current_phase_u_out(current_spwm_phase_u_hw_out_wire)
    );

    // 3. PWM Waveform Generator (The Engine)
    pwm_waveform_generator pwm_gen_inst (
        .clk_pwm(clk),
        .rst_n(rst_n & ~soft_reset_internal_out_wire), // Reset on system reset OR soft reset
        .enable_motor_in(enable_motor_out_wire),
        .direction_in(direction_out_wire),
        .op_mode_in(op_mode_out_wire),
        .step_duration_period_in(commutation_step_period_out_wire),
        .pwm_carrier_period_in(pwm_carrier_period_out_wire),
        .generic_pwm_duty_val_in(pwm_duty_value_generic_out_wire),
        .spwm_oc_u_in(spwm_oc_u_wire),
        .spwm_oc_v_in(spwm_oc_v_wire),
        .spwm_oc_w_in(spwm_oc_w_wire),
        // Ideal HS Outputs
        .ideal_hs_u_out(ideal_hs_u_wire),
        .ideal_hs_v_out(ideal_hs_v_wire),
        .ideal_hs_w_out(ideal_hs_w_wire),
        // Status Outputs to Register File
        .commutation_state_out(current_comm_state_hw_out_wire)
    );

    // 4. Dead Zone Inserter (The Safety Guard)
    dead_zone_inserter dz_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dead_zone_value_in(dead_zone_value_out_wire), // 4-bit connection
        .ideal_hs_u_in(ideal_hs_u_wire),
        .ideal_hs_v_in(ideal_hs_v_wire),
        .ideal_hs_w_in(ideal_hs_w_wire),
        .final_hs_u_out(dz_hs_u_wire), .final_ls_u_out(dz_ls_u_wire),
        .final_hs_v_out(dz_hs_v_wire), .final_ls_v_out(dz_ls_v_wire),
        .final_hs_w_out(dz_hs_w_wire), .final_ls_w_out(dz_ls_w_wire)
    );

    // 5. Brake Logic (The Final Override)
    brake_logic brake_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pwm_hs_u_in(dz_hs_u_wire), .pwm_ls_u_in(dz_ls_u_wire),
        .pwm_hs_v_in(dz_hs_v_wire), .pwm_ls_v_in(dz_ls_v_wire),
        .pwm_hs_w_in(dz_hs_w_wire), .pwm_ls_w_in(dz_ls_w_wire),
        .sw_brake_enable_in(sw_brake_enable_out_wire),
        .sw_brake_pattern_in(sw_brake_pattern_out_wire),
        .hw_brake_pin_enable_in(hw_brake_pin_enable_out_wire),
        .hw_brake_pin_in(hw_brake_pin_in),
        .final_pwm_hs_u_out(final_pwm_hs_u_out), .final_pwm_ls_u_out(final_pwm_ls_u_out),
        .final_pwm_hs_v_out(final_pwm_hs_v_out), .final_pwm_ls_v_out(final_pwm_ls_v_out),
        .final_pwm_hs_w_out(final_pwm_hs_w_out), .final_pwm_ls_w_out(final_pwm_ls_w_out),
        .brake_active_status_out(brake_active_hw_out_wire)
    );

endmodule