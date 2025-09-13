![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Open-Loop VCO-ADC Front-End Sampler + All-Digital CDR (TinyTapeout)

**Top module:** `tt_um_sfg_vcoadc_cdr`  
**Shuttle target:** TinyTapeout (IHP open PDK) · **Tile size:** 1×1  
**Language:** Verilog-2001 · **Harness clock:** 50 MHz

This project is a **fully-digital Clock and Data Recovery (CDR)** front-end built around an **open-loop VCO-ADC sampler**. The sampler converts an 8-bit signed input into an 8-bit code using a digitally-controlled phase accumulator (VCO model), and the CDR locks symbol timing with a Mueller–Müller phase detector and a fixed-point PI loop filter. Everything is synchronous to the TinyTapeout harness clock—**no generated/gated clocks** leave the design; timing appears via a **one-cycle strobe** (`sample_en`) and a **50% duty recovered clock** derived by toggling on that strobe.

---

## Table of Contents

- [Block Diagram](#block-diagram)
- [Pinout](#pinout)
- [What You Get on the Pins](#what-you-get-on-the-pins)
- [Quick Start (Simulation & GDS)](#quick-start-simulation--gds)
- [Design Details](#design-details)
- [Tuning the Symbol Rate](#tuning-the-symbol-rate)
- [Area & Signoff Metrics](#area--signoff-metrics)
- [Repo Layout](#repo-layout)
- [Testing on Real Hardware](#testing-on-real-hardware)
- [Known Limitations / Notes](#known-limitations--notes)
- [License](#license)

---

## Block Diagram

