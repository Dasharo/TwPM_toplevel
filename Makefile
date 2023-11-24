# Target board, currently only Orangecrab is supported
BOARD ?= orangecrab

# Toolchain to use for FPGA synthesis, can be "trellis" or "diamond"
# Diamond is not included in SDK
FPGA_TOOLCHAIN ?= trellis

# Build directory
BUILD_DIR ?= build

all: image
clean:
# Call to fpga/ so that neorv32 build artifacts are cleaned up (which are not
# stored in build directory)
	@$(MAKE) -C fpga BUILD_DIR=$(shell readlink -f "$(BUILD_DIR)/fpga") clean
	@rm -rf $(BUILD_DIR)

$(BUILD_DIR):
	@mkdir -p $@

.PHONY: fpga
fpga: $(BUILD_DIR)
	@$(MAKE) -C fpga BOARD=$(BOARD) BUILD_DIR=$(shell readlink -f "$(BUILD_DIR)/fpga") TOOLCHAIN=$(FPGA_TOOLCHAIN)

.PHONY: firmware
firmware: $(BUILD_DIR)
	@$(MAKE) -C firmware BOARD=$(BOARD) BUILD_DIR=$(shell readlink -f "$(BUILD_DIR)/firmware")

.PHONY: image
# TODO: build complete image with bitstream and firmware
image: fpga/neorv32/sw/image_gen/image_gen fpga firmware
	@fpga/neorv32/sw/image_gen/image_gen -app_bin $(BUILD_DIR)/firmware/zephyr/zephyr.bin $(BUILD_DIR)/firmware/zephyr_with_header.bin
