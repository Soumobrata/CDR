// mmpd_beta.v — MMPD Type-A with β-correction (per Musah & Namachivayam 2022)
// f[n] = (s[n-1]*d[n] - s[n]*d[n-1])/2 + beta * sign(d[n-1])*sign(d[n])

module mmpd #(
    // Enable/disable correction term
    parameter integer ENABLE_BETA = 1,

    // β scaling: corr = (BETA_NUM * zc) >>> BETA_SHIFT
    // For β ≈ 0.5 in the same units as the baseline term, try  BETA_NUM=1, BETA_SHIFT=1
    parameter integer BETA_NUM   = 1,
    parameter integer BETA_SHIFT = 1,

    // If your 2-bit PAM4 symbol's MSB encodes sign (0=neg,1=pos),
    // you can set USE_D_MSB=1 to derive sign(d) from d_sym[1] instead of "decoded".
    parameter integer USE_D_MSB  = 0
)(
    input  wire signed  [7:0]  s_n,
    input  wire signed  [7:0]  s_n1,
    input  wire        [1:0]   d_sym,    // 2-bit PAM4 symbol (00:-3, 01:-1, 10:+1, 11:+3)
    input  wire signed  [3:0]  d_n,      // decoded level (±3, ±1)
    input  wire signed  [3:0]  d_n1,     // delayed decoded level (±3, ±1)
    output wire signed [15:0]  f_n
);
    // --- Baseline proportional MMPD term: (s[n-1]*d[n] - s[n]*d[n-1]) / 2
    wire signed [15:0] p1 = $signed(s_n1) * $signed(d_n);
    wire signed [15:0] p2 = $signed(s_n)  * $signed(d_n1);
    wire signed [15:0] f_base = (p1 - p2) >>> 1;

    // --- sign(d) for correction term (choose source)
    // Using decoded level's sign is robust across mappings.
    wire signed [3:0] sign_dec   = (d_n  >= 0) ? 4'sd1 : -4'sd1;
    wire signed [3:0] sign_dec_1 = (d_n1 >= 0) ? 4'sd1 : -4'sd1;

    // Optional: use symbol MSB if it reflects sign (depends on your mapping)
    wire signed [3:0] sign_sym   = (d_sym[1]  ? 4'sd1 : -4'sd1);
    // For the delayed symbol, pass it in if available; else keep decoded-based
    // (You already have d_n1, so we stay with decoded for delayed path.)

    wire signed [3:0] s_now  = (USE_D_MSB ? sign_sym : sign_dec);
    wire signed [3:0] s_prev = sign_dec_1;

    // zc = sign(d[n-1]) * sign(d[n]) ∈ {−1, +1} (0 not expected for PAM4)
    wire signed [7:0] zc = $signed(s_prev) * $signed(s_now);

    // β * zc  (scale to match f_base units; keep headroom within 16b)
    wire signed [15:0] corr_unscaled = $signed(BETA_NUM) * $signed({{8{zc[7]}}, zc}); // extend zc
    wire signed [15:0] corr = (ENABLE_BETA != 0) ? (corr_unscaled >>> BETA_SHIFT) : 16'sd0;

    assign f_n = f_base + corr;
endmodule



