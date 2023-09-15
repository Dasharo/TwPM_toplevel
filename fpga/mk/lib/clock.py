from typing import List, Tuple
from math import ceil


SLOW_OSCILLATOR_FREQ = 32768
CLK_CONTROL_F_0 = 0x40004020
CLK_CONTROL_F_1 = 0x40004024
CLK_CONTROL_I_0 = 0x40004034
CLK_CONTROL_I_1 = 0x40004038
CLK_DIVIDER_CLK_GATING = 0x40004124


def calculate_divider(input_freq: int, target_freq: int) -> int:
    assert input_freq >= target_freq
    return ceil(input_freq / target_freq)


def configure_sclk(
    osc_freq: int, sclk_freq: int, control_0_reg, control_1_reg
) -> List[Tuple[int, int]]:
    assert osc_freq >= sclk_freq
    assert sclk_freq > 0 and sclk_freq

    div_fast_osc = ceil(osc_freq / sclk_freq)
    fast_error = sclk_freq - osc_freq // div_fast_osc

    use_slow_oscillator = 0

    # If target frequency is lower than 32768 Hz try to use slow oscillator as
    # source.
    if sclk_freq <= SLOW_OSCILLATOR_FREQ:
        div_slow_osc = ceil(SLOW_OSCILLATOR_FREQ / sclk_freq)
        slow_error = sclk_freq - osc_freq // div_slow_osc

        if slow_error <= fast_error:
            use_slow_oscillator = 1

    if use_slow_oscillator:
        div = div_slow_osc
    else:
        div = div_fast_osc

    if div > 512:
        raise ValueError(
            f"Could not configure clock divider: achieving target frequency would require dividing source clock by {div} which is not possible"
        )

    if div == 1:
        enable_divider = False
        div = 0
    else:
        enable_divider = True

    control_0 = div - 2
    if enable_divider:
        control_0 |= 1 << 9
    else:
        control_0 = 0

    control_1 = 0
    if use_slow_oscillator:
        control_1 |= 1

    return [(control_0_reg, control_0), (control_1_reg, control_1)]


def configure_sclk0(osc_freq: int, sclk_freq: int) -> List[Tuple[int, int]]:
    return configure_sclk(osc_freq, sclk_freq, CLK_CONTROL_F_0, CLK_CONTROL_F_1)


def configure_sclk1(osc_freq: int, sclk_freq: int) -> List[Tuple[int, int]]:
    return configure_sclk(osc_freq, sclk_freq, CLK_CONTROL_I_0, CLK_CONTROL_I_1)
