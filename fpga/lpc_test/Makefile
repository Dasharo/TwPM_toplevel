BOARD ?= orangecrab
TOOLCHAIN ?= trellis
BUILD_DIR ?= build


SRC = lpc_test.v
TOP = lpc_top
LPF_FILE = $(BOARD).lpf

NEXTPNR_ARGS = --seed 1 --top $(TOP) --json $(BUILD_DIR)/twpm.json --textcfg $(BUILD_DIR)/nextpnr.config


ifeq ($(BOARD),orangecrab)
# 50.4 MHz is actual frequency PLL produces when asked for 50 MHz on 48 MHz input.
NEXTPNR_ARGS += --25k --lpf orangecrab.lpf --package CSFBGA285 --ignore-loops --freq 50.4
LPF_FILE = orangecrab.lpf
endif

all: $(BUILD_DIR)/twpm.dfu

clean:
	@rm -rf $(BUILD_DIR)

$(BUILD_DIR):
	@mkdir -p $@


ifeq ($(TOOLCHAIN),trellis)
$(BUILD_DIR)/build.ys $(BUILD_DIR)/twpm.json $(BUILD_DIR)/twpm_synth.v: $(SRC)
	@mkdir -p $(BUILD_DIR)
	@rm -f $@ $(BUILD_DIR)/build.ys
	@echo "read_verilog $^" >> $(BUILD_DIR)/build.ys
	@echo "synth_ecp5 -top $(TOP)" >> $(BUILD_DIR)/build.ys
	@echo "write_verilog $(BUILD_DIR)/twpm_synth.v" >> $(BUILD_DIR)/build.ys
	@echo "write_json $(BUILD_DIR)/twpm.json" >> $(BUILD_DIR)/build.ys
	@yosys $(YOSYS_ARGS) $(BUILD_DIR)/build.ys |& tee $(BUILD_DIR)/yosys.log

$(BUILD_DIR)/nextpnr.config: $(BUILD_DIR)/twpm.json $(LPF_FILE)
	nextpnr-ecp5 $(NEXTPNR_ARGS) |& tee $(BUILD_DIR)/nextpnr.log

$(BUILD_DIR)/twpm.bit: $(BUILD_DIR)/nextpnr.config
	@ecppack  --bootaddr 0   --compress $< --svf $(BUILD_DIR)/twpm.svf --bit $@
else ifeq ($(TOOLCHAIN),diamond)
$(BUILD_DIR)/build.tcl: $(BUILD_DIR)
	@echo "prj_project new -name twpm -impl $(BOARD) -dev LFE5U-25F-8MG285C -synthesis synplify" > $@
	@for file in $(SRC); do \
		echo "prj_src add -work twpm $$(readlink -f $$file)" >> $@; done
	@for file in $(NEORV32_SRC); do \
		echo "prj_src add -work neorv32 $$(readlink -f $$file)" >> $@; done
	@echo "prj_impl option top $(TOP)" >> $@
# Save project file so that it can be opened using Diamond's GUI
	@echo "prj_project save" >> $@
	@echo "prj_run Synthesis -impl $(BOARD)" >> $@
	@echo "prj_run Translate -impl $(BOARD)" >> $@
	@echo "prj_run Map -impl $(BOARD)" >> $@
	@echo "prj_run PAR -impl $(BOARD)" >> $@
	@echo "prj_run Export -impl $(BOARD) -task Bitgen" >> $@


$(BUILD_DIR)/twpm.bit: $(BUILD_DIR)/build.tcl $(LPF_FILE)
	@cp $(LPF_FILE) $(BUILD_DIR)/twpm.lpf
	@(cd $(BUILD_DIR) && diamondc build.tcl)
	@cp $(BUILD_DIR)/$(BOARD)/twpm_$(BOARD).bit $@
else
$(error Unsupported toolchain "$(TOOLCHAIN)")
endif

$(BUILD_DIR)/twpm.dfu: $(BUILD_DIR)/twpm.bit
	@cp $< $@.temp
	@dfu-suffix -v 1209 -p 5bf0 -a $@.temp
	@mv $@.temp $@
