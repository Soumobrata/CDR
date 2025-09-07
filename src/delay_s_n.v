module delay_s_n (
    input  wire               clk,   // connect clk_sample here
    input  wire               rst,
    input  wire signed [7:0]  in,
    output reg  signed [7:0]  out
);
    always @(posedge clk or posedge rst) begin
        if (rst) out <= 8'sd0;
        else     out <= in;
    end
endmodule
