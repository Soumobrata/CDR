
module vco #(
  parameter integer PHASE_BITS   = 32,
  // Reference and nominal target (integers; 10e9 and 5e9 here)
  parameter integer F_REF_HZ     = 10_000_000_000,
  parameter integer F_NOM_HZ     = 5_000_000_000,
  // Control word scaling (maps v_ctrl to frequency delta)
  // freq_inc = NOM_INC + ((v_ctrl >>> CTRL_SHIFT) * KVCO_NUM) >>> KVCO_SHIFT
  parameter integer CTRL_SHIFT   = 12,  // coarse divide of v_ctrl before KVCO
  parameter integer KVCO_NUM     = 1,   // numerator
  parameter integer KVCO_SHIFT   = 20   // overall KVCO scale (bigger → weaker)
)(
  input  wire               clk,        // 10 GHz ref
  input  wire               rst,
  input  wire signed [31:0] v_ctrl,     // control from loop filter
  output wire               clk_sample  // recovered sample clock (MSB)
);

  // 64-bit math to avoid overflow in constant calc
  localparam [63:0] TWO_PWR = 64'd1 << PHASE_BITS;
  localparam [63:0] NOM_INC = (TWO_PWR * F_NOM_HZ) / F_REF_HZ;

  reg [PHASE_BITS-1:0] phase;
  wire [PHASE_BITS-1:0] inc_nom = NOM_INC[PHASE_BITS-1:0];

  // Signed control delta (very small by default; tune KVCO_* to taste)
  wire signed [31:0] v_div    = $signed(v_ctrl) >>> CTRL_SHIFT;
  wire signed [63:0] kvco_mul = $signed(v_div) * $signed(KVCO_NUM);
  wire signed [63:0] kvco_shf = kvco_mul >>> KVCO_SHIFT;

  // Clamp delta to phase width
  wire signed [PHASE_BITS-1:0] inc_delta = kvco_shf[PHASE_BITS-1:0];

  wire [PHASE_BITS-1:0] inc = inc_nom + inc_delta;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      phase <= {PHASE_BITS{1'b0}};
    end else begin
      phase <= phase + inc;
    end
  end

  assign clk_sample = phase[PHASE_BITS-1];

endmodule






