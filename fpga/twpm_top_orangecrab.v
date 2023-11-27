module twpm_top (clk_i, rstn_i, uart_rxd_i, uart_txd_o,
                 LCLK, LRESET, LFRAME, LAD, SERIRQ,
                 spi_dat_o, spi_dat_i, spi_flash_cs_o,
                 ddram_a, ddram_ba, ddram_ras_n, ddram_cas_n,
                 ddram_we_n, ddram_dm, ddram_dq, ddram_dqs_p,
                 ddram_clk_p, ddram_cke, ddram_odt, ddram_cs_n, ddram_reset_n,
                 led_r, led_g, led_b);

// Memory map:
//
// +--------------------------------------+ 0xFFFFFFFF
// |  reserved (SoC devices etc.)         |
// +--------------------------------------+ 0xF8004000
// |  LiteDRAM controller interface       |
// +--------------------------------------+ 0xF8000000
// |  unused                              |
// +--------------------------------------+ 0xF0001000
// |  TPM command/response area           |
// +--------------------------------------+ 0xF0000800
// |  TPM <-> SoC communication registers |
// +--------------------------------------+ 0xF0000000
// |  code (XIP from flash)               |
// +--------------------------------------+ 0xE0000000
// |  unused                              |
// +--------------------------------------+ 0x88000000
// |  RAM                                 |
// +--------------------------------------+ 0x80000000
// |  unused                              |
// +--------------------------------------+ 0

parameter LITEDRAM_BASE_ADDRESS = 32'hF8000000;
parameter LITEDRAM_ADDR_WIDTH   = 14;
parameter TPM_RAM_BASE_ADDRESS  = 32'hF0000800;
parameter TPM_RAM_ADDR_WIDTH    = 11;
parameter TPM_REGS_BASE_ADDRESS = 32'hF0000000;
parameter TPM_REGS_ADDR_WIDTH   = 11;
parameter TPM_REG_STATUS        = 16'h0000;
parameter TPM_REG_OP_TYPE       = 16'h0004;
parameter TPM_REG_LOCALITY      = 16'h0008;
parameter TPM_REG_BUF_SIZE      = 16'h000C;
parameter TPM_REG_COMPLETE      = 16'h0040;
parameter RAM_BASE_ADDRESS      = 32'h80000000;
parameter RAM_ADDR_WIDTH        = 27;

parameter DEFAULT_READ_VALUE    = 32'hBAD_FAB_AC; // Bad FPGA Access

parameter COMPLETE_PULSE_WIDTH  = 20;

//# {{Global control}}
input  wire         clk_i;
input  wire         rstn_i;
//# {{UART}}
input  wire         uart_rxd_i;
output wire         uart_txd_o;
//# {{LPC interface}}
input  wire         LCLK;
input  wire         LRESET;
input  wire         LFRAME;
inout  wire [  3:0] LAD;
inout  wire         SERIRQ;
//# {{SPI interface}}
output wire         spi_dat_o;
input  wire         spi_dat_i;
output wire         spi_flash_cs_o;
//# {{DDR3 interface}}
output wire [15:0]  ddram_a;
output wire [2:0]   ddram_ba;
output wire         ddram_ras_n;
output wire         ddram_cas_n;
output wire         ddram_we_n;
output wire [1:0]   ddram_dm;
inout  wire [15:0]  ddram_dq;
inout  wire [1:0]   ddram_dqs_p;
output wire         ddram_clk_p;
output wire         ddram_cke;
output wire         ddram_odt;
output wire         ddram_cs_n;
output wire         ddram_reset_n;
//# {{Misc}}
output wire         led_r;
output wire         led_g;
output wire         led_b;

// Wishbone interface
wire [ 31:0] wb_adr;    // address
reg  [ 31:0] wb_dat_rd; // read data
wire [ 31:0] wb_dat_wr; // write data
wire         wb_we;     // write enable
wire [  3:0] wb_sel;    // byte enable
wire         wb_stb;    // strobe
wire         wb_cyc;    // cycle valid
reg          wb_ack;    // transfer ack
reg          wb_err;    // transfer error
wire         wb_clk;    // wishbone clock

// Data provider interface
wire    [7:0] data_lpc2dp;
wire    [7:0] data_dp2lpc;
wire   [15:0] lpc_addr;
wire          lpc_data_wr;
wire          lpc_wr_done;
wire          lpc_data_rd;
wire          lpc_data_req;
wire    [3:0] irq_num;
wire          interrupt;
wire [TPM_RAM_ADDR_WIDTH-1:0] DP_addr;
wire    [7:0] DP_data_rd;
wire    [7:0] DP_data_wr;
wire          DP_wr_en;
wire   [ 3:0] op_type;
wire   [ 3:0] locality;
wire [TPM_RAM_ADDR_WIDTH-1:0] buf_len;
wire          exec;
wire          abort;
wire          complete;

// RAM lines - final
wire    [8:0] RAM_A;
wire   [31:0] RAM_WD;
wire   [31:0] RAM_RD;
wire          RAM_CLK;
wire    [3:0] RAM_byte_sel;

// RAM lines - DP
wire    [8:0] DP_RAM_A;
wire   [31:0] DP_RAM_WD;
wire    [3:0] DP_RAM_byte_sel;

// RAM lines - WB
wire    [8:0] WB_RAM_A;
wire    [3:0] WB_RAM_byte_sel;

// Misc
wire          WBs_ACK_nxt;
wire    [7:0] spi_csn;
wire          spi_clk_o;
reg     [7:0] complete_pulse_counter = 0;
wire   [63:0] gpio;
wire          pll_locked;

// Helper signals
wire          hits_ctrl    = (wb_adr[31:LITEDRAM_ADDR_WIDTH] === LITEDRAM_BASE_ADDRESS[31:LITEDRAM_ADDR_WIDTH]);
wire          hits_tpm_ram = (wb_adr[31:TPM_RAM_ADDR_WIDTH]  === TPM_RAM_BASE_ADDRESS[31:TPM_RAM_ADDR_WIDTH]);
wire          hits_regs    = (wb_adr[31:TPM_REGS_ADDR_WIDTH] === TPM_REGS_BASE_ADDRESS[31:TPM_REGS_ADDR_WIDTH]);
wire          hits_ram     = (wb_adr[31:RAM_ADDR_WIDTH]      === RAM_BASE_ADDRESS[31:RAM_ADDR_WIDTH]);

wire          wb_stb_ddr3 = hits_ram & wb_stb;
wire          wb_we_ddr3  = hits_ram & wb_we;
wire          wb_ack_ddr3;
wire          wb_err_ddr3;
wire   [31:0] wb_dat_ddr3;

wire          wb_stb_ctrl = hits_ctrl & wb_stb;
wire          wb_we_crtl  = hits_ctrl & wb_we;
wire          wb_ack_ctrl;
wire          wb_err_ctrl;
wire   [31:0] wb_dat_ctrl;

wire          clk_50mhz;
wire          user_rst;

neorv32_verilog_wrapper cpu (
    .clk_i(clk_50mhz),
    .rstn_i(~user_rst),
    // TODO: connect JTAG: https://github.com/stnolting/neorv32/discussions/28#discussioncomment-6313328
    .jtag_trst_i(1'b1),
    .jtag_tck_i(1'b0),
    .jtag_tdi_i(1'b0),
    .jtag_tdo_o(),
    .jtag_tms_i(1'b0),
    .uart0_txd_o(uart_txd_o),
    .uart0_rxd_i(uart_rxd_i),
    .wb_adr_o(wb_adr),
    .wb_dat_i(wb_dat_rd),
    .wb_dat_o(wb_dat_wr),
    .wb_we_o(wb_we),
    .wb_sel_o(wb_sel),
    .wb_stb_o(wb_stb),
    .wb_cyc_o(wb_cyc),
    .wb_ack_i(wb_ack),
    .wb_err_i(wb_err),
    .spi_clk_o(spi_clk_o),
    .spi_dat_o(spi_dat_o),
    .spi_dat_i(spi_dat_i),
    .spi_csn_o(spi_csn),
    .gpio_o(gpio),
    .gpio_i(64'b0)
);

// SPI flash interface
assign spi_flash_cs_o = spi_csn[0]; // CS0 from NeoRV32

// Export clock to SPI flash, this has to be done through USRMCLK primitive.
USRMCLK spi_flash_clk (
  .USRMCLKI(spi_clk_o),
  // If 1 then SPI flash clock is tri-stated
  .USRMCLKTS(1'b0)
);

// Wishbone and CPU use the same clock.
assign wb_clk = clk_50mhz;

assign complete = complete_pulse_counter === 8'h0 ? 1'b0 : 1'b1;

// RAM DP lines assignments
assign DP_RAM_A =         DP_addr[TPM_RAM_ADDR_WIDTH-1:2];    // 32b words
// TODO: check if endianness needs changing in below assignments
assign DP_RAM_WD =        DP_addr[1:0] === 2'b00 ? {24'h000000, DP_data_wr} :
                          DP_addr[1:0] === 2'b01 ? {16'h0000, DP_data_wr, 8'h00} :
                          DP_addr[1:0] === 2'b10 ? {8'h00, DP_data_wr, 16'h0000} :
                          DP_addr[1:0] === 2'b11 ? {DP_data_wr, 24'h000000} :
                          32'h00000000;

assign DP_data_rd =       DP_addr[1:0] === 2'b00 ? RAM_RD[ 7: 0] :
                          DP_addr[1:0] === 2'b01 ? RAM_RD[15: 8] :
                          DP_addr[1:0] === 2'b10 ? RAM_RD[23:16] :
                          DP_addr[1:0] === 2'b11 ? RAM_RD[31:24] :
                          8'hFF;

assign DP_RAM_byte_sel =  DP_wr_en     === 1'b0  ? 4'b0000 :
                          DP_addr[1:0] === 2'b00 ? 4'b0001 :
                          DP_addr[1:0] === 2'b01 ? 4'b0010 :
                          DP_addr[1:0] === 2'b10 ? 4'b0100 :
                          DP_addr[1:0] === 2'b11 ? 4'b1000 :
                          4'b0000;

// RAM WB lines assignments
assign WB_RAM_A =         wb_adr[TPM_RAM_ADDR_WIDTH-1:2];    // 32b words
assign WB_RAM_byte_sel =  (hits_tpm_ram && wb_cyc === 1'b1 && wb_stb === 1'b1
                           && wb_we  === 1'b1 && wb_ack === 1'b0) ?
                          wb_sel : 4'b0000;

// Combined RAM signals
assign RAM_A =        exec ? WB_RAM_A         : DP_RAM_A;
assign RAM_WD =       exec ? wb_dat_wr        : DP_RAM_WD;
assign RAM_byte_sel = exec ? WB_RAM_byte_sel  : DP_RAM_byte_sel;
// This is sketchy, may produce spurious edges and not give enough time for signals to stabilize.
// It depends on RAM_byte_sel being zeroed on exec changes.
assign RAM_CLK =      exec ? wb_clk           : ~LCLK;

// WB acknowledge signal
assign WBs_ACK_nxt = wb_cyc & wb_stb & (~wb_ack);

always @(negedge wb_clk or negedge rstn_i) begin
  if (~rstn_i) begin
    wb_ack                  <= 1'b0;
    wb_err                  <= 1'b0;
    complete_pulse_counter  <= 1'b0;
  end else begin
    if (complete_pulse_counter !== 8'h0)
      complete_pulse_counter <= complete_pulse_counter - 1;
    if (hits_regs || hits_tpm_ram) begin
      wb_ack <= WBs_ACK_nxt;
      wb_err <= 1'b0;
      if (wb_adr[15:2] === TPM_REG_COMPLETE[15:2] && complete_pulse_counter === 8'h0
          && wb_cyc === 1'b1 && wb_stb === 1'b1 && wb_we  === 1'b1 && wb_ack === 1'b0)
        complete_pulse_counter <= COMPLETE_PULSE_WIDTH;
    end else if (hits_ram) begin
      wb_ack <= wb_cyc & wb_stb & wb_ack_ddr3 & ~wb_ack;
      wb_err <= wb_err_ddr3;
    end else if (hits_ctrl) begin
      wb_ack <= wb_cyc & wb_stb & wb_ack_ctrl & ~wb_ack;
      wb_err <= wb_err_ctrl;
    end else begin
      wb_ack <= 1'b0;
      wb_err <= 1'b0;
    end
  end
end

// Define the how to read from each IP
always @(*) begin
  if (hits_tpm_ram) begin
    wb_dat_rd <= RAM_RD;
  end else if (hits_regs) begin
      case (wb_adr[15:2])
        TPM_REG_STATUS[15:2]:   wb_dat_rd <= {29'h0000000, complete, abort, exec};
        TPM_REG_OP_TYPE[15:2]:  wb_dat_rd <= {28'h0000000, op_type};
        TPM_REG_LOCALITY[15:2]: wb_dat_rd <= {28'h0000000, locality};
        TPM_REG_BUF_SIZE[15:2]: wb_dat_rd <= {{(32-TPM_RAM_ADDR_WIDTH){1'b0}}, buf_len};
        default:                wb_dat_rd <= DEFAULT_READ_VALUE;
      endcase
  end else if (hits_ram) begin
    wb_dat_rd <= wb_dat_ddr3;
  end else if (hits_ctrl) begin
    wb_dat_rd <= wb_dat_ctrl;
  end
end

lpc_periph lpc_periph_inst (
  // LPC Interface
  .clk_i(LCLK),
  .nrst_i(LRESET),
  .lframe_i(LFRAME),
  .lad_bus(LAD),
  .serirq(SERIRQ),
  // Data provider interface
  .lpc_data_i(data_dp2lpc),
  .lpc_data_o(data_lpc2dp),
  .lpc_addr_o(lpc_addr),
  .lpc_data_wr(lpc_data_wr),
  .lpc_wr_done(lpc_wr_done),
  .lpc_data_rd(lpc_data_rd),
  .lpc_data_req(lpc_data_req),
  .irq_num(irq_num),
  .interrupt(interrupt)
);

regs_module regs_module_inst (
  // Signals to/from LPC module
  .clk_i(LCLK),
  .data_i(data_lpc2dp),
  .data_o(data_dp2lpc),
  .addr_i(lpc_addr),
  .data_wr(lpc_data_wr),
  .wr_done(lpc_wr_done),
  .data_rd(lpc_data_rd),
  .data_req(lpc_data_req),
  .irq_num(irq_num),
  .interrupt(interrupt),
  // Signals to/from M4
  .op_type(op_type),
  .locality(locality),
  .buf_len(buf_len),
  .exec(exec),
  .complete(complete),
  .abort(abort),
  // Signals to/from RAM
  .RAM_addr(DP_addr),
  .RAM_data_rd(DP_data_rd),
  .RAM_data_wr(DP_data_wr),
  .RAM_wr(DP_wr_en)
);

// TODO: parameterize address width
r512x32_512x32 RAM_INST (
  .A(RAM_A),
  .RD(RAM_RD),
  .WD(RAM_WD),
  .Clk(RAM_CLK),
  .WEN(RAM_byte_sel)
);

litedram_core litedram (
    .clk(clk_i),          // Input clock from oscillator (48 MHz)
    .rst(~rstn_i),        // Input, asynchronous reset, ACTIVE HIGH!
    .user_clk(clk_50mhz), // Output clock, minimum 50 MHz due to DDR3 timings
    .user_rst(user_rst),  // Output, synchronous reset, ACTIVE HIGH!
    // RAM signals
    .ddram_a(ddram_a[12:0]),
    .ddram_ba(ddram_ba),
    .ddram_cas_n(ddram_cas_n),
    .ddram_cke(ddram_cke),
    .ddram_clk_p(ddram_clk_p),  // ddram_clk_n handled by HW macro
    .ddram_cs_n(ddram_cs_n),
    .ddram_dm(ddram_dm),
    .ddram_dq(ddram_dq),
    .ddram_dqs_p(ddram_dqs_p),  // ddram_dqs_n handled by HW macro
    .ddram_odt(ddram_odt),
    .ddram_ras_n(ddram_ras_n),
    .ddram_reset_n(ddram_reset_n),
    .ddram_we_n(ddram_we_n),
    // Output status signals
    .init_done(),         // Controlled by SW, same as CSR_BASE+0
    .init_error(),        // Controlled by SW, same as CSR_BASE+4
    .pll_locked(pll_locked), // Active high indicates PLL lock
    // RAM data WISHBONE interface
    .user_port_wishbone_ack(wb_ack_ddr3),
    .user_port_wishbone_adr(wb_adr[RAM_ADDR_WIDTH-1:2]),
    .user_port_wishbone_cyc(wb_cyc),
    .user_port_wishbone_dat_r(wb_dat_ddr3),
    .user_port_wishbone_dat_w(wb_dat_wr),
    .user_port_wishbone_err(wb_err_ddr3),
    .user_port_wishbone_sel(wb_sel),
    .user_port_wishbone_stb(wb_stb_ddr3),
    .user_port_wishbone_we(wb_we_ddr3),
    // Controller WISHBONE interface
    .wb_ctrl_ack(wb_ack_ctrl),
    .wb_ctrl_adr({{(32-LITEDRAM_ADDR_WIDTH){1'b0}}, wb_adr[LITEDRAM_ADDR_WIDTH-1:2]}),
    .wb_ctrl_cyc(wb_cyc),
    .wb_ctrl_dat_r(wb_dat_ctrl),
    .wb_ctrl_dat_w(wb_dat_wr),
    .wb_ctrl_err(wb_err_ctrl),
    .wb_ctrl_sel(wb_sel),
    .wb_ctrl_stb(wb_stb_ctrl),
    .wb_ctrl_we(wb_we_crtl)
);

// Hardwire unused outputs
assign ddram_a[15:13] = 0;
// LEDs are active-low. Neorv32 by default sets all GPIOs to low so we negate
// GPIO signal to keep LEDs off until explicitly enabled.
assign led_r = ~gpio[1];
assign led_g = ~gpio[0];
assign led_b = pll_locked & ~gpio[2];

endmodule
