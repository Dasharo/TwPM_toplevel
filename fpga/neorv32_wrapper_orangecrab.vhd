library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_verilog_wrapper is
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- primary UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic; -- UART0 receive data
    -- JTAG --
    jtag_trst_i : in  std_ulogic; -- low-active TAP reset (optional)
    jtag_tck_i  : in  std_ulogic; -- serial clock
    jtag_tdi_i  : in  std_ulogic; -- serial data input
    jtag_tdo_o  : out std_ulogic; -- serial data output
    jtag_tms_i  : in  std_ulogic; -- mode select
    -- Wishbone bus interface --
    wb_adr_o    : out std_ulogic_vector(31 downto 0); -- address
    wb_dat_i    : in  std_ulogic_vector(31 downto 0); -- read data
    wb_dat_o    : out std_ulogic_vector(31 downto 0); -- write data
    wb_we_o     : out std_ulogic; -- read/write
    wb_sel_o    : out std_ulogic_vector(03 downto 0); -- byte enable
    wb_stb_o    : out std_ulogic; -- strobe
    wb_cyc_o    : out std_ulogic; -- valid cycle
    wb_ack_i    : in  std_ulogic; -- transfer acknowledge
    wb_err_i    : in  std_ulogic; -- transfer error
    -- SPI interface --
    spi_clk_o   : out std_ulogic; -- serial clock output
    spi_dat_o   : out std_ulogic; -- serial data output
    spi_dat_i   : in  std_ulogic; -- serial data input
    spi_csn_o   : out std_ulogic_vector(07 downto 0) -- 8-bit dedicated chip select output (low-active)
  );
end entity;

architecture neorv32_verilog_wrapper_rtl of neorv32_verilog_wrapper is

begin

  neorv32_top_inst: neorv32_top

  generic map (
    -- General --
    CLOCK_FREQUENCY              => 48_000_000,  -- clock frequency of clk_i in Hz
    ON_CHIP_DEBUGGER_EN          => true,        -- enable JTAG support
    INT_BOOTLOADER_EN            => true,        -- boot configuration: boot explicit bootloader
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C        => true,        -- implement compressed extension?
    CPU_EXTENSION_RISCV_M        => true,        -- implement mul/div extension?
    CPU_EXTENSION_RISCV_Zicntr   => true,        -- implement base counters?
    CPU_EXTENSION_RISCV_Zifencei => true,        -- implement instruction stream sync? Required by ON_CHIP_DEBUGGER_EN
    -- Internal Instruction memory (IMEM) --
    MEM_INT_IMEM_EN              => false,       -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            => 64*1024,     -- size of processor-internal instruction memory in bytes
    -- Internal Data memory (DMEM) --
    MEM_INT_DMEM_EN              => true,        -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => 64*1024,     -- size of processor-internal data memory in bytes
    -- Processor peripherals --
    IO_MTIME_EN                  => true,        -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,        -- implement primary universal asynchronous receiver/transmitter (UART0)?
    IO_UART0_RX_FIFO             => 64,          -- RX fifo depth, has to be a power of two, min 1
    IO_UART0_TX_FIFO             => 64,          -- TX fifo depth, has to be a power of two, min 1
    IO_TRNG_EN                   => true,        -- implement true random number generator (TRNG)?
    IO_SPI_EN                    => true,
    -- External memory interface (WISHBONE) --
    MEM_EXT_EN                   => true,        -- implement external memory bus interface?
    MEM_EXT_TIMEOUT              => 4096,        -- cycles after a pending bus access auto-terminates (0 = disabled)
    MEM_EXT_PIPE_MODE            => false,       -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    MEM_EXT_BIG_ENDIAN           => false,       -- byte order: true=big-endian, false=little-endian
    MEM_EXT_ASYNC_RX             => false,       -- use register buffer for RX data when false
    MEM_EXT_ASYNC_TX             => false        -- use register buffer for TX data when false
  )
  port map (
    -- Global control --
    clk_i       => clk_i,       -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i, -- UART0 receive data
    -- JTAG on-chip debugger interface (available if ON_CHIP_DEBUGGER_EN = true) --
    jtag_trst_i => jtag_trst_i, -- low-active TAP reset (optional)
    jtag_tck_i  => jtag_tck_i,  -- serial clock
    jtag_tdi_i  => jtag_tdi_i,  -- serial data input
    jtag_tdo_o  => jtag_tdo_o,  -- serial data output
    jtag_tms_i  => jtag_tms_i,  -- mode select
    -- Wishbone bus interface --
    wb_tag_o    => open,        -- request tag
    wb_adr_o    => wb_adr_o,    -- address
    wb_dat_i    => wb_dat_i,    -- read data
    wb_dat_o    => wb_dat_o,    -- write data
    wb_we_o     => wb_we_o,     -- read/write
    wb_sel_o    => wb_sel_o,    -- byte enable
    wb_stb_o    => wb_stb_o,    -- strobe
    wb_cyc_o    => wb_cyc_o,    -- valid cycle
    wb_ack_i    => wb_ack_i,    -- transfer acknowledge
    wb_err_i    => wb_err_i,    -- transfer error
    -- SPI interface --
    spi_clk_o   => spi_clk_o,   -- serial clock output
    spi_dat_o   => spi_dat_o,   -- serial data output
    spi_dat_i   => spi_dat_i,   -- serial data input
    spi_csn_o   => spi_csn_o    -- 8-bit dedicated chip select output (low-active)
  );

end architecture;
