#!/usr/bin/env bash

set -euo pipefail

mkdir build
yosys -p \
    'read_verilog TwPM_Top.v verilog-lpc-module/lpc_periph.v verilog-tpm-fifo-registers/regs_module.v; synth_ice40 -top TwPM_Top -json build/twpm.json' \
    &> build/synth.log

nextpnr-ice40 --top TwPM_Top --json build/twpm.json --up5k --package sg48 \
    --asc build/twpm.ice --pcf dummy.pcf --opt-timing --freq 33000000 |& tee build/pnr.log
