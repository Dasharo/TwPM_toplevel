// SPDX-License-Identifier: LGPL-2.1-or-later
//
// Copyright (C) 2023 3mdeb Sp. z o.o.

`timescale 1 ns / 1 ps

`include "lpc_defines.v"
`include "defines.v"

module top_tb ();

parameter TPM_RAM_ADDR_WIDTH    = 11;

//# {{LPC interface}}
reg         LCLK;
reg         LRESET;
reg         LFRAME;
inout  wire [  3:0] LAD;
inout  wire         SERIRQ;

reg     [7:0] data;

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

reg     [3:0] LAD_reg = 4'h0;
reg           drive_lad = 0;
reg    [15:0] addr_iter;
assign LAD = drive_lad ? LAD_reg : 4'hz;

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

// Combined RAM signals
assign RAM_A =        DP_RAM_A;
assign RAM_WD =       DP_RAM_WD;
assign RAM_byte_sel = DP_RAM_byte_sel;
assign RAM_CLK =      ~LCLK;

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


  task lpc_addr_task (input [15:0] addr);
    begin
      @(negedge LCLK) LAD_reg = addr[15:12];  // ADDR
      @(negedge LCLK) LAD_reg = addr[11:8];
      @(negedge LCLK) LAD_reg = addr[7:4];
      @(negedge LCLK) LAD_reg = addr[3:0];
    end
  endtask

  task lpc_tar_h2p_sync (input rsp_expected);
    begin
      @(negedge LCLK) LAD_reg = 4'hF;         // TAR1
      @(negedge LCLK) drive_lad = 0;
      @(posedge LCLK) if (LAD !== 4'hz)       // TAR2
        $display("### LAD driven on TAR2 @ %t", $realtime);
      // Forked threads would hit previous posedge, skip it manually
      @(negedge LCLK);
      fork : fs                               // SYNC
        begin
          @(posedge LCLK) begin
            if (LRESET && rsp_expected) begin
              if (LAD !== `LPC_SYNC_READY && LAD !== `LPC_SYNC_LWAIT)
                $display("### Unexpected LAD on SYNC (%b) @ %t", LAD, $realtime);
            end else if (LRESET == 0 && LAD !== 4'hz)
              $display("### LAD driven during reset on SYNC (%b) @ %t", LAD, $realtime);
            else if (rsp_expected == 0 && LAD !== 4'hz)
              $display("### LAD driven for bad START/CYCDIR on SYNC (%b) @ %t", LAD, $realtime);
            else if (rsp_expected == 0 && LAD === 4'hz)
              disable fs;
          end
        end
        begin
          @(posedge LCLK && LAD === `LPC_SYNC_READY && LRESET && rsp_expected) disable fs;
        end
      join
    end
  endtask

  task lpc_tar_p2h (input rsp_expected);
    begin
      @(posedge LCLK)                         // TAR1
      if (LRESET == 0 && LAD !== 4'hz)
        $display("### LAD driven on TAR1 during reset (%b) @ %t", LAD, $realtime);
      else if (rsp_expected == 0 && LAD !== 4'hz)
        $display("### LAD driven on TAR1 for bad START/CYCDIR (%b) @ %t", LAD, $realtime);
      else if (LRESET && rsp_expected && LAD === 4'hz)
        $display("### LAD not driven on TAR1 @ %t", $realtime);
      else if (LRESET && rsp_expected && LAD !== 4'hF)
        $display("### Unexpected LAD on TAR1 (%b) @ %t", LAD, $realtime);
      @(posedge LCLK)                         // TAR2
      if (LRESET == 1 && LAD !== 4'hz)
        $display("### LAD driven on TAR2 @ %t", $realtime);
      // Task should end on negedge, but because it also starts on negedge we end after posedge
      // here to make back-to-back invocations possible
    end
  endtask

  task lpc_data_read (input rsp_expected, output [3:0] data);
    begin
      @(posedge LCLK)                         // DATA
      if ((LAD[0] === 1'bx || LAD[1] === 1'bx || LAD[2] === 1'bx || LAD[3] === 1'bx ||
           LAD[0] === 1'bz || LAD[1] === 1'bz || LAD[2] === 1'bz || LAD[3] === 1'bz) &&
          LRESET && rsp_expected)
        $display("### Unexpected LAD on DATA (%b) @ %t", LAD, $realtime);
      else if (LRESET == 0 && LAD !== 4'hz)
        $display("### LAD driven on DATA during reset (%b) @ %t", LAD, $realtime);
      else if (rsp_expected == 0 && LAD !== 4'hz)
        $display("### LAD driven on DATA for bad START/CYCDIR (%b) @ %t", LAD, $realtime);
      else data = LAD;
    end
  endtask

  task lpc_write (input [3:0] start, input [3:0] cycdir, input [15:0] addr, input [7:0] data);
    reg rsp_expected;
    begin
      @(negedge LCLK);
      drive_lad = 1;
      LFRAME = 0;
      LAD_reg = start;                          // START
      @(posedge LCLK)
        if ((LAD === `LPC_START) && (cycdir === `LPC_IO_WRITE))
          rsp_expected = 1;
        else
          rsp_expected = 0;
      @(negedge LCLK) LFRAME = 1;
      LAD_reg = cycdir;                         // CYCTYPE + DIR
      lpc_addr_task (addr);                     // ADDR
      @(negedge LCLK) LAD_reg = data[3:0];      // DATA
      @(negedge LCLK) LAD_reg = data[7:4];
      lpc_tar_h2p_sync (rsp_expected);          // TAR, SYNC
      lpc_tar_p2h (rsp_expected);               // TAR
    end
  endtask

  task lpc_read (input [3:0] start, input [3:0] cycdir, input [15:0] addr, output [7:0] data);
    reg rsp_expected;
    begin
      @(negedge LCLK);
      drive_lad = 1;
      LFRAME = 0;
      LAD_reg = start;                          // START
      @(posedge LCLK)
        if ((LAD === `LPC_START) && (cycdir === `LPC_IO_READ))
          rsp_expected = 1;
        else
          rsp_expected = 0;
      @(negedge LCLK) LFRAME = 1;
      LAD_reg = cycdir;                         // CYCTYPE + DIR
      lpc_addr_task (addr);                     // ADDR
      lpc_tar_h2p_sync (rsp_expected);          // TAR, SYNC
      lpc_data_read (rsp_expected, data[3:0]);  // DATA1
      lpc_data_read (rsp_expected, data[7:4]);  // DATA2
      lpc_tar_p2h (rsp_expected);               // TAR
    end
  endtask

  task tpm_write (input [15:0] addr, input [7:0] data);
    lpc_write (`LPC_START, `LPC_IO_WRITE, addr, data);
  endtask

  task tpm_read (input [15:0] addr, output [7:0] data);
    lpc_read (`LPC_START, `LPC_IO_READ, addr, data);
  endtask


  initial begin
    LCLK = 1'b1;
    forever #20 LCLK = ~LCLK;
  end

  initial begin
    // Initialize
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
    $timeformat(-9, 0, " ns", 10);

    LFRAME       = 1;
    #40 LRESET   = 0;
    #250 LRESET  = 1;

    for (addr_iter = 0; addr_iter < 16'h0080; addr_iter = addr_iter + 1) begin
      tpm_read (addr_iter, data);
      $display("0x%4h = 0x%2h", addr_iter, data);
    end

    #500;
    //------------------------------
    $stop;
    $finish;
  end

endmodule
