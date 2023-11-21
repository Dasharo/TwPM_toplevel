BOARD ?= orangecrab
TOOLCHAIN ?= trellis
BUILD_DIR ?= build


SRC = twpm_top_$(BOARD).v verilog-lpc-module/lpc_periph.v verilog-tpm-fifo-registers/regs_module.v ram/r512x32_512x32.v
SRC += ddr3_controller/src_v/ddr3_dfi_seq.v ddr3_controller/src_v/ddr3_core.v ddr3_controller/src_v/phy/ecp5/ddr3_dfi_phy.v ddr3_wb.v ddr3_controller/examples/ecpix_ecp5/ecp5pll.sv
TOP = twpm_top
NEORV32_DIR = neorv32
NEORV32_WRAPPER = neorv32_wrapper_$(BOARD).vhd
NEXTPNR_ARGS = --seed 1 --top $(TOP) --json $(BUILD_DIR)/twpm.json --textcfg $(BUILD_DIR)/nextpnr.config
NEORV32_SRC = $(filter-out %neorv32_bootloader_image.vhd, $(wildcard $(NEORV32_DIR)/rtl/core/*.vhd) $(wildcard $(NEORV32_DIR)/rtl/core/mem/*.vhd))
LPF_FILE = $(BOARD).lpf


NEORV32_BOOTLOADER_ARGS += -DAUTO_BOOT_TIMEOUT=3

ifeq ($(BOARD),orangecrab)
NEXTPNR_ARGS += --25k --lpf orangecrab.lpf --package CSFBGA285 --ignore-loops
LPF_FILE = orangecrab.lpf

# Offset for firmware in SPI flash
NEORV32_BOOTLOADER_ARGS += -DSPI_BOOT_BASE_ADDR=0x80000
# Load firmware into D-MEM
NEORV32_BOOTLOADER_ARGS += -DEXE_BASE_ADDR=0x800000000

# Disable unused features to reduce space.
NEORV32_BOOTLOADER_ARGS += -DSTATUS_LED_EN=0
NEORV32_BOOTLOADER_ARGS += -DXIP_EN=0

# Silence warnings about logic loops in TRNG module, loops are where randomness comes from
YOSYS_ARGS=-w "found logic loop in module .*io_system_neorv32_trng_inst_true_neorv32_trng_inst"
endif

all: $(BUILD_DIR)/twpm.dfu

clean:
	@rm -rf $(BUILD_DIR)
	@make -C neorv32/sw/bootloader clean
	@find neorv32/sw -name '*.o' -exec rm '{}' \;

$(BUILD_DIR):
	@mkdir -p $@

$(BUILD_DIR)/neorv32: $(BUILD_DIR)
	@mkdir -p $@

.PHONY: $(BUILD_DIR)/bootloader.vhd
$(BUILD_DIR)/bootloader.vhd:
	@$(MAKE) -C neorv32/sw/bootloader bl_image USER_FLAGS="$(NEORV32_BOOTLOADER_ARGS)"
	@cp neorv32/sw/bootloader/neorv32_bootloader_image.vhd $@

ifeq ($(TOOLCHAIN),trellis)
$(BUILD_DIR)/neorv32.v: $(BUILD_DIR)/neorv32 $(NEORV32_SRC) $(BUILD_DIR)/bootloader.vhd $(NEORV32_WRAPPER)
	@ghdl -i --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 -Pbuild $(NEORV32_SRC) $(NEORV32_WRAPPER) $(BUILD_DIR)/bootloader.vhd
	@ghdl -m --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 neorv32_verilog_wrapper
	@ghdl synth --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 -Pbuild --out=verilog neorv32_verilog_wrapper > $@

$(BUILD_DIR)/build.ys $(BUILD_DIR)/twpm.json $(BUILD_DIR)/twpm_synth.v: $(SRC) $(BUILD_DIR)/neorv32.v
	@rm -f $@ $(BUILD_DIR)/build.ys
	@echo "read_verilog $^" >> $(BUILD_DIR)/build.ys
	@echo "synth_ecp5 -top $(TOP)" >> $(BUILD_DIR)/build.ys
	@echo "write_verilog $(BUILD_DIR)/twpm_synth.v" >> $(BUILD_DIR)/build.ys
	@echo "write_json $(BUILD_DIR)/twpm.json" >> $(BUILD_DIR)/build.ys
	@yosys $(YOSYS_ARGS) $(BUILD_DIR)/build.ys |& tee $(BUILD_DIR)/yosys.log

$(BUILD_DIR)/nextpnr.config: $(BUILD_DIR)/twpm.json $(LPF_FILE)
	@nextpnr-ecp5 $(NEXTPNR_ARGS) |& tee $(BUILD_DIR)/nextpnr.log

$(BUILD_DIR)/twpm.bit: $(BUILD_DIR)/nextpnr.config
	@ecppack  --bootaddr 0   --compress $< --svf $(BUILD_DIR)/twpm.svf --bit $@
else ifeq ($(TOOLCHAIN),diamond)
$(BUILD_DIR)/build.tcl: $(BUILD_DIR) $(NEORV32_SRC) $(NEORV32_WRAPPER) $(BUILD_DIR)/bootloader.vhd
	@echo "prj_project new -name twpm -impl $(BOARD) -dev LFE5U-25F-8MG285C -synthesis synplify" > $@
	@for file in $(SRC); do \
		echo "prj_src add -work twpm $$(readlink -f $$file)" >> $@; done
	@for file in $(NEORV32_SRC); do \
		echo "prj_src add -work neorv32 $$(readlink -f $$file)" >> $@; done
	@echo "prj_src add -work neorv32 $$(readlink -f $(BUILD_DIR)/bootloader.vhd)" >> $@
	@echo "prj_src add -work twpm $$(readlink -f $(NEORV32_WRAPPER))" >> $@
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
