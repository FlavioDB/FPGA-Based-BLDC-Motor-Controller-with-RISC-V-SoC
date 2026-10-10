// main_timer.v
// VERSION 2.0 - Rewritten for robust and clear operation.

module main_timer (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire load_period,
    input wire [15:0] period_value_in,

    output reg [15:0] timer_count_out,
    output reg period_match_tick
);

    reg [15:0] current_period_val; // Internal storage for the period

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset to a known state
            timer_count_out    <= 16'd0;
            current_period_val <= 16'd0;
            period_match_tick  <= 1'b0;
        end else begin
            // Default behavior at every clock edge: tick goes low
            period_match_tick <= 1'b0;

            // Priority 1: Handle loading a new period value when requested.
            // This is independent of whether the timer is enabled.
            if (load_period) begin
                // Use a minimum period of 1 to prevent the timer from locking up
                if (period_value_in == 0) begin
                    current_period_val <= 1;
                end else begin
                    current_period_val <= period_value_in;
                end
            end

            // Priority 2: Handle counting logic based on the enable signal.
            if (enable) begin
                // The timer is active. Check if we have reached the end of the count.
                // It counts from 0 to (period - 1).
                if (timer_count_out >= current_period_val - 1) begin
                    timer_count_out <= 16'd0; // Wrap back to 0
                    if (current_period_val > 0) begin // Only tick if the period is valid
                        period_match_tick <= 1'b1;
                    end
                end else begin
                    // Not at the end, so just increment the counter.
                    timer_count_out <= timer_count_out + 1;
                end
            end else begin
                // If the timer is not enabled, keep its counter reset to 0.
                timer_count_out <= 16'd0;
            end
        end
    end

endmodule