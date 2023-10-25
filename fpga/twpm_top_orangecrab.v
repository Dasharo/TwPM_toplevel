parameter STATUS_REG_ADDRESS    = 17'h00000;
parameter OP_TYPE_REG_ADDRESS   = 17'h00004;
parameter LOCALITY_REG_ADDRESS  = 17'h00008;
parameter BUF_SIZE_REG_ADDRESS  = 17'h0000C;
parameter COMPLETE_REG_ADDRESS  = 17'h00040;
parameter FPGA_RAM_BASE_ADDRESS = 17'h00800;
parameter DEFAULT_READ_VALUE    = 32'hBAD_FAB_AC; // Bad FPGA Access
parameter RAM_ADDR_WIDTH        = 11;
parameter COMPLETE_PULSE_WIDTH  = 20;

module twpm_top (
    input  wire         clk_i,
    input  wire         rstn_i,
    input  wire         uart_rxd_i,
    output wire         uart_txd_o,
    // LPC interface
    input  wire         LCLK,
    input  wire         LRESET,
    input  wire         LFRAME,
    inout  wire [  3:0] LAD,
    inout  wire         SERIRQ,
    // SPI interface
    output wire         spi_dat_o,
    input  wire         spi_dat_i,
    output wire         spi_flash_cs_o
);

// Wishbone interface
wire [ 31:0] wb_adr;    // address
reg  [ 31:0] wb_dat_rd; // read data
wire [ 31:0] wb_dat_wr; // write data
wire         wb_we;     // write enable
wire [  3:0] wb_sel;    // byte enable
wire         wb_stb;    // strobe
wire         wb_cyc;    // cycle valid
reg          wb_ack;    // transfer ack
wire         wb_err;    // transfer error
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
wire [RAM_ADDR_WIDTH-1:0] DP_addr;
wire    [7:0] DP_data_rd;
wire    [7:0] DP_data_wr;
wire          DP_wr_en;
wire   [ 3:0] op_type;
wire   [ 3:0] locality;
wire [RAM_ADDR_WIDTH-1:0] buf_len;
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

neorv32_verilog_wrapper cpu (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
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
    .spi_csn_o(spi_csn)
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
assign wb_clk = clk_i;

assign complete = complete_pulse_counter === 8'h0 ? 1'b0 : 1'b1;

// RAM DP lines assignments
assign DP_RAM_A =         DP_addr[RAM_ADDR_WIDTH-1:2];    // 32b words
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
assign WB_RAM_A =         wb_adr[RAM_ADDR_WIDTH-1:2];    // 32b words
assign WB_RAM_byte_sel =  (wb_adr[16:RAM_ADDR_WIDTH] === FPGA_RAM_BASE_ADDRESS[16:RAM_ADDR_WIDTH]
                           && wb_cyc === 1'b1 && wb_stb === 1'b1 && wb_we  === 1'b1
                           && wb_ack === 1'b0) ?
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

assign wb_err = 0;

always @(posedge wb_clk or negedge rstn_i) begin
  if (~rstn_i) begin
    wb_ack                  <= 1'b0;
    complete_pulse_counter  <= 1'b0;
  end else begin
    wb_ack <= WBs_ACK_nxt;
    if (wb_adr[16:2] === COMPLETE_REG_ADDRESS[16:2] && complete_pulse_counter === 8'h0
        && wb_cyc === 1'b1 && wb_stb === 1'b1 && wb_we  === 1'b1 && wb_ack === 1'b0)
      complete_pulse_counter <= COMPLETE_PULSE_WIDTH;
    else
      complete_pulse_counter <= complete_pulse_counter - 1;
  end
end

// Define the how to read from each IP
always @(wb_adr or op_type or locality or buf_len or RAM_RD) begin
  if (wb_adr[16:RAM_ADDR_WIDTH] === FPGA_RAM_BASE_ADDRESS[16:RAM_ADDR_WIDTH])
    wb_dat_rd <= RAM_RD;
  else
    case (wb_adr[16:2])
      STATUS_REG_ADDRESS[16:2]:   wb_dat_rd <= {29'h0000000, complete, abort, exec};
      OP_TYPE_REG_ADDRESS[16:2]:  wb_dat_rd <= {28'h0000000, op_type};
      LOCALITY_REG_ADDRESS[16:2]: wb_dat_rd <= {28'h0000000, locality};
      BUF_SIZE_REG_ADDRESS[16:2]: wb_dat_rd <= {{(32-RAM_ADDR_WIDTH){1'b0}}, buf_len};
      default:                    wb_dat_rd <= DEFAULT_READ_VALUE;
    endcase
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

endmodule
