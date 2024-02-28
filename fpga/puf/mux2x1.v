(* dont_touch = "true" *)
module mux2x1(
    input  wire a,
    input  wire b,
    input  wire sel,
    output wire out
);

assign out = sel ? b : a;

endmodule
