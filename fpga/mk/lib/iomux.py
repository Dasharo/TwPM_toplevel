from typing import Tuple, Iterable
from enum import IntEnum


IOMUX_BASE = 0x40004C00
FBIOSEL_BASE = 0x40004D80


class Control(IntEnum):
    A0 = 0
    OTHER = 1
    FABRIC = 2


class Mode(IntEnum):
    DISABLED = 0
    INPUT = 1
    OUTPUT = 2
    INPUT_OUTPUT = 3


class Pull(IntEnum):
    DISABLED = 0
    UP = 1
    DOWN = 2
    KEEPER = 3


class Slew(IntEnum):
    SLOW = 0
    FAST = 1


class Schmitt(IntEnum):
    DISABLED = 0
    ENABLED = 1


class Drive(IntEnum):
    MA_2 = 0
    MA_4 = 1
    MA_8 = 2
    MA_12 = 3


def configure_pad(
    pad: int,
    control: Control = Control.A0,
    mode: Mode = Mode.DISABLED,
    pull: Pull = Pull.DISABLED,
    drive: Drive = Drive.MA_2,
    slew: Slew = Slew.SLOW,
    schmitt: Schmitt = Schmitt.DISABLED,
    function: int = 0,
) -> Tuple[int, int]:
    if pad < 0 or pad > 45:
        raise ValueError(f"pad {pad} is out of range")

    if control not in Control._value2member_map_:
        raise ValueError("control is invalid")

    if mode not in Mode._value2member_map_:
        raise ValueError("mode is invalid")

    if pull not in Drive._value2member_map_:
        raise ValueError("pull is invalid")

    if drive not in Drive._value2member_map_:
        raise ValueError("drive is invalid")

    if slew not in Slew._value2member_map_:
        raise ValueError("slew is invalid")

    if schmitt not in Schmitt._value2member_map_:
        raise ValueError("schmitt is invalid")

    if function < 0 or function > 3:
        raise ValueError("function is invalid")

    reg = 0
    reg |= function
    reg |= control << 3

    if mode == Mode.DISABLED:
        oen = 0
        ren = 0
    elif mode == Mode.INPUT:
        oen = 0
        ren = 1
    elif mode == Mode.OUTPUT:
        oen = 1
        ren = 0
    elif mode == Mode.INPUT_OUTPUT:
        oen = 1
        ren = 1
    else:
        assert False, "unreachable"

    reg |= (oen << 5) | (ren << 11)
    reg |= pull << 6
    reg |= drive << 8
    reg |= slew << 10
    reg |= schmitt << 12

    return IOMUX_BASE + pad * 4, reg


def configure_fbio(pads: Iterable[int]):
    fbio_sel = {FBIOSEL_BASE: 0, FBIOSEL_BASE + 4: 0}
    for pad in pads:
        r = pad // 32
        b = pad % 32
        fbio_sel[FBIOSEL_BASE + r * 4] |= 1 << b

    return fbio_sel
