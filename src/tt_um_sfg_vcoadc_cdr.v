// ========================== TOP ==========================
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

  // CDR core signals
  wire        sample_en;          // recovered clock strobe (1-cycle pulse)
  wire signed [7:0] x_n;          // sampler output
  wire        d_bb;
  wire [1:0]  d_q2;
  wire signed [31:0] v_ctrl;
  wire signed [31:0] dfcw;        // signed delta FCW

  // ---------------- CDR CORE ----------------
  // NOTE: FCW_NOM sets nominal strobe rate: f_s = f_clk * FCW_NOM / 2^PHASE_BITS
  // For 50 MHz clk and PHASE_BITS=32: 
  //   1 MHz  ->  85_899_345
  //   10 MHz -> 858_993_459
  //   25 MHz -> 2_147_483_648
  //   ~50 MHz-> 4_294_967_295 (avoid; leaves no headroom)
  cdr_core #(
    .PHASE_BITS      (32),
    .FCW_NOM         (32'd85_899_345),  // ~1 MHz nominal @ 50 MHz

    // VCO-ADC sampler configuration
    .SAMP_PHASE_BITS (24),
    .SAMP_FCW        (24'd8_388_608), // 2^23 baseline
    .GAIN_NUM        (1),
    .GAIN_SHIFT      (8),
    .X_SHIFT         (8),

    // Loop filter gains (PI)
    .KP_SHIFT        (6),
    .KI_SHIFT        (12),

    // v_ctrl -> ΔFCW scaling for DCO
    .DFCW_SHIFT      (18),

    // Optional clamp on ΔFCW to keep NCO in-range under all conditions
    .DFCW_CLAMP      (32'sd2_000_000)   // adjust as needed; 0 disables via code below
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

  // 50% duty recovered clock via T-FF toggled on sample_en
  reg rec_clk_ff;
  always @(posedge clk) begin
    if (rst | ~ena) rec_clk_ff <= 1'b0;
    else if (sample_en) rec_clk_ff <= ~rec_clk_ff;
  end

  // Outputs
  assign uo_out[0]   = active ? sample_en : 1'b0;     // strobe at f_s
  assign uo_out[1]   = active ? rec_clk_ff : 1'b0;    // ~f_s/2, 50% duty
  assign uo_out[7:2] = active ? x_n[7:2] : 6'h00;     // observe sampler

  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

endmodule

// ========================= CDR CORE ======================
module cdr_core #(
  // NCO/DCO
  parameter integer PHASE_BITS = 32,
  parameter [PHASE_BITS-1:0] FCW_NOM = 32'd85_899_345, // ~1 MHz @ 50 MHz clk

  // Sampler (VCO-ADC)
  parameter integer SAMP_PHASE_BITS = 24,
  parameter [SAMP_PHASE_BITS-1:0] SAMP_FCW = 24'd8_388_608,
  parameter integer GAIN_NUM   = 1,
  parameter integer GAIN_SHIFT = 8,
  parameter integer X_SHIFT    = 8,

  // Loop filter (PI)
  parameter integer KP_SHIFT = 6,
  parameter integer KI_SHIFT = 12,

  // v_ctrl -> ΔFCW scaling
  parameter integer DFCW_SHIFT = 18,

  // Optional clamp (absolute value) for dfcw after shifting
  // Set to 0 to disable clamping in this module.
  parameter signed [31:0] DFCW_CLAMP = 32'sd0
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

  // ---------------- NCO/DCO ----------------
  wire [PHASE_BITS-1:0] phase;

  // ---------------- Sampler ----------------
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

  // --------------- Quantizers ---------------
  quantizer_sign2b u_q (
    .x_n   (x_n),
    .d_bb  (d_bb),
    .d_q2  (d_q2)
  );

  // --------- MMPD (Mueller–Müller) ---------
  wire signed [15:0] f_n;
  mmpd_mueller u_pd (
    .clk       (clk),
    .rst       (rst),
    .sample_en (sample_en),
    .x_n       (x_n),
    .d_bb      (d_bb),
    .f_n       (f_n)
  );

  // ------------- Loop filter (PI) ----------
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

  // ---- v_ctrl -> ΔFCW  (signed mapping + optional clamp) ----
  wire signed [31:0] dfcw_raw = $signed(v_ctrl) >>> DFCW_SHIFT;

  wire signed [31:0] dfcw_limited =
      (DFCW_CLAMP == 0) ? dfcw_raw :
      (dfcw_raw >  DFCW_CLAMP) ?  DFCW_CLAMP :
      (dfcw_raw < -DFCW_CLAMP) ? -DFCW_CLAMP : dfcw_raw;

  assign dfcw = dfcw_limited;

  // --------------- NCO with saturation ---------------
  nco_dco #(
    .PHASE_BITS (PHASE_BITS)
  ) u_dco (
    .clk       (clk),
    .rst       (rst),
    .fcw_nom   (FCW_NOM),
    .dfcw      (dfcw[PHASE_BITS-1:0]), // width-match
    .phase     (phase),
    .sample_en (sample_en)
  );

endmodule

// -------- Sampler with CE: latches on sample_en ----------
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
    if (rst)           x_n <= 8'sd0;
    else if (sample_en) x_n <= x_next;   // capture only on recovered strobe
  end
endmodule

// ------------- Open-Loop VCO-ADC (sampler) --------------
module open_loop_vcoadc_fast #(
  parameter integer PHASE_BITS = 24,
  parameter [PHASE_BITS-1:0] FCW = 24'd8_388_608, // 2^23
  parameter integer GAIN_NUM   = 1,
  parameter integer GAIN_SHIFT = 8,
  parameter integer X_SHIFT    = 8
)(
  input  wire                     clk_sample,
  input  wire signed [7:0]        y_n,
  output reg  signed [7:0]        x_n
);
  localparam integer W = PHASE_BITS;

  // Stage 0: inc = sat(FCW + (GAIN_NUM * y_n) >>> GAIN_SHIFT)
  reg  [W-1:0] phi;
  wire signed [W:0] y_term      = ($signed(y_n) * GAIN_NUM) >>> GAIN_SHIFT;
  wire signed [W:0] inc_signed0 = $signed({1'b0, FCW}) + y_term;

  wire [W-1:0] inc0 =
      (inc_signed0 < 0)                         ? {W{1'b0}} :
      (inc_signed0 > $signed({1'b0,{W{1'b1}}})) ? {W{1'b1}} :
                                                  inc_signed0[W-1:0];

  reg [W-1:0] inc1;

  always @(posedge clk_sample) begin
    phi  <= phi + inc0;
    inc1 <= inc0; // pipeline register
  end

  // Stage 1: x_n = sat8( (inc - FCW) >>> X_SHIFT )
  wire signed [W:0] diff1 = $signed({1'b0, inc1}) - $signed({1'b0, FCW});
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

// ------------------ Quantizers --------------------------
module quantizer_sign2b (
  input  wire signed [7:0] x_n,
  output wire              d_bb,
  output wire [1:0]        d_q2
);
  assign d_bb = ~x_n[7]; // 1 if x_n >= 0

  // 2-bit graded decision
  wire neg = x_n[7];
  wire [6:0] mag = neg ? (~x_n[6:0] + 1'b1) : x_n[6:0];
  wire is_weak = (mag < 7'd8);
  assign d_q2 = neg ? (is_weak ? 2'b01 : 2'b00)
                    : (is_weak ? 2'b10 : 2'b11);
endmodule

// -------- Mueller–Müller PD (symbol-spaced) -------------
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

// ------------------- Loop Filter PI ---------------------
module loop_filter_pi #(
  parameter integer KP_SHIFT = 6,
  parameter integer KI_SHIFT = 12
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

// ================== NCO/DCO with SATURATION =============
// Saturates effective FCW to [0 .. 2^PHASE_BITS-1] so the NCO never runs
// backward or overflows even if dfcw is momentarily large.
module nco_dco #(
  parameter integer PHASE_BITS = 32
)(
  input  wire                          clk,
  input  wire                          rst,
  input  wire [PHASE_BITS-1:0]         fcw_nom,
  input  wire signed [PHASE_BITS-1:0]  dfcw,     // signed delta FCW
  output reg  [PHASE_BITS-1:0]         phase,
  output wire                          sample_en
);
  // Sign-extend to PHASE_BITS+1
  wire signed [PHASE_BITS:0] dfcw_ext       = {dfcw[PHASE_BITS-1], dfcw};
  wire signed [PHASE_BITS:0] fcw_nom_ext    = $signed({1'b0, fcw_nom});
  wire signed [PHASE_BITS:0] fcw_eff_signed = fcw_nom_ext + dfcw_ext;

  // Saturate effective FCW into legal range [0 .. 2^PHASE_BITS-1]
  wire [PHASE_BITS-1:0] fcw_eff =
      (fcw_eff_signed <= 0) ? {PHASE_BITS{1'b0}} :
      (fcw_eff_signed >  $signed({1'b0, {PHASE_BITS{1'b1}}})) ? {PHASE_BITS{1'b1}} :
       fcw_eff_signed[PHASE_BITS-1:0];

  // Accumulate phase with saturated FCW
  wire [PHASE_BITS:0] add = {1'b0, phase} + {1'b0, fcw_eff};

  assign sample_en = add[PHASE_BITS]; // carry-out = 1-cycle strobe

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= add[PHASE_BITS-1:0];
  end
endmodule

