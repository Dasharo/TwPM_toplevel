library ieee;
use ieee.std_logic_1164.all;

library neorv32;
use neorv32.neorv32_package.all;

entity top is
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- primary UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic; -- UART0 receive data\
    --
    led_r       : out std_ulogic;
    led_g       : out std_ulogic;
    led_b       : out std_ulogic
  );
end entity;

architecture top_rtl of top is
  constant CFS_OUT_SIZE: natural := 3;

  signal wb_adr: std_ulogic_vector(31 downto 0);
  signal wb_dat: std_ulogic_vector(31 downto 0);
  signal wb_we: std_ulogic;
  signal wb_sel: std_ulogic_vector(3 downto 0);
  signal wb_stb: std_ulogic;
  signal wb_cyc: std_ulogic;
  signal wb_ack: std_ulogic;
  signal wb_err: std_ulogic;

  signal cfs_out: std_ulogic_vector(CFS_OUT_SIZE-1 downto 0);
begin

  neorv32_top_inst: neorv32_top

  generic map (
    -- General --
    CLOCK_FREQUENCY              => 50_400_000,  -- clock frequency of clk_i in Hz
    ON_CHIP_DEBUGGER_EN          => false,       -- enable JTAG support
    INT_BOOTLOADER_EN            => true,        -- boot configuration: boot explicit bootloader
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_A        => true,       -- implement atomic memory operations extension?
    CPU_EXTENSION_RISCV_C        => true,       -- implement compressed extension?
    CPU_EXTENSION_RISCV_M        => true,       -- implement mul/div extension?
    CPU_EXTENSION_RISCV_Zicntr   => true,       -- implement base counters?
    -- Internal Instruction memory (IMEM) --
    MEM_INT_IMEM_EN              => true,       -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            => 32*1024,     -- size of processor-internal instruction memory in bytes
    -- Internal Data memory (DMEM) --
    MEM_INT_DMEM_EN              => true,        -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => 32*1024,     -- size of processor-internal data memory in bytes
    -- Processor peripherals --
    IO_MTIME_EN                  => false,       -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,        -- implement primary universal asynchronous receiver/transmitter (UART0)?
    IO_UART0_RX_FIFO             => 64,          -- RX fifo depth, has to be a power of two, min 1
    IO_UART0_TX_FIFO             => 64,          -- TX fifo depth, has to be a power of two, min 1
    IO_TRNG_EN                   => false,       -- implement true random number generator (TRNG)?
    IO_SPI_EN                    => false,
    -- External memory interface (WISHBONE) --
    MEM_EXT_EN                   => false,       -- implement external memory bus interface?
    MEM_EXT_TIMEOUT              => 4096,        -- cycles after a pending bus access auto-terminates (0 = disabled)
    MEM_EXT_PIPE_MODE            => false,       -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    MEM_EXT_BIG_ENDIAN           => false,       -- byte order: true=big-endian, false=little-endian
    MEM_EXT_ASYNC_RX             => false,       -- use register buffer for RX data when false
    MEM_EXT_ASYNC_TX             => false,       -- use register buffer for TX data when false
    -- GPIO --
    IO_GPIO_NUM                  => 3,           -- use GPIO for controlling LEDs
    IO_CFS_EN                    => true,
    IO_CFS_OUT_SIZE              => CFS_OUT_SIZE
  )
  port map (
    -- Global control --
    clk_i       => clk_i,       -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i, -- UART0 receive data
    --     -- Wishbone bus interface --
    wb_tag_o    => open,        -- request tag
    wb_adr_o    => wb_adr,      -- address
    wb_dat_i    => wb_dat,      -- read data
    wb_dat_o    => wb_dat,      -- write data
    wb_we_o     => wb_we,       -- read/write
    wb_sel_o    => wb_sel,      -- byte enable
    wb_stb_o    => wb_stb,      -- strobe
    wb_cyc_o    => wb_cyc,      -- valid cycle
    wb_ack_i    => wb_ack,      -- transfer acknowledge
    wb_err_i    => wb_err,      -- transfer error
    cfs_out_o   => cfs_out
  );

  led_r <= not cfs_out(0);
  led_g <= not cfs_out(1);
  led_b <= not cfs_out(2);

end architecture;
