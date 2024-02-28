module switch(
    input  wire [1:0] in,
    input  wire       challenge,
    output wire [1:0] out,
);

mux2x1 upper(.a(in[0]), .b(in[1]), .sel(challenge), .out(out[0]));
mux2x1 lower(.a(in[1]), .b(in[0]), .sel(challenge), .out(out[1]));

endmodule
