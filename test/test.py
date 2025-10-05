import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test(dut):
    """Basic TT rules + recovered clock activity."""
    # 50 MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # init
    dut.rst_n.value = 0
    dut.ena.value   = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # hold reset 5 cycles
    for _ in range(5):
        await RisingEdge(dut.clk)

    # deassert reset, still disabled
    dut.rst_n.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    # While disabled: outputs and uio_oe must be 0
    assert int(dut.uo_out.value) == 0, f"uo_out not zero with ena=0: {dut.uo_out.value}"
    assert int(dut.uio_oe.value) == 0, f"uio_oe not zero with ena=0: {dut.uio_oe.value}"

    # Enable DUT
    dut.ena.value = 1

    # Drive a gentle signed ramp on ui_in for a while
    val = 0
    toggles = 0
    prev = (int(dut.uo_out.value) >> 1) & 1  # REC_CLK = uo_out[1]

    for _ in range(800):
        await RisingEdge(dut.clk)
        val = (val + 2) & 0xFF
        dut.ui_in.value = val

        cur = (int(dut.uo_out.value) >> 1) & 1
        if cur != prev:
            toggles += 1
            prev = cur

    # We expect the recovered clock to toggle at least once
    assert toggles > 0, "Recovered clock (uo_out[1]) did not toggle after enable"
