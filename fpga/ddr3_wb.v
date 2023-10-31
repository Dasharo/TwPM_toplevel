module ddr3_wb
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter DDR_MHZ          = 24
    ,parameter DDR_WRITE_LATENCY = 6
    ,parameter DDR_READ_LATENCY = 6
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // TODO: explicitly specify wire/reg for symbolator
    //# {{Global inputs}}
     input           clk_i
    ,input           rst_i

    //# {{WISHBONE interface}}
    // Inputs
    ,input           wb_we_i
    ,input  [ 31:0]  wb_adr_i
    ,input           wb_stb_i
    ,input  [ 31:0]  wb_dat_i
    ,input  [  3:0]  wb_sel_i
    ,input           wb_cyc_i
    // Outputs
    ,output          wb_ack_o
    ,output          wb_err_o
    ,output [ 31:0]  wb_dat_o

    //# {{DDR3 lines}}
    ,output [14:0]  ddram_a
    ,output [2:0]   ddram_ba
    ,output         ddram_ras_n
    ,output         ddram_cas_n
    ,output         ddram_we_n
    ,output [1:0]   ddram_dm
    ,inout [15:0]   ddram_dq
    ,inout [1:0]    ddram_dqs_p
    ,output         ddram_clk_p
    ,output         ddram_cke
    ,output         ddram_odt
);

//-----------------------------------------------------------------
// DFI interface
//-----------------------------------------------------------------
// PHY -> MC
wire [ 31:0]  dfi_rddata_w;
wire          dfi_rddata_valid_w;
wire [  1:0]  dfi_rddata_dnv_w;
// MC -> PHY
wire [ 14:0]  dfi_address_w;
wire [  2:0]  dfi_bank_w;
wire          dfi_cas_n_w;
wire          dfi_cke_w;
wire          dfi_cs_n_w;
wire          dfi_odt_w;
wire          dfi_ras_n_w;
wire          dfi_reset_n_w;
wire          dfi_we_n_w;
wire [ 31:0]  dfi_wrdata_w;
wire          dfi_wrdata_en_w;
wire [  3:0]  dfi_wrdata_mask_w;
wire          dfi_rddata_en_w;

//-----------------------------------------------------------------
// Clocking / Reset
//-----------------------------------------------------------------
wire [3:0] clk_pll_w;

ecp5pll
#(
   .in_hz(48000000)
  ,.out0_hz(24000000)
  ,.out1_hz(24000000)
  ,.out1_deg(90)
)
u_pll
(
     .clk_i(clk_i)
    ,.clk_o(clk_pll_w)
    ,.reset(1'b0)
    ,.standby(1'b0)
    ,.phasesel(2'b0)
    ,.phasedir(1'b0) 
    ,.phasestep(1'b0)
    ,.phaseloadreg(1'b0)
    ,.locked()
);

wire clk_w;
wire clk_ddr_w;

assign clk_w     = clk_pll_w[0]; // 24MHz
assign clk_ddr_w = clk_pll_w[1]; // 24MHz (90 degree phase shift)

reg [15:0] count_q = 16'b0;
reg       rst_q   = 1'b1;

always @(posedge clk_w)   // TODO: add rst_i maybe?
if (count_q != 16'hFFFF)
    count_q <= count_q + 16'd1;
else
    rst_q <= 1'b0;

//-----------------------------------------------------------------
// Glue logic between WISHBONE and DDR Core
//-----------------------------------------------------------------
wire [31:0]  ram_addr_w       = {4'b0, wb_adr_i[27:4], 4'b0};
wire         ram_rd_w         = wb_cyc_i & wb_stb_i & ~wb_we_i;
wire [15:0]  ram_wr_w         = ~{16{wb_cyc_i & wb_stb_i & wb_we_i}}; // {12'b1, {4{wb_cyc_i & wb_stb_i & wb_we_i}} & ~wb_sel_i};
wire [127:0] ram_write_data_w = {128'h55112233445566778899aabbccddeeff}; //, wb_dat_i};

wire [127:0]  ram_read_data_w;
wire          ram_ack_w;
wire          ram_error_w;

assign wb_dat_o = ram_read_data_w[31:0];
assign wb_err_o = ram_error_w;
assign wb_ack_o = ram_ack_w; // (ram_rd_w | (ram_wr_w[3:0] !== 4'hF)) & ram_ack_w;

//reg ack_q;
//always @(posedge clk_i) begin
//  ack_q <= (ram_rd_w | (ram_wr_w[3:0] !== 4'hF)) & ram_ack_w;
//end
//assign wb_ack_o = ack_q;

//-----------------------------------------------------------------
// DDR Core + PHY
//-----------------------------------------------------------------
ddr3_core
#(
     .DDR_MHZ(DDR_MHZ)
    ,.DDR_WRITE_LATENCY(DDR_WRITE_LATENCY)
    ,.DDR_READ_LATENCY(DDR_READ_LATENCY)
)
u_core
(
     .clk_i(clk_w)
    ,.rst_i(rst_q)

    ,.inport_wr_i(ram_wr_w)
    ,.inport_rd_i(ram_rd_w)
    ,.inport_req_id_i(16'b0)  // unused for WISHBONE
    ,.inport_addr_i(ram_addr_w)
    ,.inport_write_data_i(ram_write_data_w)
    ,.inport_accept_o()       // unused for WISHBONE
    ,.inport_ack_o(ram_ack_w)
    ,.inport_error_o(ram_error_w)
    ,.inport_read_data_o(ram_read_data_w)
    ,.inport_resp_id_o()      // unused for WISHBONE

    ,.cfg_enable_i(1'b1)
    ,.cfg_stb_i(1'b0)
    ,.cfg_data_i(32'b0)
    ,.cfg_stall_o()

    ,.dfi_address_o(dfi_address_w)
    ,.dfi_bank_o(dfi_bank_w)
    ,.dfi_cas_n_o(dfi_cas_n_w)
    ,.dfi_cke_o(dfi_cke_w)
    ,.dfi_cs_n_o(dfi_cs_n_w)
    ,.dfi_odt_o(dfi_odt_w)
    ,.dfi_ras_n_o(dfi_ras_n_w)
    ,.dfi_reset_n_o(dfi_reset_n_w)
    ,.dfi_we_n_o(dfi_we_n_w)
    ,.dfi_wrdata_o(dfi_wrdata_w)
    ,.dfi_wrdata_en_o(dfi_wrdata_en_w)
    ,.dfi_wrdata_mask_o(dfi_wrdata_mask_w)
    ,.dfi_rddata_en_o(dfi_rddata_en_w)
    ,.dfi_rddata_i(dfi_rddata_w)
    ,.dfi_rddata_valid_i(dfi_rddata_valid_w)
    ,.dfi_rddata_dnv_i(dfi_rddata_dnv_w)
);

ddr3_dfi_phy
#(
     .DQ_IN_DELAY_INIT("DELAY0")
    ,.TPHY_RDLAT(0)
)
u_phy
(
     .clk_i(clk_w)
    ,.rst_i(rst_q)

    ,.clk_ddr_i(clk_ddr_w)

    ,.cfg_valid_i(1'b0)

    ,.dfi_address_i(dfi_address_w)
    ,.dfi_bank_i(dfi_bank_w)
    ,.dfi_cas_n_i(dfi_cas_n_w)
    ,.dfi_cke_i(dfi_cke_w)
    ,.dfi_cs_n_i(dfi_cs_n_w)
    ,.dfi_odt_i(dfi_odt_w)
    ,.dfi_ras_n_i(dfi_ras_n_w)
    ,.dfi_reset_n_i(dfi_reset_n_w)
    ,.dfi_we_n_i(dfi_we_n_w)
    ,.dfi_wrdata_i(dfi_wrdata_w)
    ,.dfi_wrdata_en_i(dfi_wrdata_en_w)
    ,.dfi_wrdata_mask_i(dfi_wrdata_mask_w)
    ,.dfi_rddata_en_i(dfi_rddata_en_w)
    ,.dfi_rddata_o(dfi_rddata_w)
    ,.dfi_rddata_valid_o(dfi_rddata_valid_w)
    ,.dfi_rddata_dnv_o(dfi_rddata_dnv_w)
    
    ,.ddr3_ck_p_o(ddram_clk_p)
    ,.ddr3_cke_o(ddram_cke)
    ,.ddr3_reset_n_o()
    ,.ddr3_ras_n_o(ddram_ras_n)
    ,.ddr3_cas_n_o(ddram_cas_n)
    ,.ddr3_we_n_o(ddram_we_n)
    ,.ddr3_cs_n_o()
    ,.ddr3_ba_o(ddram_ba)
    ,.ddr3_addr_o(ddram_a)
    ,.ddr3_odt_o(ddram_odt)
    ,.ddr3_dm_o(ddram_dm)
    ,.ddr3_dqs_p_io(ddram_dqs_p)
    ,.ddr3_dq_io(ddram_dq)
);

endmodule
