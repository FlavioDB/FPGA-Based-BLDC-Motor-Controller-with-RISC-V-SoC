/*
 * Module: spwm_phase_generator
 * Description: Generates three phase-shifted, signed sine wave values.
 *              Uses a phase accumulator for frequency control and a quarter-wave
 *              sine ROM for wave shaping.
 */
module spwm_phase_generator (
    // --- Inputs ---
    input wire           clk,
    input wire           rst_n,
    input wire           enable,
    input wire  [15:0]   frequency_step_in,

    // --- Outputs ---
    output reg signed [8:0]  sine_out_u,
    output reg signed [8:0]  sine_out_v,
    output reg signed [8:0]  sine_out_w,

    output wire [15:0]       current_phase_accumulator_out
);

//================================================================
// 1. PHASE ACCUMULATOR & ANGLE GENERATION
//================================================================

// High-resolution phase accumulator
reg [31:0] phase_accumulator;

// On every clock cycle, add the frequency step if enabled
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phase_accumulator <= 32'd0;
    end else if (enable) begin
        phase_accumulator <= phase_accumulator + frequency_step_in;
    end
end

// The top 8 bits of the accumulator represent our 360-degree angle (0-255)
wire [7:0] angle_u;
wire [7:0] angle_v;
wire [7:0] angle_w;

// Define phase offsets for 120 and 240 degrees
localparam [7:0] PHASE_OFFSET_120 = 8'd85;  // 256 / 3
localparam [7:0] PHASE_OFFSET_240 = 8'd171; // 256 * 2 / 3

assign angle_u = phase_accumulator[31:24];
assign angle_v = angle_u + PHASE_OFFSET_120; // Addition will wrap around automatically
assign angle_w = angle_u + PHASE_OFFSET_240; // Addition will wrap around automatically

assign current_phase_accumulator_out = phase_accumulator[31:16];


//================================================================
// 2. SINE ROM INSTANTIATION
//================================================================

// Wires for communicating with the single Sine ROM
reg [5:0] rom_addr_u, rom_addr_v, rom_addr_w;
wire [7:0] rom_q_u, rom_q_v, rom_q_w;

// Instantiate the sine ROM three times conceptually. Synthesis will be smart
// and likely use one BRAM with three read ports if possible.
sine_rom sine_rom_u (.addr(rom_addr_u), .q(rom_q_u));
sine_rom sine_rom_v (.addr(rom_addr_v), .q(rom_q_v));
sine_rom sine_rom_w (.addr(rom_addr_w), .q(rom_q_w));


//================================================================
// 3. QUARTER-WAVE RECONSTRUCTION LOGIC
//================================================================
// This is a combinatorial block that calculates the final outputs
// based on the current angles.
always @(*) begin
    
    // Default assignments to prevent latches
    rom_addr_u = 6'd0;
    rom_addr_v = 6'd0;
    rom_addr_w = 6'd0;
    sine_out_u = 9'd0;
    sine_out_v = 9'd0;
    sine_out_w = 9'd0;

    //-------------------------------------------------
    // Phase U Logic
    //-------------------------------------------------
    // Use the top 2 bits of the angle to select the quadrant
    case (angle_u[7:6])
        // Quadrant 1 (0-89 deg): Read ROM forward, output is positive
        2'b00: begin
            rom_addr_u = angle_u[5:0];
            sine_out_u = rom_q_u; // Implicitly cast unsigned 8-bit to signed 9-bit
        end
        // Quadrant 2 (90-179 deg): Read ROM backward, output is positive
        2'b01: begin
            rom_addr_u = ~angle_u[5:0]; // Invert bits for mirror image
            sine_out_u = rom_q_u;
        end
        // Quadrant 3 (180-269 deg): Read ROM forward, output is negative
        2'b10: begin
            rom_addr_u = angle_u[5:0];
            sine_out_u = -rom_q_u; // Negate the value
        end
        // Quadrant 4 (270-359 deg): Read ROM backward, output is negative
        2'b11: begin
            rom_addr_u = ~angle_u[5:0];
            sine_out_u = -rom_q_u;
        end
        default: begin // Should not happen
            rom_addr_u = 6'd0;
            sine_out_u = 9'd0;
        end
    endcase


    //-------------------------------------------------
    // Phase V Logic
    //-------------------------------------------------
    case (angle_v[7:6])
        // Quadrant 1 (0-89 deg): Read ROM forward, output is positive
        2'b00: begin
            rom_addr_v = angle_v[5:0];
            sine_out_v = rom_q_v; // Implicitly cast unsigned 8-bit to signed 9-bit
        end
        // Quadrant 2 (90-179 deg): Read ROM backward, output is positive
        2'b01: begin
            rom_addr_v = ~angle_v[5:0]; // Invert bits for mirror image
            sine_out_v = rom_q_v;
        end
        // Quadrant 3 (180-269 deg): Read ROM forward, output is negative
        2'b10: begin
            rom_addr_v = angle_v[5:0];
            sine_out_v = -rom_q_v; // Negate the value
        end
        // Quadrant 4 (270-359 deg): Read ROM backward, output is negative
        2'b11: begin
            rom_addr_v = ~angle_v[5:0];
            sine_out_v = -rom_q_v;
        end
        default: begin // Should not happen
            rom_addr_v = 6'd0;
            sine_out_v = 9'd0;
        end
    endcase

    //-------------------------------------------------
    // Phase W Logic
    //-------------------------------------------------
    case (angle_w[7:6])
        // Quadrant 1 (0-89 deg): Read ROM forward, output is positive
        2'b00: begin
            rom_addr_w = angle_w[5:0];
            sine_out_w = rom_q_w; // Implicitly cast unsigned 8-bit to signed 9-bit
        end
        // Quadrant 2 (90-179 deg): Read ROM backward, output is positive
        2'b01: begin
            rom_addr_w = ~angle_w[5:0]; // Invert bits for mirror image
            sine_out_w = rom_q_w;
        end
        // Quadrant 3 (180-269 deg): Read ROM forward, output is negative
        2'b10: begin
            rom_addr_w = angle_w[5:0];
            sine_out_w = -rom_q_w; // Negate the value
        end
        // Quadrant 4 (270-359 deg): Read ROM backward, output is negative
        2'b11: begin
            rom_addr_w = ~angle_w[5:0];
            sine_out_w = -rom_q_w;
        end
        default: begin // Should not happen
            rom_addr_w = 6'd0;
            sine_out_w = 9'd0;
        end
    endcase


end

endmodule