/*
 * Module: spwm_engine
 * Description: Top-level wrapper for the SPWM generator.
 *              It takes configuration from a single 32-bit register,
 *              generates three phase-shifted sine waves, scales them by
 *              amplitude, and converts them to final OC (duty cycle) values.
 */
module spwm_engine (
    // --- Inputs ---
    input wire           clk,
    input wire           rst_n,
    input wire           enable,
    input wire  [31:0]   spwm_config_in,      // Combined Freq/Amp register
    input wire  [15:0]   pwm_period_in,       // PWM timer period (e.g., 2700 for 1kHz @ 2.7MHz clk)

    // --- Outputs ---
    output wire [15:0]   oc_value_u,          // Final unsigned duty cycle for Phase U
    output wire [15:0]   oc_value_v,          // Final unsigned duty cycle for Phase V
    output wire [15:0]   oc_value_w,           // Final unsigned duty cycle for Phase W

    output wire [15:0]   current_phase_u_out
);

//================================================================
// 1. DECONSTRUCT INPUT REGISTER
//================================================================
wire [15:0] frequency_step = spwm_config_in[15:0];
wire [7:0]  amplitude      = spwm_config_in[31:24];

// Wire to receive the status from the phase generator
wire [15:0] phase_accumulator_status_wire;


//================================================================
// 2. INSTANTIATE THE PHASE GENERATOR
//================================================================
wire signed [8:0] sine_out_u_signed;
wire signed [8:0] sine_out_v_signed;
wire signed [8:0] sine_out_w_signed;

// This is the CORRECTED instantiation
spwm_phase_generator u_spwm_phase_gen (
    .clk               (clk),
    .rst_n             (rst_n),
    .enable            (enable),
    .frequency_step_in (frequency_step), // Input the frequency step

    .sine_out_u        (sine_out_u_signed),
    .sine_out_v        (sine_out_v_signed),
    .sine_out_w        (sine_out_w_signed),

    .current_phase_accumulator_out(phase_accumulator_status_wire)
);


//================================================================
// 3. FINAL SCALING AND BIASING LOGIC
//================================================================
// This section performs the math to convert the signed sine waves
// into final unsigned OC (duty cycle) values.

// Intermediate values for calculations. These need to be wide enough
// to hold the results of the multiplication.
// A 9-bit signed * 8-bit unsigned -> 17-bit signed result.
wire signed [16:0] scaled_sine_u, scaled_sine_v, scaled_sine_w;

// The normalized value after right-shifting by 8 bits.
// This brings it back to a signed 9-bit range.
wire signed [8:0] normalized_sine_u, normalized_sine_v, normalized_sine_w;

// The DC offset is half of the PWM period.
wire [15:0] dc_offset = pwm_period_in >> 1;

// Perform the amplitude scaling via multiplication
// Use $signed() to ensure the multiplication is a signed operation.
assign scaled_sine_u = sine_out_u_signed * $signed(amplitude);
assign scaled_sine_v = sine_out_v_signed * $signed(amplitude);
assign scaled_sine_w = sine_out_w_signed * $signed(amplitude);

// Normalize the scaled value by shifting right by 8 bits
// This is equivalent to dividing by 256.
assign normalized_sine_u = scaled_sine_u >>> 8; // Use arithmetic shift for signed numbers
assign normalized_sine_v = scaled_sine_v >>> 8;
assign normalized_sine_w = scaled_sine_w >>> 8;

// Add the DC offset to level-shift the wave into an unsigned range
// The result is the final duty cycle value.
assign oc_value_u = $signed(dc_offset) + normalized_sine_u;
assign oc_value_v = $signed(dc_offset) + normalized_sine_v;
assign oc_value_w = $signed(dc_offset) + normalized_sine_w;

assign current_phase_u_out = phase_accumulator_status_wire;


endmodule