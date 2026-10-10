// pwm_waveform_generator.v
// VERSION 2.0 - Corrected timer control logic.

module pwm_waveform_generator (
    input wire        clk_pwm,
    input wire        rst_n,
    
    // Control inputs
    input wire        enable_motor_in,
    input wire        direction_in,
    input wire [1:0]  op_mode_in,

    // Timer period settings
    input wire [15:0] step_duration_period_in,
    input wire [15:0] pwm_carrier_period_in,

    input wire [15:0] generic_pwm_duty_val_in,

    input wire [15:0] spwm_oc_u_in,
    input wire [15:0] spwm_oc_v_in,
    input wire [15:0] spwm_oc_w_in,

    // Outputs
    output reg ideal_hs_u_out,
    output reg ideal_hs_v_out,
    output reg ideal_hs_w_out,

    output wire [2:0] commutation_state_out
);

    localparam MODE_STATIC = 2'b00;
    localparam MODE_PWM    = 2'b01;
    
    localparam MODE_SPWM   = 2'b10;

    // Internal wires
    wire [15:0] internal_pwm_timer_count;
    wire        internal_step_period_match_tick;
    
    // *** FIX: Generate a one-cycle pulse to load timer periods ***
    reg  enable_motor_in_dly; // A delayed version of the enable signal
    wire load_new_timer_periods;

    always @(posedge clk_pwm or negedge rst_n) begin
        if (!rst_n)
            enable_motor_in_dly <= 1'b0;
        else
            enable_motor_in_dly <= enable_motor_in;
    end
    
    // Create a pulse when enable_motor_in goes from 0 to 1
    assign load_new_timer_periods = enable_motor_in & ~enable_motor_in_dly;

    assign commutation_state_out = commutation_state;

    // Instantiate Step Duration Timer
    main_timer step_timer (
        .clk(clk_pwm),
        .rst_n(rst_n),
        .enable(enable_motor_in && (op_mode_in == MODE_STATIC || op_mode_in == MODE_PWM)), 
        .load_period(load_new_timer_periods), // *** FIX: Connect to the generated pulse ***
        .period_value_in(step_duration_period_in),
        .timer_count_out(), 
        .period_match_tick(internal_step_period_match_tick)
    );

    // Instantiate PWM Carrier Timer
    main_timer pwm_carrier_timer (
        .clk(clk_pwm),
        .rst_n(rst_n),
        .enable(enable_motor_in && (op_mode_in == MODE_PWM || op_mode_in == MODE_SPWM)), 
        .load_period(load_new_timer_periods), // *** FIX: Connect to the generated pulse ***
        .period_value_in(pwm_carrier_period_in),
        .timer_count_out(internal_pwm_timer_count),
        .period_match_tick()
    );
    
    reg [2:0] commutation_state;

    // State Transition Logic for commutation_state (NO CHANGES HERE)
    always @(posedge clk_pwm or negedge rst_n) begin
        if (!rst_n) begin
            commutation_state <= 3'd0;
        end else begin
            if (enable_motor_in && (op_mode_in == MODE_STATIC || op_mode_in == MODE_PWM) ) begin
                if (internal_step_period_match_tick) begin 
                    if (!direction_in) begin // Forward
                        if (commutation_state == 3'd5) commutation_state <= 3'd0;
                        else commutation_state <= commutation_state + 1;
                    end else begin // Reverse
                        if (commutation_state == 3'd0) commutation_state <= 3'd5;
                        else commutation_state <= commutation_state - 1;
                    end
                end
            end
        end
    end

    // Output Logic (Combinational) (NO CHANGES HERE)
    always @(*) begin
        ideal_hs_u_out = 1'b0;
        ideal_hs_v_out = 1'b0;
        ideal_hs_w_out = 1'b0;

        if (enable_motor_in) begin
            case (op_mode_in)
                MODE_STATIC: begin
                    case (commutation_state)
                        3'd0: ideal_hs_u_out = 1'b1;
                        3'd1: ideal_hs_u_out = 1'b1;
                        3'd2: ideal_hs_v_out = 1'b1;
                        3'd3: ideal_hs_v_out = 1'b1;
                        3'd4: ideal_hs_w_out = 1'b1;
                        3'd5: ideal_hs_w_out = 1'b1;
                        default: ;
                    endcase
                end
                MODE_PWM: begin
                    case (commutation_state)
                        3'd0: ideal_hs_u_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        3'd1: ideal_hs_u_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        3'd2: ideal_hs_v_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        3'd3: ideal_hs_v_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        3'd4: ideal_hs_w_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        3'd5: ideal_hs_w_out = (internal_pwm_timer_count < generic_pwm_duty_val_in);
                        default: ;
                    endcase
                end
                MODE_SPWM: begin
                    ideal_hs_u_out = (internal_pwm_timer_count < spwm_oc_u_in);
                    ideal_hs_v_out = (internal_pwm_timer_count < spwm_oc_v_in);
                    ideal_hs_w_out = (internal_pwm_timer_count < spwm_oc_w_in);
                end
                default: ;
            endcase
        end
    end
endmodule