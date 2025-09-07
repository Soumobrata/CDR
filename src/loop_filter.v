
module loop_filter #(
    // Gains in Q format (tune to taste)
    parameter signed [15:0] KP       = 16'sd64,  // ~0.5 if SHIFT_P=7
    parameter integer       SHIFT_P  = 7,
    parameter signed [15:0] KI       = 16'sd4,   // ~0.03125 if SHIFT_I=7
    parameter integer       SHIFT_I  = 7,

    // Clamps (edit as needed for your VCO range)
    parameter signed [31:0] V_MIN    = -32'sd100000000,
    parameter signed [31:0] V_MAX    =  32'sd100000000,
    parameter signed [31:0] I_MIN    = -32'sd100000000,
    parameter signed [31:0] I_MAX    =  32'sd100000000,

    // Optional integrator leak: 0 = off; N>0 adds -I>>N each tick
    parameter integer       LEAK_SH  = 0
)(
    input  wire               clk,       // use clk_sample here
    input  wire               rst,
    input  wire signed [15:0] f_n,       // PD output
    output reg  signed [31:0] v_ctrl     // control word to VCO
);

    reg  signed [31:0] i_accum;

    // P and I terms (scaled)
    wire signed [31:0] p_term   = $signed(KP) * $signed(f_n);
    wire signed [31:0] p_term_s = p_term >>> SHIFT_P;
    wire signed [31:0] i_inc    = ($signed(KI) * $signed(f_n)) >>> SHIFT_I;

    // Helpers
    function signed [31:0] clip32;
        input signed [63:0] v;
        input signed [31:0] vmin, vmax;
        begin
            if (v >  $signed(vmax)) clip32 = vmax;
            else if (v < $signed(vmin)) clip32 = vmin;
            else clip32 = v[31:0];
        end
    endfunction

    // Anti-windup: decide if we should integrate this cycle
    function should_integrate;
        input signed [31:0] i_now;
        input signed [31:0] i_add;
        input signed [31:0] p_now;
        reg   signed [31:0] i_try, v_try;
        begin
            i_try = clip32($signed(i_now) + $signed(i_add), I_MIN, I_MAX);
            v_try = clip32($signed(i_try) + $signed(p_now), V_MIN, V_MAX);
            // If output is already at a rail and i_add pushes further, skip
            if ((v_try == V_MAX && i_add > 0) || (v_try == V_MIN && i_add < 0))
                should_integrate = 1'b0;
            else
                should_integrate = 1'b1;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i_accum <= 32'sd0;
            v_ctrl  <= 32'sd0;
        end else if (^f_n === 1'bx) begin
            // PD unknown: hold state (prevents poisoning from X)
            i_accum <= i_accum;
            v_ctrl  <= v_ctrl;
        end else begin
            // Optional leak
            if (LEAK_SH > 0)
                i_accum <= clip32($signed(i_accum) - ($signed(i_accum) >>> LEAK_SH), I_MIN, I_MAX);
            else
                i_accum <= i_accum;

            // Conditional integration (anti-windup)
            if (should_integrate(i_accum, i_inc, p_term_s))
                i_accum <= clip32($signed(i_accum) + $signed(i_inc), I_MIN, I_MAX);

            // Output clamp
            v_ctrl <= clip32($signed(i_accum) + $signed(p_term_s), V_MIN, V_MAX);
        end
    end
endmodule



