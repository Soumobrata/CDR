# How it works

This project implements a **digital Clock and Data Recovery (CDR)** loop using a custom **open-loop VCO-ADC front-end** as a sampler.

- The **sampler** is based on a phase accumulator (VCO-ADC), which converts the 8-bit input (`ui_in[7:0]`) into sampled outputs.
- A **Mueller–Müller phase detector** computes timing error using symbol-spaced samples.
- A **PI loop filter** integrates the error to adjust a **digital controlled oscillator (DCO)**.
- The recovered symbol timing appears as:
  - `SAMPLE_EN` (1-cycle strobe, max 50 MHz)
  - `REC_CLK` (50% duty recovered clock, max 25 MHz)

For debug visibility, the sampler’s upper 6 bits (`x_n[7:2]`) are also mapped to outputs.

---

# How to test

1. **Inputs**  
   - Drive `ui_in[7:0]` with a test pattern or signal to be sampled.  
   - The design expects signed 8-bit values (−128…+127).  

2. **Outputs**  
   - `uo_out[0]` = `SAMPLE_EN` pulse (observe strobe rate).  
   - `uo_out[1]` = `REC_CLK` (observe 50% duty recovered clock).  
   - `uo_out[7:2]` = sampler outputs for debugging.  

3. **Basic check**  
   - Apply a slowly varying input on `ui_in`.  
   - Observe `uo_out[7:2]` reflecting the sampler conversion.  
   - Verify that `REC_CLK` toggles at a stable rate (set by the nominal FCW).  

4. **Advanced test**  
   - Provide a repetitive waveform on `ui_in` (e.g., PRBS pattern).  
   - Verify that the loop locks: `REC_CLK` becomes phase-aligned to input transitions.  

---

# External hardware

No external hardware is required.  
- Inputs can be toggled from the TinyTapeout board / microcontroller.  
- Outputs can be observed on logic analyzer or LEDs.  

Optional: map `REC_CLK` to a pin connected to an LED — you’ll see it blink faster/slower depending on FCW configuration.
