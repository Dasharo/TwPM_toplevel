ifndef F4PGA_INSTALL_DIR
    $(error $F4PGA_INSTALL_DIR not defined)
endif
ifndef FPGA_FAM
    $(error $FPGA_FAM not defined)
endif
ifndef F4PGA_PACKAGES
    $(error $F4PGA_PACKAGES not defined)
endif

FPGA_TOP_MODULE := TwPM_Top
FPGA_RTL_BIN_OBJ := build/$(FPGA_TOP_MODULE).bin

.PHONY: all
all: $(FPGA_RTL_BIN_OBJ)

$(FPGA_RTL_BIN_OBJ): flow.json
	f4pga -vvv build --flow ./flow.json

.PHONY: flash
flash: $(FPGA_RTL_BIN_OBJ)
	qfprog --port /dev/ttyS_QORC --appfpga $(FPGA_RTL_BIN_OBJ) --mode fpga --reset

.PHONY: clean
clean:
	@$(RM) -r build/
