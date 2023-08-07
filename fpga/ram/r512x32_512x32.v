module r512x32_512x32 (A,RD,WD,Clk,WEN);

input       [8:0] A;
output reg [31:0] RD;
input      [31:0] WD;
input             Clk;
input       [3:0] WEN;

reg        [31:0] mem [0:511];
integer           i;

always @(posedge Clk)
  begin
    RD <= mem[A];
    for (i = 0; i < 4; i++)
      if (WEN[i])
        mem[A][i*8 +: 8] <= WD[i*8 +: 8];
  end
endmodule
