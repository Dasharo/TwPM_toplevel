BOARD ?= orangecrab
TOOLCHAIN ?= trellis
BUILD_DIR ?= build


TOP = top
NEORV32_DIR = neorv32
NEORV32_WRAPPER = top.vhd

NEXTPNR_ARGS = --seed 1 --top $(TOP) --json $(BUILD_DIR)/twpm.json --textcfg $(BUILD_DIR)/nextpnr.config
NEORV32_SRC = $(filter-out %neorv32_cfs.vhd, \
	      $(filter-out %neorv32_application_image.vhd, \
	      $(filter-out %neorv32_bootloader_image.vhd, $(wildcard $(NEORV32_DIR)/rtl/core/*.vhd) $(wildcard $(NEORV32_DIR)/rtl/core/mem/*.vhd)))) \
	fpga_puf/rtl/fpga_puf.vhd \
	fpga_puf/rtl/neorv32_cfs.vhd
LPF_FILE = $(BOARD).lpf

NEORV32_APPLICATION = fpga_puf/sw/neorv32_application_image.vhd
NEORV32_APPLICATION_FLAGS = \
	-Wl,--defsym,__neorv32_ram_base=0x80000000 -Wl,--defsym,__neorv32_ram_size=0x8000 \
	-Wl,--defsym,__neorv32_rom_base=0x0 -Wl,--defsym,__neorv32_rom_size=0x8000

NEORV32_BOOTLOADER = neorv32/sw/bootloader/neorv32_bootloader_image.vhd
NEORV32_BOOTLOADER_ARGS += -DAUTO_BOOT_TIMEOUT=3


ifeq ($(BOARD),orangecrab)
# 50.4 MHz is actual frequency PLL produces when asked for 50 MHz on 48 MHz input.
NEXTPNR_ARGS += --25k --lpf orangecrab.lpf --package CSFBGA285 --ignore-loops --freq 50.4
LPF_FILE = orangecrab.lpf

# Silence warnings about logic loops in TRNG module, loops are where randomness comes from.
YOSYS_ARGS=-w "logic loop in .*io_system_neorv32_trng_inst_true_neorv32_trng_inst"
endif

all: $(BUILD_DIR)/twpm.dfu

clean:
	@rm -rf $(BUILD_DIR)
	@$(MAKE) -C neorv32/sw/bootloader clean
	@$(MAKE) -C fpga_puf/sw clean
	@rm -f neorv32/sw/image_gen/image_gen
	@find neorv32/sw -name '*.o' -exec rm '{}' \;

$(BUILD_DIR):
	@mkdir -p $@

$(BUILD_DIR)/neorv32: $(BUILD_DIR)
	@mkdir -p $@

fpga_puf/sw/neorv32_application_image.vhd: force
	@$(MAKE) -C fpga_puf/sw image exe USER_FLAGS="$(NEORV32_APPLICATION_FLAGS)"

$(NEORV32_BOOTLOADER): force
	@$(MAKE) -C neorv32/sw/bootloader bl_image USER_FLAGS="$(NEORV32_BOOTLOADER_ARGS)"
	@$(MAKE) -C fpga_puf/sw bl_image USER_FLAGS="$(NEORV32_BOOTLOADER_ARGS)"
force: ;

ifeq ($(TOOLCHAIN),trellis)
$(BUILD_DIR)/neorv32.v: $(BUILD_DIR)/neorv32 $(NEORV32_SRC) $(NEORV32_BOOTLOADER) $(NEORV32_APPLICATION) $(NEORV32_WRAPPER)
	@ghdl -i --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 -Pbuild $(NEORV32_SRC) $(NEORV32_WRAPPER) $(NEORV32_BOOTLOADER) $(NEORV32_APPLICATION)
	@ghdl -m --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 top
	@ghdl synth --latches --std=08 --work=neorv32 --workdir=$(BUILD_DIR)/neorv32 -Pbuild --out=verilog top > $@

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
$(BUILD_DIR)/build.tcl: $(BUILD_DIR) $(NEORV32_SRC) $(NEORV32_WRAPPER) $(NEORV32_BOOTLOADER) $(NEORV32_APPLICATION)
	@echo "prj_project new -name twpm -impl $(BOARD) -dev LFE5U-25F-8MG285C -synthesis synplify" > $@
	@for file in $(SRC); do \
		echo "prj_src add -work twpm $$(readlink -f $$file)" >> $@; done
	@for file in $(NEORV32_SRC); do \
		echo "prj_src add -work neorv32 $$(readlink -f $$file)" >> $@; done
	@echo "prj_src add -work neorv32 $$(readlink -f $(NEORV32_BOOTLOADER))" >> $@
	@echo "prj_src add -work neorv32 $$(readlink -f $(NEORV32_APPLICATION))" >> $@
	@for file in $$(readlink -f $(NEORV32_WRAPPER)); do \
		echo "prj_src add -work twpm $$file" >> $@; done
	@echo "prj_impl option top twpm.$(TOP)" >> $@
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
