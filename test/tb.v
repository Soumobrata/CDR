`default_nettype none
`timescale 1ns/1ps
module tb;
  reg  [7:0] ui_in  = 8'h00;
  wire [7:0] uo_out;
  reg  [7:0] uio_in = 8'h00;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg        ena    = 1'b0;
  reg        clk    = 1'b0;
  reg        rst_n  = 1'b0;

  // 50 MHz clock
  always #10 clk = ~clk;

  // Stock TT testbench expects tt_um_example → our wrapper provides it
  tt_um_example dut (
    .ui_in (ui_in), .uo_out(uo_out),
    .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
    .ena(ena), .clk(clk), .rst_n(rst_n)
  );
endmodule

