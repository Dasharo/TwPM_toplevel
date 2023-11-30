module lpc_top (
    //input  wire         clk_48m,
    //input  wire         rstn_i,
    input  wire         clk_i,
    input  wire         lreset,
    input  wire         lframe_i,
    inout  wire [  3:0] lad_bus,
    inout  wire         SERIRQ,
    output reg          led_r,
    output reg          led_g,
    output wire         led_b
);

`include "lpc_defines.v"

reg  [ 4:0] fsm_state = `LPC_ST_IDLE;
wire [ 4:0] fsm_next_state;
wire [ 3:0] next_lad_state;
wire        next_drive_lad;
reg  [ 3:0] r_lad_state;
reg         r_drive_lad;

/*reg         heartbeat = 0;
reg [ 26:0] heartbeat_div = 0;
reg [  3:0] tpm_cycle_detected = 0;

// Hearbeat
always @(posedge clk_i) begin
    if (heartbeat_div == 0) begin
        heartbeat_div = 33000000;
        heartbeat = ~heartbeat;

        if (tpm_cycle_detected != 0)
            tpm_cycle_detected = tpm_cycle_detected - 1;
    end else
        heartbeat_div = heartbeat_div - 1;

    if (fsm_state == `LPC_ST_ADDR_RD_CLK1) begin
        tpm_cycle_detected = 3;
    end
end

assign led_b = 1;

always @* begin
    led_r = ~heartbeat;
    if (tpm_cycle_detected != 0)
        led_g = ~heartbeat;
    else
        led_g = 1;
end*/

assign fsm_next_state = fsm_state == `LPC_ST_IDLE && lframe_i == 0 && lad_bus == `LPC_START ? `LPC_ST_START
                      : fsm_state == `LPC_ST_START && lframe_i == 1 && lad_bus == `LPC_IO_READ ? `LPC_ST_ADDR_RD_CLK1
                      : fsm_state == `LPC_ST_ADDR_RD_CLK1 ? `LPC_ST_ADDR_RD_CLK2
                      : fsm_state == `LPC_ST_ADDR_RD_CLK2 ? `LPC_ST_ADDR_RD_CLK3
                      : fsm_state == `LPC_ST_ADDR_RD_CLK3 ? `LPC_ST_ADDR_RD_CLK4
                      : fsm_state == `LPC_ST_ADDR_RD_CLK4 ? `LPC_ST_TAR_RD_CLK1
                      : fsm_state == `LPC_ST_TAR_RD_CLK1 ? `LPC_ST_TAR_RD_CLK2
                      : fsm_state == `LPC_ST_TAR_RD_CLK2 ? `LPC_ST_SYNC_RD
                      : fsm_state == `LPC_ST_SYNC_RD ? `LPC_ST_DATA_RD_CLK1
                      : fsm_state == `LPC_ST_DATA_RD_CLK1 ? `LPC_ST_DATA_RD_CLK2
                      : fsm_state == `LPC_ST_DATA_RD_CLK2 ? `LPC_ST_FINAL_TAR_CLK1
                      : fsm_state == `LPC_ST_FINAL_TAR_CLK1 ? `LPC_ST_FINAL_TAR_CLK2
                      : fsm_state == `LPC_ST_FINAL_TAR_CLK2 ? `LPC_ST_IDLE
                      : `LPC_ST_IDLE;

always @(negedge clk_i) begin
    fsm_state <= fsm_next_state;
end

always @(negedge clk_i) begin
    r_lad_state = next_lad_state;
    r_drive_lad = next_drive_lad;
end

assign next_lad_state = fsm_state == `LPC_ST_SYNC_RD ? `LPC_SYNC_READY
                      : fsm_state == `LPC_ST_DATA_RD_CLK1 ? 4'b0000
                      : fsm_state == `LPC_ST_DATA_RD_CLK2 ? 4'b0000
                      : fsm_state == `LPC_ST_FINAL_TAR_CLK1 ? 4'b1010
                      : 4'b1111;

assign next_drive_lad = fsm_state == `LPC_ST_SYNC_RD ? 1
                      : fsm_state == `LPC_ST_DATA_RD_CLK1 ? 1
                      : fsm_state == `LPC_ST_DATA_RD_CLK2 ? 1
                      : fsm_state == `LPC_ST_FINAL_TAR_CLK1 ? 1
                      : 0;

assign lad_bus = r_drive_lad ? r_lad_state : 4'bzzzz;
//assign lad_bus = r_drive_lad ? 4'b0000 : 4'bzzzz;

endmodule
