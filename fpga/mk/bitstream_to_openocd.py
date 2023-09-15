#!/usr/bin/env python3

from argparse import ArgumentParser
from struct import unpack
from lib.iomux import (
    Control,
    Mode,
    Pull,
    Slew,
    Schmitt,
    Drive,
    configure_pad,
    configure_fbio,
)
from lib.clock import configure_sclk0, configure_sclk1, CLK_DIVIDER_CLK_GATING
import re
import sys


def parse_eblif(i):
    top_level = [
        "model",
        "inputs",
        "outputs",
        "names",
        "latch",
        "subckt",
    ]

    sub_level = [
        "attr",
        "param",
    ]

    eblif = {}
    current = None

    def add(d):
        if d["type"] not in eblif:
            eblif[d["type"]] = []
        eblif[d["type"]].append(d)

    for line in i:
        if "#" in line:
            line = line[: line.find("#")]

        line = line.strip()
        if not line:
            continue

        if not line.startswith("."):
            continue

        args = line.split(" ", maxsplit=1)
        if len(args) < 2:
            args.append("")
        ctype = args.pop(0)[1:]

        if ctype in top_level:
            if current:
                add(current)
            current = {
                "type": ctype,
                "args": args[-1].split(),
                "data": [],
            }
        elif ctype in sub_level:
            if ctype not in current:
                current[ctype] = {}
            key, value = args[-1].split(maxsplit=1)
            current[ctype][key] = value
        else:
            current[ctype] = args[-1].split()

    if current:
        add(current)

    assert len(eblif["inputs"]) == 1
    eblif["inputs"] = eblif["inputs"][0]
    assert len(eblif["outputs"]) == 1
    eblif["outputs"] = eblif["outputs"][0]
    return eblif


def main():
    parser = ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument(
        "--qcf", type=str, required=True, help="Path to QCF constraints file"
    )
    parser.add_argument("--eblif", type=str, required=True)
    parser.add_argument("--sclk0-freq", type=int, default=0)
    parser.add_argument("--sclk1-freq", type=int, default=0)
    args = parser.parse_args()

    with open(args.input, "rb") as file:
        bitstream = file.read()
        assert len(bitstream) % 4 == 0

    with open(args.eblif, "r") as file:
        eblif = parse_eblif(file)

    eblif_inputs = eblif["inputs"]["args"]
    eblif_outputs = eblif["outputs"]["args"]

    class QcfConstraint:
        def __init__(self, net, pad):
            self.net = net
            self.pad = pad

    qcf_constraints = []

    with open(args.qcf, "r") as file:
        for i, line in enumerate(file):
            if "#" in line:
                line = line[: line.find("#")]

            line = line.strip()
            if not line:
                continue

            qcf_args = line.split()
            if len(qcf_args) == 0:
                continue

            if qcf_args.pop(0) != "place":
                continue

            if len(qcf_args) != 2:
                print(f"Invalid place command at line {i}")
                sys.exit(1)

            net = qcf_args.pop(0)
            pad_str = qcf_args.pop(0)

            try:
                m = re.match(r"^FBIO_([0-9]+)$", pad_str)
                if m:
                    pad = int(m.group(1))
                    if pad < 0 or pad >= 32:
                        raise ValueError('pad out of range')

                # SPDE uses different conventions, pads starting at FBIO_32 are
                # named differently - FBIO_32 is SFBIO_0, FBIO_33 is SFBIO_1 and
                # so on until FBIO_45 which is SFBIO_13.
                m = re.match(r"^SFBIO_([0-9]+)$", pad_str)
                if m:
                    pad = int(m.group(1))
                    if pad < 0 or pad >= 14:
                        raise ValueError('pad out of range')
                    pad += 32
            except:
                print(f"Unknown pad {pad_str} at line {i}")
                sys.exit(1)

            constraint = QcfConstraint(net, pad)
            constraint._line = i
            qcf_constraints.append(constraint)

    pad_config = {}

    for constraint in qcf_constraints:
        n = f"{constraint.net}"

        if n in eblif_inputs and n in eblif_outputs:
            mode = Mode.INPUT_OUTPUT
        elif n in eblif_inputs:
            mode = Mode.INPUT
        elif n in eblif_outputs:
            mode = Mode.OUTPUT
        else:
            raise RuntimeError(
                f"Attempted to constraint pad {constraint.pad} to unused net {n} at line {constraint._line}"
            )

        pad_config[constraint.pad] = {
            "mode": mode,
            "pull": Pull.DISABLED,
            "drive": Drive.MA_2,
            "slew": Slew.SLOW,
            "schmitt": Schmitt.DISABLED,
            "control": Control.FABRIC,
            # TODO: some pads have FBIO under different function number, need to handle this case
            "function": 0,
        }

    pad_config_raw = []
    for pad in pad_config:
        cfg = pad_config[pad]
        pad_config_raw.append(
            configure_pad(
                pad,
                cfg["control"],
                cfg["mode"],
                cfg["pull"],
                cfg["drive"],
                cfg["slew"],
                cfg["schmitt"],
                cfg["function"],
            )
        )

    f = open(args.output, "w")
    f.write("proc load_bitstream {} {")
    f.write(
        """
    echo "Loading bitstream ..."
    mww 0x40004c4c 0x00000180 ;# PAD19 pull down drive 4mA
    # Check FPGA power status, we don't handle properly FPGA reconfiguration
    # so make sure FPGA is powered-off before attempting configuration.
    set fpga_power_status [read_memory 0x400044a0 32 1]
    if {$fpga_power_status != 4} {
        echo "FPGA is already enabled, doing reset ..."
        reset halt
        set fpga_power_status [read_memory 0x400044a0 32 1]
        if {$fpga_power_status != 4} {
            exit "FPGA still enabled after reset, bailing out."
        }
    }

    # Power up FPGA
    mww 0x40004610 0x00000002

    # Wait for FPGA to get online
    set fpga_power_status 2
    while {$fpga_power_status != 0} {
        set fpga_power_status [read_memory 0x40004610 32 1]
    }

    mww 0x40005310 0x1acce551

    # Reset C02, C09, C16, C21 domains
    mww 0x40004088 0x0000003f
    # Reset AHB-to-Wishbone
    mww 0x40004094 0x00000001
"""
    )

    # TODO: allow configuring H_Osc frequency
    if args.sclk0_freq > 0:
        f.write(f"    # Configure C16 frequency\n")
        for reg, value in configure_sclk0(72000000, args.sclk0_freq):
            f.write(f"    mww {reg:#010x} {value:#010x}\n")

    if args.sclk1_freq > 0:
        f.write(f"    # Configure C21 frequency\n")
        for reg, value in configure_sclk1(72000000, args.sclk1_freq):
            f.write(f"    mww {reg:#010x} {value:#010x}\n")

    # Always keep A gate open
    clk_divider_gating = 1

    # TODO: probably we don't need to enable those gates if we don't divide
    if args.sclk0_freq > 0:
        clk_divider_gating |= 1 << 5

    if args.sclk1_freq > 0:
        clk_divider_gating |= 1 << 8

    f.write(f"    mww {CLK_DIVIDER_CLK_GATING:#010x} {clk_divider_gating:#010x}\n")

    # TODO: setup PIF and APB0 clocks

    f.write(
        """
    # Enable APB0 clock and PIF clocks (FPGA programming interface)
    mww 0x4000411c 0x00000006
    mww 0x40004054 0x00000001
    sleep 100

    # Enable access to FPGA configuration bits
    mww 0x40014000 0x0000bdff
    sleep 100

    # Upload bitstream
    echo "Uploading bitstream ..."
"""
    )

    for i in range(len(bitstream) // 4):
        word = unpack("<I", bitstream[4 * i : 4 * i + 4])[0]
        f.write(f"    mww 0x40014ffc {word:#010x}\n")

    f.write("    sleep 100\n")

    # Ungate SCLK0 and SCLK1
    if args.sclk0_freq > 0:
        f.write(f"    mww 0x40004064 0x00000001\n")

    if args.sclk1_freq > 0:
        f.write(f"    mww 0x40004070 0x00000001\n")

    f.write(
        """
    # Disable FPGA programming mode, power-off PIF interface and disable C09
    # clock.
    mww 0x40014000 0x00000000
    mww 0x400047f0 0x00000000
    mww 0x4000411c 0x00000000
    sleep 100

    # Disable FPGA isolation
    mww 0x400047f4 0x00000000

    # Unknown, documentation says this is scratch area.
    mww 0x400047f8 0x00000090
    sleep 100
    mww 0x40004c4c 0x000009a0 ;# PAD19
    sleep 100
"""
    )

    for reg, value in pad_config_raw:
        f.write(f"    mww {reg:#010x} {value:#010x}\n")

    fbio_config = configure_fbio(pad_config)
    for reg in fbio_config:
        f.write(f"    mww {reg:#010x} {fbio_config[reg]:#010x}\n")

    f.write(
        """
    # Disable reset for C02, C09, C16, C21 domains
    mww 0x40004088 0x00000000
    # Disable reset for AHB-to-Wishbone bridge
    mww 0x40004094 0x00000000
"""
    )

    f.write('    echo "Bitstream loaded"')
    f.write("}\n")
    f.close()


if __name__ == "__main__":
    main()
