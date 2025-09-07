// quantizer.v
module quantizer (
    input  signed [7:0] x_n,           // sampled input
    output reg [1:0] d_n,              // 2-bit PAM4 symbol
    output reg signed [3:0] decoded    // PAM4 decoded level (-3 to +3)
);

    always @(*) begin
        if (x_n < -64) begin
            d_n = 2'b00;  // PAM4 level -3
            decoded = -3;
        end else if (x_n < 0) begin
            d_n = 2'b01;  // PAM4 level -1
            decoded = -1;
        end else if (x_n < 64) begin
            d_n = 2'b10;  // PAM4 level +1
            decoded = 1;
        end else begin
            d_n = 2'b11;  // PAM4 level +3
            decoded = 3;
        end
    end

endmodule


