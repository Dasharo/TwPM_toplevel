module r512x32_512x32 (A,WD,WClk,RClk,WClk_En,RClk_En,WEN,RD);

input [8:0] A;
input WClk,RClk;
input WClk_En,RClk_En;
input [3:0] WEN;
input [31:0] WD;
output reg [31:0] RD;

reg [31:0] mem [0:511];
integer    i;

always @(posedge WClk)
  begin
    if (RClk_En)
      RD <= mem[A];
    if (WClk_En)
      for (i = 0; i < 4; i++)
        if (WEN[i])
          mem[A][i*8 +: 8] <= WD[i*8 +: 8];
  end
endmodule
