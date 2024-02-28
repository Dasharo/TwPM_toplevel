module arbiter (
    input  wire [ 1:0] switch_i,
    input  wire [31:0] challenge_i,
    output wire        resp_o
);

    wire [1:0] mux_out0;
    wire [1:0] mux_out1;
    wire [1:0] mux_out2;
    wire [1:0] mux_out3;
    wire [1:0] mux_out4;
    wire [1:0] mux_out5;
    wire [1:0] mux_out6;
    wire [1:0] mux_out7;
    wire [1:0] mux_out8;
    wire [1:0] mux_out9;
    wire [1:0] mux_out10;
    wire [1:0] mux_out11;
    wire [1:0] mux_out12;
    wire [1:0] mux_out13;
    wire [1:0] mux_out14;
    wire [1:0] mux_out15;
    wire [1:0] mux_out16;
    wire [1:0] mux_out17;
    wire [1:0] mux_out18;
    wire [1:0] mux_out19;
    wire [1:0] mux_out20;
    wire [1:0] mux_out21;
    wire [1:0] mux_out22;
    wire [1:0] mux_out23;
    wire [1:0] mux_out24;
    wire [1:0] mux_out25;
    wire [1:0] mux_out26;
    wire [1:0] mux_out27;
    wire [1:0] mux_out28;
    wire [1:0] mux_out29;
    wire [1:0] mux_out30;
    wire [1:0] mux_out31;

    switch s0 (.in(switch_i), .challenge(challenge_i[0]), .out(mux_out0));
    switch s1 (.in(mux_out0), .challenge(challenge_i[1]), .out(mux_out1));
    switch s2 (.in(mux_out1), .challenge(challenge_i[2]), .out(mux_out2));
    switch s3 (.in(mux_out2), .challenge(challenge_i[3]), .out(mux_out3));
    switch s4 (.in(mux_out3), .challenge(challenge_i[4]), .out(mux_out4));
    switch s5 (.in(mux_out4), .challenge(challenge_i[5]), .out(mux_out5));
    switch s6 (.in(mux_out5), .challenge(challenge_i[6]), .out(mux_out6));
    switch s7 (.in(mux_out6), .challenge(challenge_i[7]), .out(mux_out7));
    switch s8 (.in(mux_out7), .challenge(challenge_i[8]), .out(mux_out8));
    switch s9 (.in(mux_out8), .challenge(challenge_i[9]), .out(mux_out9));
    switch s10 (.in(mux_out9), .challenge(challenge_i[10]), .out(mux_out10));
    switch s11 (.in(mux_out10), .challenge(challenge_i[11]), .out(mux_out11));
    switch s12 (.in(mux_out11), .challenge(challenge_i[12]), .out(mux_out12));
    switch s13 (.in(mux_out12), .challenge(challenge_i[13]), .out(mux_out13));
    switch s14 (.in(mux_out13), .challenge(challenge_i[14]), .out(mux_out14));
    switch s15 (.in(mux_out14), .challenge(challenge_i[15]), .out(mux_out15));
    switch s16 (.in(mux_out15), .challenge(challenge_i[16]), .out(mux_out16));
    switch s17 (.in(mux_out16), .challenge(challenge_i[17]), .out(mux_out17));
    switch s18 (.in(mux_out17), .challenge(challenge_i[18]), .out(mux_out18));
    switch s19 (.in(mux_out18), .challenge(challenge_i[19]), .out(mux_out19));
    switch s20 (.in(mux_out19), .challenge(challenge_i[20]), .out(mux_out20));
    switch s21 (.in(mux_out20), .challenge(challenge_i[21]), .out(mux_out21));
    switch s22 (.in(mux_out21), .challenge(challenge_i[22]), .out(mux_out22));
    switch s23 (.in(mux_out22), .challenge(challenge_i[23]), .out(mux_out23));
    switch s24 (.in(mux_out23), .challenge(challenge_i[24]), .out(mux_out24));
    switch s25 (.in(mux_out24), .challenge(challenge_i[25]), .out(mux_out25));
    switch s26 (.in(mux_out25), .challenge(challenge_i[26]), .out(mux_out26));
    switch s27 (.in(mux_out26), .challenge(challenge_i[27]), .out(mux_out27));
    switch s28 (.in(mux_out27), .challenge(challenge_i[28]), .out(mux_out28));
    switch s29 (.in(mux_out28), .challenge(challenge_i[29]), .out(mux_out29));
    switch s30 (.in(mux_out29), .challenge(challenge_i[30]), .out(mux_out30));

    wire t;
    assign resp_o = ~(mux_out30[0] & t);
    assign t = ~(mux_out30[1] & resp_o);

endmodule
