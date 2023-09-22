parameter STATUS_REG_ADDRESS    = 17'h00000;      // 0x40020000
parameter OP_TYPE_REG_ADDRESS   = 17'h00004;      // 0x40020004
parameter LOCALITY_REG_ADDRESS  = 17'h00008;      // 0x40020008
parameter BUF_SIZE_REG_ADDRESS  = 17'h0000C;      // 0x4002000C
parameter COMPLETE_REG_ADDRESS  = 17'h00040;      // 0x40020040
parameter FPGA_RAM_BASE_ADDRESS = 17'h00800;      // 0x40020800
parameter DEFAULT_READ_VALUE    = 32'hBAD_FAB_AC; // Bad FPGA Access
parameter RAM_ADDR_WIDTH        = 11;
parameter COMPLETE_PULSE_WIDTH  = 20;

module TwPM_Top (
// LPC interface
  LCLK,
  LRESET,
  LFRAME,
  LAD,
  SERIRQ
);


//------Port Parameters----------------
//


//------Port Signals-------------------

input         LCLK;
input         LRESET;
input         LFRAME;
inout   [3:0] LAD;
inout         SERIRQ;

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


endmodule
