module sampler (
    clk_sample,
    y_n,
    x_n
);

    input clk_sample;
    input signed [7:0] y_n;
    output reg signed [7:0] x_n;

    always @(posedge clk_sample) begin
        x_n <= y_n;
    end

endmodule
