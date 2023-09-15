TWPM_YOSYS_DIR ?=
TWPM_SPDE_DIR ?=

ifeq ($(TWPM_YOSYS_DIR),)
$(error TWPM_YOSYS_DIR is not set (are you using the latest version of TwPM SDK?))
endif

ifeq ($(TWPM_SPDE_DIR),)
$(error TWPM_SPDE_DIR is not set (are you using the latest version of TwPM SDK?))
endif

BUILD ?= $(shell pwd)/build

ifneq ($(V),1)
Q = @
else
Q =
endif

# Name of the top-level module
ifeq ($(TOP),)
$(error TOP is not set)
endif

# Verilog source files
ifeq ($(SRC),)
$(error SRC is not set)
endif

C16_FREQ ?= 0
C21_FREQ ?= 0

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

SRC_ABS := $(foreach file, $(SRC), $(realpath $(file)))
SRC_ABS_NT := $(foreach file, $(SRC_ABS), $(addprefix Z:, $(subst /,\\,$(file))))

all: $(BUILD) $(BUILD)/$(TOP).bin $(BUILD)/$(TOP).openocd

$(BUILD):
	$(Q)mkdir -p $(BUILD)

$(BUILD)/$(TOP).edif $(BUILD)/$(TOP).eblif: $(SRC)
	$(Q)(cd $(BUILD) \
	  && wine $(TWPM_YOSYS_DIR)/bin/yosys.exe \
		-p "synth_quicklogic -family pp3 -top $(TOP) -edif $(TOP).edif -blif $(TOP).eblif" $(SRC_ABS_NT) \
		> synth.log 2>&1 || (echo "Synthesis failed, please check $(BUILD)/synth.log for details" && exit 1) \
	)

$(BUILD)/$(TOP).qcf: $(QCF)
ifeq ($(QCF),)
	$(Q)(echo Cannot build full design without constraints file && exit 1)
else
	$(Q)(cp $(QCF) $@)
endif

$(addprefix $(BUILD)/$(TOP)., atr clk sdf qpd vq chp bin): $(addprefix $(BUILD)/$(TOP)., eblif edif qcf)
	$(Q)( \
		cd $(BUILD); \
		_partname=$$(grep 'partname' $(TOP).qcf 2> /dev/null); \
		if [ -z "$$_partname" ]; then echo "Please spcecify \"partname\" in .qcf file" && exit 1; fi; \
		partname=$$(echo "$$_partname" | sed -E 's|partname ([a-zA-Z0-9_-]+)|\1|' | tr -d '\n\r'); \
		export WINEDEBUG=-all; \
		wine $(TWPM_SPDE_DIR)/spdecl.exe -LOAD $(TOP).edif -RUNALLTOOLS \
			-SAVE $(TOP).chp \
			-SAVE_CONFIG_BITS; \
		rm -f "$${partname}_$(TOP).jlink"; \
		mv "$${partname}_$(TOP).bin" $(TOP).bin; \
	)

$(BUILD)/$(TOP).openocd: $(BUILD)/$(TOP).bin
	$(Q)python3 $(MK_DIR)/bitstream_to_openocd.py --eblif $(BUILD)/$(TOP).eblif --qcf $(QCF) $< $@ \
		--sclk0-freq $(C16_FREQ) --sclk1-freq $(C21_FREQ)

clean:
	$(Q)rm -rf $(BUILD)
