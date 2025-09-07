
module delay_d_n (
    input  wire              clk,   // connect clk_sample here
    input  wire              rst,
    input  wire signed [3:0] in,    // decoded: ±3, ±1 (signed)
    output reg  signed [3:0] out
);
    always @(posedge clk or posedge rst) begin
        if (rst) out <= 4'sd0;
        else     out <= in;
    end
endmodule
