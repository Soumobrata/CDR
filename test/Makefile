
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
# Just basenames here
PROJECT_SOURCES = tt_um_sfg_vcoadc_cdr.v project.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD         = sim_build/rtl
VERILOG_SOURCES  += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD         = sim_build/gl
COMPILE_ARGS     += -DGL_TEST
COMPILE_ARGS     += -DFUNCTIONAL
COMPILE_ARGS     += -DSIM
VERILOG_SOURCES  += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES  += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# gate-level netlist from the flow:
VERILOG_SOURCES  += $(PWD)/gate_level_netlist.v

# add the WRAPPER so tb can bind tt_um_example -> gate-level top:
VERILOG_SOURCES  += $(SRC_DIR)/project.v
# (Do NOT add tt_um_sfg_vcoadc_cdr.v here to avoid RTL/GL double-definition.)

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS     += -I$(SRC_DIR)

# Testbench & cocotb entry
VERILOG_SOURCES  += $(PWD)/tb.v
TOPLEVEL = tb
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
