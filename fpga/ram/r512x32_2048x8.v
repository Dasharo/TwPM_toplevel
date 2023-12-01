module r512x32_2048x8 (ADDR_A,RD_A,WD_A,Clk_A,WEN_A,
                       ADDR_B,RD_B,WD_B,Clk_B,WEN_B);

input  wire  [8:0] ADDR_A;
output wire [31:0] RD_A;
input  wire [31:0] WD_A;
input  wire        Clk_A;
input  wire  [3:0] WEN_A;

input  wire [10:0] ADDR_B;
output wire  [7:0] RD_B;
input  wire  [7:0] WD_B;
input  wire        Clk_B;
input  wire        WEN_B;

wire [31:0] RD_B_F;

assign RD_B = (ADDR_B[1:0] == 2'b00) ? RD_B_F[7:0] :
              (ADDR_B[1:0] == 2'b01) ? RD_B_F[15:8] :
              (ADDR_B[1:0] == 2'b10) ? RD_B_F[23:16] :
              RD_B_F[31:24];
DP16KD_wrap #(
  .CSDECODE_B(3'b000),
) b0 (
  .ADA(ADDR_A),
  .DIA(WD_A[7:0]),
  .CLKA(Clk_A),
  .DOA(RD_A[7:0]),
  .WEA(WEN_A[0]),
  .ADB(ADDR_B),
  .DIB(WD_B),
  .CLKB(Clk_B),
  .DOB(RD_B_F[7:0]),
  .WEB((ADDR_B[1:0] == 2'b00) && WEN_B),
);

DP16KD_wrap #(
  .CSDECODE_B(3'b001),
) b1 (
  .ADA(ADDR_A),
  .DIA(WD_A[15:8]),
  .CLKA(Clk_A),
  .DOA(RD_A[15:8]),
  .WEA(WEN_A[1]),
  .ADB(ADDR_B),
  .DIB(WD_B),
  .CLKB(Clk_B),
  .DOB(RD_B_F[15:8]),
  .WEB((ADDR_B[1:0] == 2'b01) && WEN_B),
);

DP16KD_wrap #(
  .CSDECODE_B(3'b010),
) b2 (
  .ADA(ADDR_A),
  .DIA(WD_A[23:16]),
  .CLKA(Clk_A),
  .DOA(RD_A[23:16]),
  .WEA(WEN_A[2]),
  .ADB(ADDR_B),
  .DIB(WD_B),
  .CLKB(Clk_B),
  .DOB(RD_B_F[23:16]),
  .WEB((ADDR_B[1:0] == 2'b10) && WEN_B),
);

DP16KD_wrap #(
  .CSDECODE_B(3'b011),
) b3 (
  .ADA(ADDR_A),
  .DIA(WD_A[31:24]),
  .CLKA(Clk_A),
  .DOA(RD_A[31:24]),
  .WEA(WEN_A[3]),
  .ADB(ADDR_B),
  .DIB(WD_B),
  .CLKB(Clk_B),
  .DOB(RD_B_F[31:24]),
  .WEB((ADDR_B[1:0] == 2'b11) && WEN_B),
);

endmodule

module DP16KD_wrap (ADA,DIA,CLKA,DOA,WEA,ADB,DIB,CLKB,DOB,WEB);

input  wire  [8:0] ADA;
input  wire  [7:0] DIA;
input  wire        CLKA;
output wire  [7:0] DOA;
input  wire        WEA;
input  wire [10:0] ADB;
input  wire  [7:0] DIB;
input  wire        CLKB;
output wire  [7:0] DOB;
input  wire        WEB;

parameter CSDECODE_B = 3'b000;

DP16KD #(
  .DATA_WIDTH_A(8),
  .DATA_WIDTH_B(8),
  .CSDECODE_B(CSDECODE_B),
) dp16kd (
  // Inputs:
  .ADA13(1'b0),
  .ADA12(1'b0),
  .ADA11(1'b0),
  .ADA10(1'b0),
  .ADA9(1'b0),
  .ADA8(ADA[8]),
  .ADA7(ADA[7]),
  .ADA6(ADA[6]),
  .ADA5(ADA[5]),
  .ADA4(ADA[4]),
  .ADA3(ADA[3]),
  .ADA2(ADA[2]),
  .ADA1(ADA[1]),
  .ADA0(ADA[0]),
  .DIA17(1'b0),
  .DIA16(1'b0),
  .DIA15(1'b0),
  .DIA14(1'b0),
  .DIA13(1'b0),
  .DIA12(1'b0),
  .DIA11(1'b0),
  .DIA10(1'b0),
  .DIA9(1'b0),
  .DIA8(1'b0),
  .DIA7(DIA[7]),
  .DIA6(DIA[6]),
  .DIA5(DIA[5]),
  .DIA4(DIA[4]),
  .DIA3(DIA[3]),
  .DIA2(DIA[2]),
  .DIA1(DIA[1]),
  .DIA0(DIA[0]),
  .CLKA(CLKA),
  .CEA(1'b1),
  .OCEA(1'b1),
  .RSTA(1'b0),
  .WEA(WEA),
  .CSA2(1'b0),
  .CSA1(1'b0),
  .CSA0(1'b0),
  .ADB13(1'b0),
  .ADB12(1'b0),
  .ADB11(1'b0),
  .ADB10(1'b0),
  .ADB9(1'b0),
  .ADB8(ADB[10]),   // Note: address shifted by 2, lowest bits are in CSB
  .ADB7(ADB[9]),
  .ADB6(ADB[8]),
  .ADB5(ADB[7]),
  .ADB4(ADB[6]),
  .ADB3(ADB[5]),
  .ADB2(ADB[4]),
  .ADB1(ADB[3]),
  .ADB0(ADB[2]),
  .DIB17(1'b0),
  .DIB16(1'b0),
  .DIB15(1'b0),
  .DIB14(1'b0),
  .DIB13(1'b0),
  .DIB12(1'b0),
  .DIB11(1'b0),
  .DIB10(1'b0),
  .DIB9(1'b0),
  .DIB8(1'b0),
  .DIB7(DIB[7]),
  .DIB6(DIB[6]),
  .DIB5(DIB[5]),
  .DIB4(DIB[4]),
  .DIB3(DIB[3]),
  .DIB2(DIB[2]),
  .DIB1(DIB[1]),
  .DIB0(DIB[0]),
  .CLKB(CLKB),
  .CEB(1'b1),
  .OCEB(1'b1),
  .RSTB(1'b0),
  .WEB(WEB),
  .CSB2(1'b0),
  .CSB1(ADB[1]),
  .CSB0(ADB[0]),

  // Outputs:
  .DOA17(),
  .DOA16(),
  .DOA15(),
  .DOA14(),
  .DOA13(),
  .DOA12(),
  .DOA11(),
  .DOA10(),
  .DOA9(),
  .DOA8(),
  .DOA7(DOA[7]),
  .DOA6(DOA[6]),
  .DOA5(DOA[5]),
  .DOA4(DOA[4]),
  .DOA3(DOA[3]),
  .DOA2(DOA[2]),
  .DOA1(DOA[1]),
  .DOA0(DOA[0]),
  .DOB17(),
  .DOB16(),
  .DOB15(),
  .DOB14(),
  .DOB13(),
  .DOB12(),
  .DOB11(),
  .DOB10(),
  .DOB9(),
  .DOB8(),
  .DOB7(DOB[7]),
  .DOB6(DOB[6]),
  .DOB5(DOB[5]),
  .DOB4(DOB[4]),
  .DOB3(DOB[3]),
  .DOB2(DOB[2]),
  .DOB1(DOB[1]),
  .DOB0(DOB[0]),
);

endmodule
