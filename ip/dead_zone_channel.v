// dead_zone_channel.v (Alternative with registered edge flags)
module dead_zone_channel (
    input wire        clk,
    input wire        rst_n,
    input wire [3:0]  dead_zone_cycles,
    input wire        ideal_hs_in,

    output reg        final_hs_out,
    output reg        final_ls_out
);

    reg ideal_hs_in_d1; // Stores ideal_hs_in from the previous cycle

    // Registered edge flags
    reg ideal_hs_rising_edge_r;
    reg ideal_hs_falling_edge_r;

    reg [3:0] hs_turn_on_delay_counter;
    reg [3:0] ls_turn_on_delay_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ideal_hs_in_d1 <= 1'b0;
            ideal_hs_rising_edge_r  <= 1'b0;
            ideal_hs_falling_edge_r <= 1'b0;

            final_hs_out   <= 1'b0;
            final_ls_out   <= 1'b0;
            hs_turn_on_delay_counter <= 8'd0;
            ls_turn_on_delay_counter <= 8'd0;
        end else begin
            // Update delayed input first
            ideal_hs_in_d1 <= ideal_hs_in;

            // Now calculate edge flags based on current ideal_hs_in and the ideal_hs_in_d1
            // that was just updated (which holds the value of ideal_hs_in from the PREVIOUS cycle)
            // This seems counter-intuitive because ideal_hs_in_d1 is on LHS of <= above,
            // but for RHS evaluation in the same clock tick, it uses the value before the update.
            // To be absolutely clear for this attempt, let's use the value ideal_hs_in_d1 HAD
            // at the START of this clock cycle for the edge detection.

            // Edge detection logic:
            // For ideal_hs_rising_edge_r: ideal_hs_in is 1, ideal_hs_in_d1 (from previous cycle) was 0.
            // For ideal_hs_falling_edge_r: ideal_hs_in is 0, ideal_hs_in_d1 (from previous cycle) was 1.
            ideal_hs_rising_edge_r  <= ideal_hs_in & ~ideal_hs_in_d1;
            ideal_hs_falling_edge_r <= ~ideal_hs_in & ideal_hs_in_d1;

            // --- High-Side Output Logic (using these new registered edge flags) ---
            if (ideal_hs_falling_edge_r) begin // This flag will be high one cycle AFTER the actual fall
                final_hs_out <= 1'b0;
                hs_turn_on_delay_counter <= 8'd0;
                if (dead_zone_cycles > 0) begin
                    ls_turn_on_delay_counter <= dead_zone_cycles;
                end else begin
                    final_ls_out <= 1'b1;
                    ls_turn_on_delay_counter <= 8'd0;
                end
            end else if (hs_turn_on_delay_counter > 0) begin
                hs_turn_on_delay_counter <= hs_turn_on_delay_counter - 1;
                if (hs_turn_on_delay_counter == 1) begin
                    final_hs_out <= 1'b1;
                end
            end

            // --- Low-Side Output Logic ---
            if (ideal_hs_rising_edge_r) begin // This flag will be high one cycle AFTER the actual rise
                final_ls_out <= 1'b0;
                ls_turn_on_delay_counter <= 8'd0;
                if (dead_zone_cycles > 0) begin
                    hs_turn_on_delay_counter <= dead_zone_cycles;
                end else begin
                    final_hs_out <= 1'b1;
                    hs_turn_on_delay_counter <= 8'd0;
                end
            end else if (ls_turn_on_delay_counter > 0) begin
                ls_turn_on_delay_counter <= ls_turn_on_delay_counter - 1;
                if (ls_turn_on_delay_counter == 1) begin
                    final_ls_out <= 1'b1;
                end
            end
        end
    end
endmodule