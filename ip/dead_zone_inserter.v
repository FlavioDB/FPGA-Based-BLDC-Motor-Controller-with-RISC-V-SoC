// dead_zone_inserter.v
// Top-level module for inserting dead zone into three PWM phases (U, V, W).

module dead_zone_inserter (
    input wire        clk,    // PWM clock
    input wire        rst_n,  // Asynchronous reset

    // From register_file or pwm_waveform_generator
    input wire [3:0]  dead_zone_value_in, // Global dead zone value for all phases

    // Ideal HS drive signals from pwm_waveform_generator
    input wire        ideal_hs_u_in,
    input wire        ideal_hs_v_in,
    input wire        ideal_hs_w_in,

    // Final outputs with dead time (to brake_logic)
    output wire       final_hs_u_out,
    output wire       final_ls_u_out,
    output wire       final_hs_v_out,
    output wire       final_ls_v_out,
    output wire       final_hs_w_out,
    output wire       final_ls_w_out
);

    // Instantiate dead_zone_channel for Phase U
    dead_zone_channel dzc_u (
        .clk(clk),
        .rst_n(rst_n),
        .dead_zone_cycles(dead_zone_value_in),
        .ideal_hs_in(ideal_hs_u_in),
        .final_hs_out(final_hs_u_out),
        .final_ls_out(final_ls_u_out)
    );

    // Instantiate dead_zone_channel for Phase V
    dead_zone_channel dzc_v (
        .clk(clk),
        .rst_n(rst_n),
        .dead_zone_cycles(dead_zone_value_in),
        .ideal_hs_in(ideal_hs_v_in),
        .final_hs_out(final_hs_v_out),
        .final_ls_out(final_ls_v_out)
    );

    // Instantiate dead_zone_channel for Phase W
    dead_zone_channel dzc_w (
        .clk(clk),
        .rst_n(rst_n),
        .dead_zone_cycles(dead_zone_value_in),
        .ideal_hs_in(ideal_hs_w_in),
        .final_hs_out(final_hs_w_out),
        .final_ls_out(final_ls_w_out)
    );

endmodule