module tt_um_sfg_vcoadc_cdr (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire rst    = ~rst_n;
  wire active = ena & ~rst;

  wire signed [7:0] y_n = ui_in;

  wire        sample_en;
  wire signed [7:0] x_n;
  wire        d_bb;
  wire [1:0]  d_q2;
  wire signed [31:0] v_ctrl;
  wire signed [31:0] dfcw;

  cdr_core #(
    .PHASE_BITS      (32),
    .FCW_NOM         (32'hFF00_0000),
    .SAMP_PHASE_BITS (24),
    .SAMP_FCW        (24'd8_388_608),
    .GAIN_NUM        (1),
    .GAIN_SHIFT      (8),
    .X_SHIFT         (8),
    .KP_SHIFT        (12),
    .KI_SHIFT        (18),
    .DFCW_SHIFT      (24),
    .DFCW_CLAMP      (32'sd16000000)
  ) u_cdr (
    .clk       (clk),
    .rst       (rst | ~ena),
    .y_n       (active ? y_n : 8'sd0),
    .sample_en (sample_en),
    .x_n       (x_n),
    .d_bb      (d_bb),
    .d_q2      (d_q2),
    .v_ctrl    (v_ctrl),
    .dfcw      (dfcw)
  );

  reg rec_clk_ff;
  always @(posedge clk) begin
    if (rst | ~ena) rec_clk_ff <= 1'b0;
    else if (sample_en) rec_clk_ff <= ~rec_clk_ff;
  end

  assign uo_out[0]   = active ? sample_en : 1'b0;
  assign uo_out[1]   = active ? rec_clk_ff : 1'b0;
  assign uo_out[7:2] = active ? x_n[7:2] : 6'h00;

  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

endmodule

module cdr_core #(
  parameter integer PHASE_BITS = 32,
  parameter [PHASE_BITS-1:0] FCW_NOM = 32'hFF00_0000,
  parameter integer SAMP_PHASE_BITS = 24,
  parameter [SAMP_PHASE_BITS-1:0] SAMP_FCW = 24'd8_388_608,
  parameter integer GAIN_NUM   = 1,
  parameter integer GAIN_SHIFT = 8,
  parameter integer X_SHIFT    = 8,
  parameter integer KP_SHIFT = 12,
  parameter integer KI_SHIFT = 18,
  parameter integer DFCW_SHIFT = 24,
  parameter signed [31:0] DFCW_CLAMP = 32'sd16000000
)(
  input  wire               clk,
  input  wire               rst,
  input  wire signed [7:0]  y_n,
  output wire               sample_en,
  output wire signed [7:0]  x_n,
  output wire               d_bb,
  output wire [1:0]         d_q2,
  output wire signed [31:0] v_ctrl,
  output wire signed [31:0] dfcw
);

  wire [PHASE_BITS-1:0] phase;

  sampler_ce #(
    .PHASE_BITS (SAMP_PHASE_BITS),
    .FCW        (SAMP_FCW),
    .GAIN_NUM   (GAIN_NUM),
    .GAIN_SHIFT (GAIN_SHIFT),
    .X_SHIFT    (X_SHIFT)
  ) u_samp (
    .clk       (clk),
    .rst       (rst),
    .sample_en (sample_en),
    .y_n       (y_n),
    .x_n       (x_n)
  );

  quantizer_sign2b u_q (
    .x_n   (x_n),
    .d_bb  (d_bb),
    .d_q2  (d_q2)
  );

  wire signed [15:0] f_n;
  mmpd_mueller u_pd (
    .clk       (clk),
    .rst       (rst),
    .sample_en (sample_en),
    .x_n       (x_n),
    .d_bb      (d_bb),
    .f_n       (f_n)
  );

  loop_filter_pi #(
    .KP_SHIFT (KP_SHIFT),
    .KI_SHIFT (KI_SHIFT)
  ) u_lpf (
    .clk    (clk),
    .rst    (rst),
    .en     (sample_en),
    .f_n    (f_n),
    .v_ctrl (v_ctrl)
  );

  wire signed [31:0] dfcw_raw = $signed(v_ctrl) >>> DFCW_SHIFT;
  wire signed [31:0] dfcw_limited =
      (DFCW_CLAMP == 0) ? dfcw_raw :
      (dfcw_raw >  DFCW_CLAMP) ?  DFCW_CLAMP :
      (dfcw_raw < -DFCW_CLAMP) ? -DFCW_CLAMP : dfcw_raw;
  assign dfcw = dfcw_limited;

  nco_dco #(
    .PHASE_BITS (PHASE_BITS)
  ) u_dco (
    .clk       (clk),
    .rst       (rst),
    .fcw_nom   (FCW_NOM),
    .dfcw      (dfcw[PHASE_BITS-1:0]),
    .phase     (phase),
    .sample_en (sample_en)
  );

endmodule

module sampler_ce #(
  parameter integer PHASE_BITS = 24,
  parameter [PHASE_BITS-1:0] FCW = 24'd8_388_608,
  parameter integer GAIN_NUM   = 1,
  parameter integer GAIN_SHIFT = 8,
  parameter integer X_SHIFT    = 8
)(
  input  wire               clk,
  input  wire               rst,
  input  wire               sample_en,
  input  wire signed [7:0]  y_n,
  output reg  signed [7:0]  x_n
);
  wire signed [7:0] x_next;

  open_loop_vcoadc_fast #(
    .PHASE_BITS (PHASE_BITS),
    .FCW        (FCW),
    .GAIN_NUM   (GAIN_NUM),
    .GAIN_SHIFT (GAIN_SHIFT),
    .X_SHIFT    (X_SHIFT)
  ) core (
    .clk_sample (clk),
    .y_n        (y_n),
    .x_n        (x_next)
  );

  always @(posedge clk) begin
    if (rst)         x_n <= 8'sd0;
    else if (sample_en) x_n <= x_next;
  end
endmodule

module open_loop_vcoadc_fast #(
  parameter integer PHASE_BITS = 24,
  parameter [PHASE_BITS-1:0] FCW = 24'd8_388_608,
  parameter integer GAIN_NUM   = 1,
  parameter integer GAIN_SHIFT = 8,
  parameter integer X_SHIFT    = 8
)(
  input  wire                     clk_sample,
  input  wire signed [7:0]        y_n,
  output reg  signed [7:0]        x_n
);
  localparam integer W = PHASE_BITS;

  reg  [W-1:0] phi;
  wire signed [W:0] y_term      = ( $signed(y_n) * GAIN_NUM ) >>> GAIN_SHIFT;
  wire signed [W:0] inc_signed0 = $signed({1'b0, FCW}) + y_term;

  wire [W-1:0] inc0 =
      (inc_signed0 < 0)                          ? {W{1'b0}} :
      (inc_signed0 > $signed({1'b0,{W{1'b1}}}))  ? {W{1'b1}} :
                                                   inc_signed0[W-1:0];

  reg [W-1:0] inc1;

  always @(posedge clk_sample) begin
    phi  <= phi + inc0;
    inc1 <= inc0;
  end

  wire signed [W:0] diff1 = $signed({1'b0,inc1}) - $signed({1'b0,FCW});
  wire signed [W:0] shr1  = (X_SHIFT > 0) ? (diff1 >>> X_SHIFT) : diff1;

  wire signed [15:0] narrowed =
      (shr1 >  $signed(16'sh7FFF)) ? 16'sh7FFF :
      (shr1 < -$signed(16'sh8000)) ? -16'sh8000 : shr1[15:0];

  always @(posedge clk_sample) begin
    x_n <= (narrowed >  16'sd127) ? 8'sd127 :
           (narrowed < -16'sd128) ? -8'sd128 :
                                     narrowed[7:0];
  end
endmodule

module quantizer_sign2b (
  input  wire signed [7:0] x_n,
  output wire              d_bb,
  output wire [1:0]        d_q2
);
  assign d_bb = ~x_n[7];
  wire neg = x_n[7];
  wire [6:0] mag = neg ? (~x_n[6:0] + 1'b1) : x_n[6:0];
  wire is_weak = (mag < 7'd8);
  assign d_q2 = neg ? (is_weak ? 2'b01 : 2'b00)
                    : (is_weak ? 2'b10 : 2'b11);
endmodule

module mmpd_mueller (
  input  wire               clk,
  input  wire               rst,
  input  wire               sample_en,
  input  wire signed [7:0]  x_n,
  input  wire               d_bb,
  output reg  signed [15:0] f_n
);
  reg signed [7:0]  x_z1;
  reg               d_z1;

  wire signed [1:0] d_now = d_bb ? 2'sd1 : -2'sd1;
  wire signed [1:0] d_p1  = d_z1 ?  2'sd1 : -2'sd1;

  always @(posedge clk) begin
    if (rst) begin
      x_z1 <= 8'sd0;
      d_z1 <= 1'b0;
      f_n  <= 16'sd0;
    end else if (sample_en) begin
      f_n  <= $signed(d_now) * $signed(x_z1) - $signed(d_p1) * $signed(x_n);
      x_z1 <= x_n;
      d_z1 <= d_bb;
    end
  end
endmodule

module loop_filter_pi #(
  parameter integer KP_SHIFT = 12,
  parameter integer KI_SHIFT = 18
)(
  input  wire               clk,
  input  wire               rst,
  input  wire               en,
  input  wire signed [15:0] f_n,
  output reg  signed [31:0] v_ctrl
);
  reg signed [31:0] sum_f;

  wire signed [31:0] p_term = $signed(f_n) >>> KP_SHIFT;
  wire signed [31:0] i_term = sum_f       >>> KI_SHIFT;

  always @(posedge clk) begin
    if (rst) begin
      sum_f  <= 32'sd0;
      v_ctrl <= 32'sd0;
    end else if (en) begin
      sum_f  <= sum_f + $signed({{16{f_n[15]}}, f_n});
      v_ctrl <= v_ctrl + p_term + i_term;
    end
  end
endmodule

module nco_dco #(
  parameter integer PHASE_BITS = 32
)(
  input  wire                          clk,
  input  wire                          rst,
  input  wire [PHASE_BITS-1:0]         fcw_nom,
  input  wire signed [PHASE_BITS-1:0]  dfcw,
  output reg  [PHASE_BITS-1:0]         phase,
  output wire                          sample_en
);
  wire signed [PHASE_BITS:0] dfcw_ext       = {dfcw[PHASE_BITS-1], dfcw};
  wire signed [PHASE_BITS:0] fcw_nom_ext    = $signed({1'b0, fcw_nom});
  wire signed [PHASE_BITS:0] fcw_eff_signed = fcw_nom_ext + dfcw_ext;

  wire [PHASE_BITS-1:0] fcw_eff =
      (fcw_eff_signed <= 0) ? {PHASE_BITS{1'b0}} :
      (fcw_eff_signed >  $signed({1'b0, {PHASE_BITS{1'b1}}})) ? {PHASE_BITS{1'b1}} :
       fcw_eff_signed[PHASE_BITS-1:0];

  wire [PHASE_BITS:0] add = {1'b0, phase} + {1'b0, fcw_eff};

  assign sample_en = add[PHASE_BITS];

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= add[PHASE_BITS-1:0];
  end
endmodule
