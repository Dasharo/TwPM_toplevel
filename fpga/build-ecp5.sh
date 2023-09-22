#!/usr/bin/env bash

set -euo pipefail

mkdir build
yosys -p \
    'read_verilog TwPM_Top.v verilog-lpc-module/lpc_periph.v verilog-tpm-fifo-registers/regs_module.v; synth_ecp5 -top TwPM_Top -json build/twpm.json' \
    &> build/synth.log

nextpnr-ecp5 --top TwPM_Top --json build/twpm.json --um-25k \
    --freq 33 |& tee build/pnr.log
