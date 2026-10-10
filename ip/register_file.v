// register_file.v
// Holds configuration and status registers for the BLDC controller.
// Based on the refined 6-register map.

module register_file (
    input wire clk,         // System clock (for ICB access and internal logic)
    input wire rst_n,       // Asynchronous reset, active low

    // Interface to icb_interface module
    input wire        reg_write_en,       // Write enable for a register
    input wire [2:0]  reg_addr_sel,       // Decoded address bits selecting the register
                                          // (0x00 -> 3'b000, 0x04 -> 3'b001, ..., 0x14 -> 3'b101)
    input wire [31:0] reg_write_data,     // Data to be written
    output reg [31:0] reg_read_data_muxed,// Data to be read from selected register

    // --- Inputs for Status Register bits (from other hardware modules) ---
    input wire        brake_active_hw_in,
    input wire        motor_enabled_actual_hw_in, // Reflects the true state of motor operation
    input wire [1:0]  current_op_mode_hw_in,    // Actual op mode being run by waveform gen
    input wire [2:0]  current_comm_state_hw_in, // Actual 6-step commutation state
    input wire [15:0] current_spwm_phase_u_hw_in, // Example SPWM phase accumulator

    // --- Outputs to other modules (control signals derived from registers) ---
    // From CONTROL_REG
    output wire [1:0] op_mode_out,
    output wire       direction_out,
    output wire       enable_motor_out,
    output wire       soft_reset_internal_out, // Pulse
    output wire       sw_brake_enable_out,
    output wire [1:0] sw_brake_pattern_out,
    output wire       hw_brake_pin_enable_out,
    //output wire       interrupt_out, not needed anymore

    // From CARRIER_TIMING_REG
    output wire [15:0] pwm_carrier_period_out,
    output wire [3:0]  dead_zone_value_out,

    // From COMMUTATION_TIMING_REG
    output wire [15:0] commutation_step_period_out,

    // From PWM_DUTY_REG
    output wire [15:0] pwm_duty_value_generic_out,

    // From SPWM_CONFIG_REG
    output wire [15:0] spwm_phase_increment_out,
    output wire [7:0]  spwm_amplitude_global_out
);

    // Internal Register Declarations
    reg [31:0] REG_CONTROL;
    reg [31:0] REG_CARRIER_TIMING;
    reg [31:0] REG_COMMUTATION_TIMING;
    reg [31:0] REG_PWM_DUTY;
    reg [31:0] REG_SPWM_CONFIG;
    // STATUS_REG is Read-Only and constructed combinationally

    // Define register addresses (indices for reg_addr_sel)
    localparam ADDR_CONTROL             = 3'h0; // Offset 0x00
    localparam ADDR_CARRIER_TIMING      = 3'h1; // Offset 0x04
    localparam ADDR_COMMUTATION_TIMING  = 3'h2; // Offset 0x08
    localparam ADDR_PWM_DUTY            = 3'h3; // Offset 0x0C
    localparam ADDR_SPWM_CONFIG         = 3'h4; // Offset 0x10
    localparam ADDR_STATUS              = 3'h5; // Offset 0x14

    // Helper for soft_reset_internal_out pulse
    reg soft_reset_internal_pulse_reg;

    //wire for interrupting logic
    wire hw_brake_int_enable;

    // --- Register Write Logic (Synchronous) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values for all registers
            REG_CONTROL            <= 32'd0;
            REG_CARRIER_TIMING     <= {12'd0, 4'd5, 16'd256}; // Default DeadZone=5, CarrierPeriod=256
            REG_COMMUTATION_TIMING <= {16'd0, 16'd5000};    // Default CommutationStepPeriod=5000
            REG_PWM_DUTY           <= {16'd0, 16'd128};     // Default Duty=128 (50% if Carrier=256)
            REG_SPWM_CONFIG        <= {8'd128, 8'd0, 16'd10}; // Default Amp=128, PhaseInc=10
            soft_reset_internal_pulse_reg <= 1'b0;
        end else begin
            // De-assert single-cycle pulse for soft_reset
            if (soft_reset_internal_pulse_reg) begin
                soft_reset_internal_pulse_reg <= 1'b0;
            end

            if (reg_write_en) begin
                case (reg_addr_sel)
                    ADDR_CONTROL: begin
                        // Store incoming data, but always ensure bit 4 (soft_reset) is read as 0 in REG_CONTROL.
                        REG_CONTROL <= reg_write_data & ~(1'b1 << 4); 
                        if (reg_write_data[4]) begin // If CPU attempted to write '1' to soft_reset bit
                            soft_reset_internal_pulse_reg <= 1'b1; // Trigger the pulse
                        end
                    end
                    ADDR_CARRIER_TIMING:     REG_CARRIER_TIMING     <= reg_write_data;
                    ADDR_COMMUTATION_TIMING: REG_COMMUTATION_TIMING <= reg_write_data;
                    ADDR_PWM_DUTY:           REG_PWM_DUTY           <= reg_write_data;
                    ADDR_SPWM_CONFIG:        REG_SPWM_CONFIG        <= reg_write_data;
                    ADDR_STATUS:             ; // Read-Only, no write action
                    default: ; // No action for undefined addresses (should not happen if reg_addr_sel is only 3 bits)
                endcase
            end
        end
    end

    // --- Continuous Assignments for Control Outputs ---
    // From CONTROL_REG
    assign op_mode_out                 = REG_CONTROL[1:0];
    assign direction_out               = REG_CONTROL[2];
    assign enable_motor_out            = REG_CONTROL[3];
    assign soft_reset_internal_out     = soft_reset_internal_pulse_reg; // Output the generated pulse
    assign sw_brake_enable_out         = REG_CONTROL[5];
    assign sw_brake_pattern_out        = REG_CONTROL[7:6];
    assign hw_brake_pin_enable_out     = REG_CONTROL[8];
    //assign hw_brake_int_enable         = REG_CONTROL[9];
    //assign interrupt_out               = brake_active_hw_in & hw_brake_int_enable;

    // From CARRIER_TIMING_REG
    assign pwm_carrier_period_out      = REG_CARRIER_TIMING[15:0];
    assign dead_zone_value_out         = REG_CARRIER_TIMING[19:16];

    // From COMMUTATION_TIMING_REG
    assign commutation_step_period_out = REG_COMMUTATION_TIMING[15:0];

    // From PWM_DUTY_REG
    assign pwm_duty_value_generic_out  = REG_PWM_DUTY[15:0];

    // From SPWM_CONFIG_REG
    assign spwm_phase_increment_out    = REG_SPWM_CONFIG[15:0];
    assign spwm_amplitude_global_out   = REG_SPWM_CONFIG[31:24];


    // --- Register Read Logic (Combinational) ---
    always @(*) begin
        // The case statement must assign to reg_read_data_muxed in all branches
        // to avoid inferring a latch. The default case handles unmapped addresses.
        case (reg_addr_sel)
            ADDR_CONTROL:             reg_read_data_muxed = REG_CONTROL;
            ADDR_CARRIER_TIMING:      reg_read_data_muxed = REG_CARRIER_TIMING;
            ADDR_COMMUTATION_TIMING:  reg_read_data_muxed = REG_COMMUTATION_TIMING;
            ADDR_PWM_DUTY:            reg_read_data_muxed = REG_PWM_DUTY;
            ADDR_SPWM_CONFIG:         reg_read_data_muxed = REG_SPWM_CONFIG;
            ADDR_STATUS: begin
                // Construct the Status Register value directly into reg_read_data_muxed
                // Initialize all bits first to ensure no latches for unassigned bits within this scope
                reg_read_data_muxed = 32'b0; // Default to all zeros for this specific case branch

                reg_read_data_muxed[0]     = brake_active_hw_in;
                reg_read_data_muxed[1]     = motor_enabled_actual_hw_in;
                // Reserved [4:2] are already 0 due to the line above
                reg_read_data_muxed[6:5]   = current_op_mode_hw_in;
                reg_read_data_muxed[9:7]   = current_comm_state_hw_in;
                // Reserved [15:10] are already 0
                reg_read_data_muxed[31:16] = current_spwm_phase_u_hw_in;
            end
            default:                  reg_read_data_muxed = 32'hDEADBEEF; 
        endcase
    end

endmodule