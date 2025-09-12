`default_nettype none
`timescale 1ns/1ps
module tb;
  // TT harness signals
  reg  [7:0] ui_in;
  wire [7:0] uo_out;
  reg  [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg        ena;
  reg        clk;
  reg        rst_n;

  // The stock TT tb instantiates tt_um_example, which our wrapper provides
  tt_um_example dut (
    .ui_in (ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena   (ena),
    .clk   (clk),
    .rst_n (rst_n)
  );

  // 50 MHz clock
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // simple toggle counter on recovered clock (uo_out[1])
  integer rec_toggles;
  reg rec_prev;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    // init
    ui_in   = 8'sd0;
    uio_in  = 8'h00;
    ena     = 1'b0;
    rst_n   = 1'b0;
    rec_toggles = 0;
    rec_prev    = 0;

    // hold reset a few cycles
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    // while disabled, outputs must be 0 and uio tri-stated
    repeat (5) @(posedge clk);
    if (uo_out !== 8'h00) begin
      $display("FAIL: uo_out not zero while ena=0 (got %02x)", uo_out);
      $finish(1);
    end
    if (uio_oe !== 8'h00) begin
      $display("FAIL: uio_oe not zero (got %02x)", uio_oe);
      $finish(1);
    end

    // enable design
    ena = 1'b1;

    // feed some signed stimulus on ui_in (slow ramp)
    repeat (64) begin
      @(posedge clk);
      ui_in <= ui_in + 8'sd2;
    end

    // observe recovered clock toggles for a while
    repeat (256) begin
      @(posedge clk);
      if (uo_out[1] !== rec_prev) rec_toggles = rec_toggles + 1;
      rec_prev = uo_out[1];

      // also ensure no X on outputs once enabled
      if (^uo_out === 1'bx) begin
        $display("FAIL: uo_out contains X after enable");
        $finish(1);
      end
    end

    if (rec_toggles == 0) begin
      $display("FAIL: recovered clock (uo_out[1]) did not toggle");
      $finish(1);
    end

    $display("PASS");
    $finish(0);
  end
endmodule

