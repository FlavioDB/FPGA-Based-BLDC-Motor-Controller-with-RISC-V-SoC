// brake_logic.v
// Overrides PWM signals with a brake pattern if brake is active.

module brake_logic (
    input wire        clk,     // System/PWM clock (may not be strictly needed if purely combinational)
    input wire        rst_n,   // For any registered status

    // Inputs from dead_zone_inserter.v
    input wire        pwm_hs_u_in,
    input wire        pwm_ls_u_in,
    input wire        pwm_hs_v_in,
    input wire        pwm_ls_v_in,
    input wire        pwm_hs_w_in,
    input wire        pwm_ls_w_in,

    // Inputs from register_file.v
    input wire        sw_brake_enable_in,
    input wire [1:0]  sw_brake_pattern_in, // 00: All Off, 01: All LS On, 10/11: Reserved (All Off)
    input wire        hw_brake_pin_enable_in,

    // Input from FPGA I/O
    input wire        hw_brake_pin_in,     // Assumed debounced if necessary

    // Outputs to FPGA I/O Pins
    output reg        final_pwm_hs_u_out,
    output reg        final_pwm_ls_u_out,
    output reg        final_pwm_hs_v_out,
    output reg        final_pwm_ls_v_out,
    output reg        final_pwm_hs_w_out,
    output reg        final_pwm_ls_w_out,

    // Output Status to register_file.v
    output wire       brake_active_status_out
);

    wire effective_hw_brake_active;
    wire final_brake_active;
    wire [1:0] current_brake_pattern;

    // Determine effective brake conditions
    assign effective_hw_brake_active = hw_brake_pin_in && hw_brake_pin_enable_in;
    assign final_brake_active        = sw_brake_enable_in || effective_hw_brake_active;
    assign brake_active_status_out   = final_brake_active; // Directly output status

    // Determine which brake pattern to use if brake is active
    // Priority: Software brake setting if sw_brake_enable_in is active.
    // Otherwise, if hardware brake is the sole cause, use a default (e.g., all LS ON).
    assign current_brake_pattern = sw_brake_enable_in ? sw_brake_pattern_in :
                                   (effective_hw_brake_active ? 2'b01 : 2'b00); // Default to All Off if no brake

    // Output logic (Combinational)
    always @(*) begin
        if (final_brake_active) begin
            case (current_brake_pattern)
                2'b00: begin // All Off (Coast)
                    final_pwm_hs_u_out = 1'b0; final_pwm_ls_u_out = 1'b0;
                    final_pwm_hs_v_out = 1'b0; final_pwm_ls_v_out = 1'b0;
                    final_pwm_hs_w_out = 1'b0; final_pwm_ls_w_out = 1'b0;
                end
                2'b01: begin // All HS Off / All LS On (Dynamic Brake)
                    final_pwm_hs_u_out = 1'b0; final_pwm_ls_u_out = 1'b1;
                    final_pwm_hs_v_out = 1'b0; final_pwm_ls_v_out = 1'b1;
                    final_pwm_hs_w_out = 1'b0; final_pwm_ls_w_out = 1'b1;
                end
                2'b10: begin // Reserved - Treat as All Off for safety
                    final_pwm_hs_u_out = 1'b0; final_pwm_ls_u_out = 1'b0;
                    final_pwm_hs_v_out = 1'b0; final_pwm_ls_v_out = 1'b0;
                    final_pwm_hs_w_out = 1'b0; final_pwm_ls_w_out = 1'b0;
                end
                2'b11: begin // Reserved - Treat as All Off for safety
                    final_pwm_hs_u_out = 1'b0; final_pwm_ls_u_out = 1'b0;
                    final_pwm_hs_v_out = 1'b0; final_pwm_ls_v_out = 1'b0;
                    final_pwm_hs_w_out = 1'b0; final_pwm_ls_w_out = 1'b0;
                end
                default: begin // Should not happen with 2-bit pattern, but for safety
                    final_pwm_hs_u_out = 1'b0; final_pwm_ls_u_out = 1'b0;
                    final_pwm_hs_v_out = 1'b0; final_pwm_ls_v_out = 1'b0;
                    final_pwm_hs_w_out = 1'b0; final_pwm_ls_w_out = 1'b0;
                end
            endcase
        end else begin
            // Pass through normal PWM signals
            final_pwm_hs_u_out = pwm_hs_u_in; final_pwm_ls_u_out = pwm_ls_u_in;
            final_pwm_hs_v_out = pwm_hs_v_in; final_pwm_ls_v_out = pwm_ls_v_in;
            final_pwm_hs_w_out = pwm_hs_w_in; final_pwm_ls_w_out = pwm_ls_w_in;
        end
    end

    // No sequential logic directly tied to clk/rst_n in this simple combinational version,
    // unless brake_active_status_out needed to be a latched status.
    // If brake_active_status_out needs to be registered:
    // reg brake_active_status_reg;
    // assign brake_active_status_out = brake_active_status_reg;
    // always @(posedge clk or negedge rst_n) begin
    //    if(!rst_n) brake_active_status_reg <= 1'b0;
    //    else brake_active_status_reg <= final_brake_active; // final_brake_active calculated combinationally
    // end
    // For now, making it a direct wire output is simpler.

endmodule