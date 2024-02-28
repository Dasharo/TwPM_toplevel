module puf (
    input  wire [ 1:0] switch_i,
    input  wire [31:0] challenge_i,
    output wire [95:0] id_o
);

arbiter arb0 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[0]) );
arbiter arb1 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[1]) );
arbiter arb2 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[2]) );
arbiter arb3 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[3]) );
arbiter arb4 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[4]) );
arbiter arb5 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[5]) );
arbiter arb6 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[6]) );
arbiter arb7 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[7]) );
arbiter arb8 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[8]) );
// arbiter arb9 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[9]) );
// arbiter arb10 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[10]) );
// arbiter arb11 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[11]) );
// arbiter arb12 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[12]) );
// arbiter arb13 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[13]) );
// arbiter arb14 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[14]) );
// arbiter arb15 ( .switch_i(switch_i), .challenge_i(challenge_i), .resp_o(id_o[15]) );

endmodule
