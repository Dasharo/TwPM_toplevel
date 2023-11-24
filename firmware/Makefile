BUILD_DIR ?= build

.west: twpm-firmware
	@west init -l twpm-firmware


.PHONY: firmware
firmware: .west
	@west update
	@( \
		[ -n "$$TWPM_ZEPHYR_CMAKE_PATH" ] && export CMAKE_PREFIX_PATH="$$TWPM_ZEPHYR_CMAKE_PATH"; \
		west build -b orangecrab -d $(BUILD_DIR) twpm-firmware/app \
	)
