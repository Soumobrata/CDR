module cdr_top (
    input wire clk,               // System clock
    input wire rst,               // Reset
    input wire signed [7:0] y_n,  // Input signal
    output wire clk_sample,       // Recovered sampling clock
    output wire signed [31:0] v_ctrl, // Control output to VCO

    // Add these outputs for debugging/observation in testbench
    output wire signed [7:0] x_n,
    output wire [1:0] d_n,
    output wire signed [3:0] decoded,
    output wire signed [7:0] s_n,
    output wire signed [7:0] s_n1,
    output wire signed [3:0] d_n1,
    output wire signed [15:0] f_n
);

    // Internal wiring remains the same
    // All signals are directly connected to output ports

    // --- VCO ---
    vco vco_inst (
    .clk(clk),
    .rst(rst),
    .v_ctrl(v_ctrl),
    .clk_sample(clk_sample)
    );


    // --- Sampler ---
    sampler sampler_inst (
        .clk_sample(clk_sample),
        .y_n(y_n),
        .x_n(x_n)
    );

    // --- Quantizer ---
    quantizer quantizer_inst (
        .x_n(x_n),
        .d_n(d_n),
        .decoded(decoded)
    );

    // --- Error Generator ---
    error_gen error_gen_inst (
        .x_n(x_n),
        .decoded(decoded),
        .s_n(s_n)
    );

    // --- Delays ---
    delay_s_n s_delay (
        .clk(clk_sample),
        .rst(rst),
        .in(s_n),
        .out(s_n1)
    );

    delay_d_n d_delay (
        .clk(clk_sample),
        .rst(rst),
        .in(decoded),
        .out(d_n1)
    );

    // --- MMPD ---
    mmpd mmpd_inst (
        .s_n(s_n),
        .s_n1(s_n1),
        .d_n(decoded),
        .d_n1(d_n1),
        .f_n(f_n)
    );

    // --- Loop Filter ---
    loop_filter loop_filter_inst (
        .clk(clk_sample),
        .rst(rst),
        .f_n(f_n),
        .v_ctrl(v_ctrl)
    );

endmodule



