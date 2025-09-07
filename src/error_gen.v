// error_gen.v
module error_gen (
    input  signed [7:0] x_n,           // Sampled value from sampler
    input  signed [3:0] decoded,       // Decoded PAM4 level from quantizer
    output reg signed [7:0] s_n        // Sign output: +1, -1, or 0
);

    reg signed [7:0] error;

    always @(*) begin
        // Promote decoded to 8-bit signed before subtracting
        error = x_n - $signed(decoded);

        if (error > 0)
            s_n = 8'sd1;
        else if (error < 0)
            s_n = -8'sd1;
        else
            s_n = 8'sd0;
    end

endmodule

