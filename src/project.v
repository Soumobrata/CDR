// Wrapper so the stock TinyTapeout testbench (which expects tt_um_example) works.
module tt_um_example (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  tt_um_sfg_vcoadc_cdr dut (
    .ui_in (ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena   (ena),
    .clk   (clk),
    .rst_n (rst_n)
  );
endmodule

