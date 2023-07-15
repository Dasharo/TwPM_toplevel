module TwPM_Top (
// LPC interface
      LCLK,
      LRESET,
      LFRAME,
      LAD,
      SERIRQ,
// M4 interface - to be removed
      exec,
      complete,
      abort
);


//------Port Parameters----------------
//


//------Port Signals-------------------

input         LCLK;
input         LRESET;
input         LFRAME;
inout   [3:0] LAD;
inout         SERIRQ;

output        exec;
input         complete;
output        abort;

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
wire   [10:0] DP_addr;
wire    [7:0] DP_data_rd;
wire    [7:0] DP_data_wr;

// RAM lines
wire    [8:0] RAM_A;
wire   [31:0] RAM_WD;
wire   [31:0] RAM_RD;
wire          RAM_rd_clk_en;
wire          RAM_wr_clk_en;
wire    [3:0] RAM_byte_sel;

// FPGA Global Signals
//
wire            WB_CLK         ; // Selected FPGA Clock

wire            Sys_Clk0       ; // Selected FPGA Clock
wire            Sys_Clk0_Rst   ; // Selected FPGA Reset

wire            Sys_Clk1       ; // Selected FPGA Clock
wire            Sys_Clk1_Rst   ; // Selected FPGA Reset

// Wishbone Bus Signals
//
wire    [16:0]  WBs_ADR        ; // Wishbone Address Bus
wire            WBs_CYC        ; // Wishbone Client Cycle  Strobe (i.e. Chip Select)
wire     [3:0]  WBs_BYTE_STB   ; // Wishbone Byte   Enables
wire            WBs_WE         ; // Wishbone Write  Enable Strobe
wire            WBs_RD         ; // Wishbone Read   Enable Strobe
wire            WBs_STB        ; // Wishbone Transfer      Strobe
wire    [31:0]  WBs_RD_DAT     ; // Wishbone Read   Data Bus
wire    [31:0]  WBs_WR_DAT     ; // Wishbone Write  Data Bus
wire            WBs_ACK        ; // Wishbone Client Acknowledge
wire            WB_RST         ; // Wishbone FPGA Reset
wire            WB_RST_FPGA    ; // Wishbone FPGA Reset

// Misc
//
wire    [31:0]  Device_ID;
wire            boot;
wire            clk_48mhz;
wire            reset;


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

assign RAM_A =    DP_addr[10:2];    // 32b words
// TODO: check if endianness needs changing in below assignments
assign RAM_WD =       DP_addr[1:0] === 2'b00 ? {24'h000000, DP_data_wr} :
                      DP_addr[1:0] === 2'b01 ? {16'h0000, DP_data_wr, 8'h00} :
                      DP_addr[1:0] === 2'b10 ? {8'h00, DP_data_wr, 16'h0000} :
                      DP_addr[1:0] === 2'b11 ? {DP_data_wr, 24'h000000} :
                      32'h00000000;

assign DP_data_rd =   DP_addr[1:0] === 2'b00 ? RAM_RD[ 7: 0] :
                      DP_addr[1:0] === 2'b01 ? RAM_RD[15: 8] :
                      DP_addr[1:0] === 2'b10 ? RAM_RD[23:16] :
                      DP_addr[1:0] === 2'b11 ? RAM_RD[31:24] :
                      8'hFF;

assign RAM_byte_sel = DP_addr[1:0] === 2'b00 ? 4'b0001 :
                      DP_addr[1:0] === 2'b01 ? 4'b0010 :
                      DP_addr[1:0] === 2'b10 ? 4'b0100 :
                      DP_addr[1:0] === 2'b11 ? 4'b1000 :
                      4'b0000;

// Example FPGA Design
//
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
      .exec(exec),
      .complete(complete),
      .abort(abort),
      // Signals to/from RAM
      .RAM_addr(DP_addr),
      .RAM_data_rd(DP_data_rd),
      .RAM_data_wr(DP_data_wr),
      .RAM_rd(RAM_rd_clk_en),
      .RAM_wr(RAM_wr_clk_en)
  );

r512x32_512x32 RAM_INST (
			.A(RAM_A),
			.WD(RAM_WD),
			.WClk(~LCLK),
			.RClk(~LCLK),
			.WClk_En(RAM_wr_clk_en),
			.RClk_En(RAM_rd_clk_en),
			.WEN(RAM_byte_sel),
			.RD(RAM_RD)
			);

// Empty Verilog model of QLAL4S3B
//
qlal4s3b_cell_macro              u_qlal4s3b_cell_macro
                               (
    // AHB-To-FPGA Bridge
	//
    .WBs_ADR                   ( WBs_ADR                     ), // output [16:0] | Address Bus                to   FPGA
    .WBs_CYC                   ( WBs_CYC                     ), // output        | Cycle Chip Select          to   FPGA
    .WBs_BYTE_STB              ( WBs_BYTE_STB                ), // output  [3:0] | Byte Select                to   FPGA
    .WBs_WE                    ( WBs_WE                      ), // output        | Write Enable               to   FPGA
    .WBs_RD                    ( WBs_RD                      ), // output        | Read  Enable               to   FPGA
    .WBs_STB                   ( WBs_STB                     ), // output        | Strobe Signal              to   FPGA
    .WBs_WR_DAT                ( WBs_WR_DAT                  ), // output [31:0] | Write Data Bus             to   FPGA
    .WB_CLK                    ( WB_CLK                      ), // input         | FPGA Clock               from FPGA
    .WB_RST                    ( WB_RST                      ), // output        | FPGA Reset               to   FPGA
    .WBs_RD_DAT                ( WBs_RD_DAT                  ), // input  [31:0] | Read Data Bus              from FPGA
    .WBs_ACK                   ( WBs_ACK                     ), // input         | Transfer Cycle Acknowledge from FPGA
    //
    // SDMA Signals
    //
    .SDMA_Req                  (4'b0000						 ), // input   [3:0]
    .SDMA_Sreq                 (4'b0000		                 ), // input   [3:0]
    .SDMA_Done                 (  							 ), // output  [3:0]
    .SDMA_Active               ( 							 ), // output  [3:0]
    //
    // FB Interrupts
    //
    //.FB_msg_out                ( {  3'b000,  boot           }), // input   [3:0]
    .FB_msg_out                ( {  4'b0000                 }), // input   [3:0]
    .FB_Int_Clr                (  8'h0                       ), // input   [7:0]
    .FB_Start                  (                             ), // output
    .FB_Busy                   (  1'b0                       ), // input
    //
    // FB Clocks
    //
    .Clk_C16                   ( Sys_Clk0                    ), // output
    .Clk_C16_Rst               ( Sys_Clk0_Rst                ), // output
    .Clk_C21                   ( Sys_Clk1                    ), // output
    .Clk_C21_Rst               ( Sys_Clk1_Rst                ), // output
    //
    // Packet FIFO
    //
    .Sys_PKfb_Clk              (  1'b0                       ), // input
    .Sys_PKfb_Rst              (                             ), // output
    .FB_PKfbData               ( 32'h0                       ), // input  [31:0]
    .FB_PKfbPush               (  4'h0                       ), // input   [3:0]
    .FB_PKfbSOF                (  1'b0                       ), // input
    .FB_PKfbEOF                (  1'b0                       ), // input
    .FB_PKfbOverflow           (                             ), // output
	//
	// Sensor Interface
	//
    .Sensor_Int                (                             ), // output  [7:0]
    .TimeStamp                 (                             ), // output [23:0]
    //
    // SPI Master APB Bus
    //
    .Sys_Pclk                  (                             ), // output
    .Sys_Pclk_Rst              (                             ), // output      <-- Fixed to add "_Rst"
    .Sys_PSel                  (  1'b0                       ), // input
    .SPIm_Paddr                ( 16'h0                       ), // input  [15:0]
    .SPIm_PEnable              (  1'b0                       ), // input
    .SPIm_PWrite               (  1'b0                       ), // input
    .SPIm_PWdata               ( 32'h0                       ), // input  [31:0]
    .SPIm_Prdata               (                             ), // output [31:0]
    .SPIm_PReady               (                             ), // output
    .SPIm_PSlvErr              (                             ), // output
    //
    // Misc
    //
    .Device_ID                 ( Device_ID[15:0]             ), // input  [15:0]
    //
    // FBIO Signals
    //
    .FBIO_In                   (                             ), // output [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
    .FBIO_In_En                (                             ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
    .FBIO_Out                  (                             ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
    .FBIO_Out_En               (                             ), // input  [13:0] <-- Do Not make any connections; Use Constraint manager in SpDE to sFBIO
	//
	// ???
	//
    .SFBIO                     (                             ), // inout  [13:0]
    .Device_ID_6S              ( 1'b0                        ), // input
    .Device_ID_4S              ( 1'b0                        ), // input
    .SPIm_PWdata_26S           ( 1'b0                        ), // input
    .SPIm_PWdata_24S           ( 1'b0                        ), // input
    .SPIm_PWdata_14S           ( 1'b0                        ), // input
    .SPIm_PWdata_11S           ( 1'b0                        ), // input
    .SPIm_PWdata_0S            ( 1'b0                        ), // input
    .SPIm_Paddr_8S             ( 1'b0                        ), // input
    .SPIm_Paddr_6S             ( 1'b0                        ), // input
    .FB_PKfbPush_1S            ( 1'b0                        ), // input
    .FB_PKfbData_31S           ( 1'b0                        ), // input
    .FB_PKfbData_21S           ( 1'b0                        ), // input
    .FB_PKfbData_19S           ( 1'b0                        ), // input
    .FB_PKfbData_9S            ( 1'b0                        ), // input
    .FB_PKfbData_6S            ( 1'b0                        ), // input
    .Sys_PKfb_ClkS             ( 1'b0                        ), // input
    .FB_BusyS                  ( 1'b0                        ), // input
    .WB_CLKS                   ( 1'b0                        )  // input
                                                             );

//pragma attribute u_qlal4s3b_cell_macro        preserve_cell true
//pragma attribute RAM_INST                     preserve_cell true

endmodule
