module top (clk_i, rstn_i, uart0_rxd_i, uart0_txd_o, led_r, led_g, led_b);

input  wire         clk_i;
input  wire         rstn_i;

input  wire         uart0_rxd_i;
output wire         uart0_txd_o;

output wire         led_r;
output wire         led_g;
output wire         led_b;

wire                clk_10mhz; // 9.600000 MHz
wire                clk_5mhz; // 5.025000 MHz
wire                clk_8mhz; // 8.040000 MHz
wire                clk_96mhz; // 96.000000 MHz
wire                clk_192mhz; // 192.000000 MHz
wire                clk_58mhz; // 57.600000 MHz
wire                pll1_locked;
wire                pll2_locked;
wire                plls_locked;

wire                cpu_led_r;
wire                cpu_led_g;
wire                cpu_led_b;

pll1 pll_1 (
    .CLKI(clk_i),
    .RST(1'b0),
    .CLKOP(clk_10mhz),
    .CLKOS(clk_5mhz),
    .CLKOS2(clk_8mhz),
    .LOCK(pll1_locked)
);

pll2 pll_2 (
    .CLKI(clk_i),
    .RST(1'b0),
    .CLKOP(clk_96mhz),
    .CLKOS(clk_192mhz),
    .CLKOS2(clk_58mhz),
    .LOCK(pll2_locked)
);

neorv32_wrapper cpu (
    .clk_i(clk_96mhz),
    .rstn_i(rstn_i),
    .uart0_rxd_i(uart0_rxd_i),
    .uart0_txd_o(uart0_txd_o),
    .led_r(cpu_led_r),
    .led_g(cpu_led_g),
    .led_b(cpu_led_b)
);

assign plls_locked = pll1_locked & pll2_locked;

assign led_r = cpu_led_r;
assign led_g = ~plls_locked;
assign led_b = cpu_led_b;

endmodule
