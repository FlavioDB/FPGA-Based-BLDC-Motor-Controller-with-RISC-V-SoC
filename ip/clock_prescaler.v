// clock_prescaler.v
// Generates pwm_clk from clk_in
// pwm_clk = clk_in / (2 * (PRESCALE_FACTOR_N_PLUS_1))
// For clk_in = 27MHz, to get pwm_clk = 2.7MHz, we need division by 10.
// So, 2 * (PRESCALE_FACTOR_N_PLUS_1) = 10
// PRESCALE_FACTOR_N_PLUS_1 = 5
// Let parameter N = PRESCALE_FACTOR_N_PLUS_1 - 1 = 4

module clock_prescaler (
    input wire clk_in,      // System clock (e.g., 27MHz)
    input wire rst_n,       // Asynchronous reset, active low
    output reg pwm_clk_out  // Prescaled clock (e.g., 2.7MHz)
);

    // N determines the division factor: clk_in / (2 * (N + 1))
    // To get 2.7MHz from 27MHz (divide by 10):
    // 2 * (N + 1) = 10  => N + 1 = 5 => N = 4
    parameter N = 4;

    reg [$clog2(N):0] counter; // Counter needs to count from 0 to N

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            pwm_clk_out <= 1'b0; // Initialize clock output to a known state
        end else begin
            if (counter == N) begin
                counter <= 0;
                pwm_clk_out <= ~pwm_clk_out; // Toggle the output clock
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule