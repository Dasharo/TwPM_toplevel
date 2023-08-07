parameter OP_TYPE_REG_ADDRESS   = 17'h00000;      // 0x40020000
parameter LOCALITY_REG_ADDRESS  = 17'h00004;      // 0x40020004
parameter BUF_SIZE_REG_ADDRESS  = 17'h00008;      // 0x40020008
parameter COMPLETE_REG_ADDRESS  = 17'h00040;      // 0x40020400
parameter FPGA_RAM_BASE_ADDRESS = 17'h00800;      // 0x40020800
parameter DEFAULT_READ_VALUE    = 32'hBAD_FAB_AC; // Bad FPGA Access
parameter RAM_ADDR_WIDTH        = 11;

module TwPM_Top (
// LPC interface
  LCLK,
  LRESET,
  LFRAME,
  LAD,
  SERIRQ,
// M4 interface - to be removed
  complete
);


//------Port Parameters----------------
//


//------Port Signals-------------------

input         LCLK;
input         LRESET;
input         LFRAME;
inout   [3:0] LAD;
inout         SERIRQ;

input         complete;

//------Internal Signals---------------
//

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

// FPGA Global Signals
//
wire          WB_CLK         ; // Selected FPGA Clock
wire          Sys_Clk0       ; // Selected FPGA Clock
wire          Sys_Clk0_Rst   ; // Selected FPGA Reset
wire          Sys_Clk1       ; // Selected FPGA Clock
wire          Sys_Clk1_Rst   ; // Selected FPGA Reset

// Wishbone Bus Signals
//
wire  [16:0]  WBs_ADR        ; // Wishbone Address Bus
wire          WBs_CYC        ; // Wishbone Client Cycle  Strobe (i.e. Chip Select)
wire   [3:0]  WBs_BYTE_STB   ; // Wishbone Byte   Enables
wire          WBs_WE         ; // Wishbone Write  Enable Strobe
wire          WBs_RD         ; // Wishbone Read   Enable Strobe
wire          WBs_STB        ; // Wishbone Transfer      Strobe
reg   [31:0]  WBs_RD_DAT     ; // Wishbone Read   Data Bus
wire  [31:0]  WBs_WR_DAT     ; // Wishbone Write  Data Bus
reg           WBs_ACK        ; // Wishbone Client Acknowledge
wire          WB_RST         ; // Wishbone FPGA Reset
wire          WB_RST_FPGA    ; // Wishbone FPGA Reset

// Misc
//
wire          WBs_ACK_nxt;
wire  [15:0]  Device_ID = 16'h0123;   // TODO: decide what to do with it
wire          clk_48mhz;
wire          reset;

//------Logic Operations---------------
//

// Determine the FPGA reset
//
// Note: Reset the FPGA IP on either the AHB or clock domain reset signals.
//
gclkbuff u_gclkbuff_reset ( .A(Sys_Clk0_Rst | WB_RST) , .Z(WB_RST_FPGA) );
gclkbuff u_gclkbuff_clock ( .A(Sys_Clk0             ) , .Z(WB_CLK     ));

gclkbuff u_gclkbuff_reset1 ( .A(Sys_Clk1_Rst) , .Z(reset) );
gclkbuff u_gclkbuff_clock1  ( .A(Sys_Clk1   ) , .Z(clk_48mhz ) );

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
assign WB_RAM_A =         WBs_ADR[RAM_ADDR_WIDTH-1:2];    // 32b words
assign WB_RAM_byte_sel =  (WBs_ADR[16:RAM_ADDR_WIDTH] === FPGA_RAM_BASE_ADDRESS[16:RAM_ADDR_WIDTH]
                           && WBs_CYC === 1'b1 && WBs_STB === 1'b1 && WBs_WE  === 1'b1
                           && WBs_ACK === 1'b0) ?
                          WBs_BYTE_STB : 4'b0000;

// Combined RAM signals
assign RAM_A =        exec ? WB_RAM_A         : DP_RAM_A;
assign RAM_WD =       exec ? WBs_WR_DAT       : DP_RAM_WD;
assign RAM_byte_sel = exec ? WB_RAM_byte_sel  : DP_RAM_byte_sel;
// This is sketchy, may produce spurious edges and not give enough time for signals to stabilize
assign RAM_CLK =      exec ? WB_CLK           : ~LCLK;

// WB acknowledge signal
assign WBs_ACK_nxt = WBs_CYC & WBs_STB & (~WBs_ACK);

always @(posedge WB_CLK or posedge WB_RST) begin
  if (WB_RST)
    WBs_ACK <= 1'b0;
  else
    WBs_ACK <= WBs_ACK_nxt;
end

// Define the how to read from each IP
always @(WBs_ADR or op_type or locality or buf_len or RAM_RD) begin
  if (WBs_ADR[16:RAM_ADDR_WIDTH] === FPGA_RAM_BASE_ADDRESS[16:RAM_ADDR_WIDTH])
    WBs_RD_DAT <= RAM_RD;
  else
    case (WBs_ADR[16:2])
      OP_TYPE_REG_ADDRESS[16:2]:  WBs_RD_DAT <= {28'h0000000, op_type};
      LOCALITY_REG_ADDRESS[16:2]: WBs_RD_DAT <= {28'h0000000, locality};
      BUF_SIZE_REG_ADDRESS[16:2]: WBs_RD_DAT <= {{(32-RAM_ADDR_WIDTH){1'b0}}, buf_len};
      default:                    WBs_RD_DAT <= DEFAULT_READ_VALUE;
    endcase
end

// LPC Peripheral instantiation
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

// Empty Verilog model of QLAL4S3B
//
qlal4s3b_cell_macro u_qlal4s3b_cell_macro
(
  // AHB-To-FPGA Bridge
  //
  .WBs_ADR                   ( WBs_ADR              ), // output [16:0] | Address Bus                to   FPGA
  .WBs_CYC                   ( WBs_CYC              ), // output        | Cycle Chip Select          to   FPGA
  .WBs_BYTE_STB              ( WBs_BYTE_STB         ), // output  [3:0] | Byte Select                to   FPGA
  .WBs_WE                    ( WBs_WE               ), // output        | Write Enable               to   FPGA
  .WBs_RD                    ( WBs_RD               ), // output        | Read  Enable               to   FPGA
  .WBs_STB                   ( WBs_STB              ), // output        | Strobe Signal              to   FPGA
  .WBs_WR_DAT                ( WBs_WR_DAT           ), // output [31:0] | Write Data Bus             to   FPGA
  .WB_CLK                    ( WB_CLK               ), // input         | FPGA Clock                 from FPGA
  .WB_RST                    ( WB_RST               ), // output        | FPGA Reset                 to   FPGA
  .WBs_RD_DAT                ( WBs_RD_DAT           ), // input  [31:0] | Read Data Bus              from FPGA
  .WBs_ACK                   ( WBs_ACK              ), // input         | Transfer Cycle Acknowledge from FPGA
  //
  // SDMA Signals
  //
  .SDMA_Req                  ( 4'b0000              ), // input   [3:0]
  .SDMA_Sreq                 ( 4'b0000              ), // input   [3:0]
  .SDMA_Done                 (                      ), // output  [3:0]
  .SDMA_Active               (                      ), // output  [3:0]
  //
  // FB Interrupts
  //
  .FB_msg_out                ( {2'b00, abort, exec} ), // input   [3:0]
  .FB_Int_Clr                ( 8'h0                 ), // input   [7:0]
  .FB_Start                  (                      ), // output
  .FB_Busy                   ( 1'b0                 ), // input
  //
  // FB Clocks
  //
  .Sys_Clk0                  ( Sys_Clk0             ), // output
  .Sys_Clk0_Rst              ( Sys_Clk0_Rst         ), // output
  .Sys_Clk1                  ( Sys_Clk1             ), // output
  .Sys_Clk1_Rst              ( Sys_Clk1_Rst         ), // output
  //
  // Packet FIFO
  //
  .Sys_PKfb_Clk              (  1'b0                ), // input
  .Sys_PKfb_Rst              (                      ), // output
  .FB_PKfbData               ( 32'h0                ), // input  [31:0]
  .FB_PKfbPush               (  4'h0                ), // input   [3:0]
  .FB_PKfbSOF                (  1'b0                ), // input
  .FB_PKfbEOF                (  1'b0                ), // input
  .FB_PKfbOverflow           (                      ), // output
  //
  // Sensor Interface
  //
  .Sensor_Int                (                      ), // output  [7:0]
  .TimeStamp                 (                      ), // output [23:0]
  //
  // SPI Master APB Bus
  //
  .Sys_Pclk                  (                      ), // output
  .Sys_Pclk_Rst              (                      ), // output      <-- Fixed to add "_Rst"
  .Sys_PSel                  (  1'b0                ), // input
  .SPIm_Paddr                ( 16'h0                ), // input  [15:0]
  .SPIm_PEnable              (  1'b0                ), // input
  .SPIm_PWrite               (  1'b0                ), // input
  .SPIm_PWdata               ( 32'h0                ), // input  [31:0]
  .SPIm_Prdata               (                      ), // output [31:0]
  .SPIm_PReady               (                      ), // output
  .SPIm_PSlvErr              (                      ), // output
  //
  // Misc
  //
  .Device_ID                 ( Device_ID            ), // input  [15:0]
  //
  // FBIO Signals
  //
  .FBIO_In                   (                      ), // output [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
  .FBIO_In_En                (                      ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
  .FBIO_Out                  (                      ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
  .FBIO_Out_En               (                      ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
  //
  // ???
  //
  .SFBIO                     (                      ), // inout  [13:0]
  .Device_ID_6S              ( 1'b0                 ), // input
  .Device_ID_4S              ( 1'b0                 ), // input
  .SPIm_PWdata_26S           ( 1'b0                 ), // input
  .SPIm_PWdata_24S           ( 1'b0                 ), // input
  .SPIm_PWdata_14S           ( 1'b0                 ), // input
  .SPIm_PWdata_11S           ( 1'b0                 ), // input
  .SPIm_PWdata_0S            ( 1'b0                 ), // input
  .SPIm_Paddr_8S             ( 1'b0                 ), // input
  .SPIm_Paddr_6S             ( 1'b0                 ), // input
  .FB_PKfbPush_1S            ( 1'b0                 ), // input
  .FB_PKfbData_31S           ( 1'b0                 ), // input
  .FB_PKfbData_21S           ( 1'b0                 ), // input
  .FB_PKfbData_19S           ( 1'b0                 ), // input
  .FB_PKfbData_9S            ( 1'b0                 ), // input
  .FB_PKfbData_6S            ( 1'b0                 ), // input
  .Sys_PKfb_ClkS             ( 1'b0                 ), // input
  .FB_BusyS                  ( 1'b0                 ), // input
  .WB_CLKS                   ( 1'b0                 )  // input
);

//pragma attribute u_qlal4s3b_cell_macro        preserve_cell true
//pragma attribute RAM_INST                     preserve_cell true

endmodule
