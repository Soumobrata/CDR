# Cocotb + Icarus
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Sources live in ../src
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = cdr.v project.v

# RTL sim
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

# Share include dir with DUT
COMPILE_ARGS += -I$(SRC_DIR)

# Testbench + cocotb entry
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# <<< IMPORTANT: use a non-conflicting module name >>>
MODULE   = test_cdr

# Put the junit XML in the current directory (we're already in test/)
export COCOTB_RESULTS_FILE := results.xml

include $(shell cocotb-config --makefiles)/Makefile.sim
