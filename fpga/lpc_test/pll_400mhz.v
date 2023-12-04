/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.13.0.56.2 */
`timescale 1 ns / 1 ps

module pll_400mhz (CLKI, CLKOP);
    input wire CLKI;
    output wire CLKOP;

    wire REFCLK;
    wire LOCK;
    wire CLKOP_t;
    wire CLKFB_t;
    wire buf_CLKI;

    IB Inst1_IB (.I(CLKI), .O(buf_CLKI));

    defparam PLLInst_0.PLLRST_ENA = "DISABLED" ;
    defparam PLLInst_0.INTFB_WAKE = "DISABLED" ;
    defparam PLLInst_0.STDBY_ENABLE = "DISABLED" ;
    defparam PLLInst_0.DPHASE_SOURCE = "DISABLED" ;
    defparam PLLInst_0.CLKOS3_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS3_CPHASE = 0 ;
    defparam PLLInst_0.CLKOS2_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS2_CPHASE = 0 ;
    defparam PLLInst_0.CLKOS_FPHASE = 0 ;
    defparam PLLInst_0.CLKOS_CPHASE = 0 ;
    defparam PLLInst_0.CLKOP_FPHASE = 0 ;
    defparam PLLInst_0.CLKOP_CPHASE = 1 ;
    defparam PLLInst_0.PLL_LOCK_MODE = 0 ;
    defparam PLLInst_0.CLKOS_TRIM_DELAY = 0 ;
    defparam PLLInst_0.CLKOS_TRIM_POL = "FALLING" ;
    defparam PLLInst_0.CLKOP_TRIM_DELAY = 0 ;
    defparam PLLInst_0.CLKOP_TRIM_POL = "FALLING" ;
    defparam PLLInst_0.OUTDIVIDER_MUXD = "DIVD" ;
    defparam PLLInst_0.CLKOS3_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXC = "DIVC" ;
    defparam PLLInst_0.CLKOS2_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXB = "DIVB" ;
    defparam PLLInst_0.CLKOS_ENABLE = "DISABLED" ;
    defparam PLLInst_0.OUTDIVIDER_MUXA = "DIVA" ;
    defparam PLLInst_0.CLKOP_ENABLE = "ENABLED" ;
    defparam PLLInst_0.CLKOS3_DIV = 1 ;
    defparam PLLInst_0.CLKOS2_DIV = 1 ;
    defparam PLLInst_0.CLKOS_DIV = 1 ;
    defparam PLLInst_0.CLKOP_DIV = 2 ;
    defparam PLLInst_0.CLKFB_DIV = 25 ;
    defparam PLLInst_0.CLKI_DIV = 3 ;
    defparam PLLInst_0.FEEDBK_PATH = "INT_OP" ;
    EHXPLLL PLLInst_0 (
        .CLKI(buf_CLKI),
        .CLKFB(CLKFB_t),
        .PHASESEL1(1'b0),
        .PHASESEL0(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PHASELOADREG(1'b0),
        .STDBY(1'b0),
        .PLLWAKESYNC(1'b0),
        .RST(1'b0),
        .ENCLKOP(1'b0),
        .ENCLKOS(1'b0),
        .ENCLKOS2(1'b0),
        .ENCLKOS3(1'b0),
        .CLKOP(CLKOP_t),
        .CLKOS(),
        .CLKOS2(),
        .CLKOS3(),
        .LOCK(LOCK),
        .INTLOCK(),
        .REFCLK(REFCLK),
        .CLKINTFB(CLKFB_t));

    assign CLKOP = CLKOP_t;

endmodule
