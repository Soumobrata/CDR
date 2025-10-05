
# Cocotb + Icarus
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Sources live at the REPO ROOT (not in src/)
ROOT_DIR := $(abspath $(PWD)/..)

# Build dir
SIM_BUILD = sim_build/rtl

# Verilog sources (root) + testbench (this folder)
VERILOG_SOURCES = \
  $(ROOT_DIR)/cdr.v \
  $(ROOT_DIR)/project.v \
  $(PWD)/tb.v

# Share include dir with DUT
COMPILE_ARGS += -I$(ROOT_DIR)

# DUT top for cocotb
TOPLEVEL = tb

# Name of the cocotb Python module (file test_cdr.py)
MODULE   = test_cdr

# JUnit XML in current folder
export COCOTB_RESULTS_FILE := results.xml

include $(shell cocotb-config --makefiles)/Makefile.sim
