module draw_pixelgen
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [31:0]	REG_SETFCOLOR,
  input       	REG_SETSTMODE,
  input [3:0]	REG_SETSCOLOR_MASK,
  input [31:0]	REG_SETSCOLOR_L,
  input [31:0]	REG_SETSCOLOR_H,
  input       	REG_SETBLENDOFF,
  input [2:0]	REG_SETBLENDALPHA_A,
  input [2:0]	REG_SETBLENDALPHA_B,
  input [2:0]	REG_SETBLENDALPHA_C,
  input [2:0]	REG_SETBLENDALPHA_D,
  input [2:0]	REG_SETBLENDALPHA_E,
  input [7:0]	REG_SETBLENDALPHA_SRCCA,
  input [31:0]	REG_SETBLENDALPHA_COEF0,
  input [31:0]	REG_SETBLENDALPHA_COEF1,
  input       	READYPAT_PIXEL,
  input       	READYBIT_PIXEL,
  input       	STARTBLT_PIXEL,
  input [63:0]	SRC_DATA,
  input       	SRC_VALID,
  input [63:0]	DST_DATA,
  input       	DST_VALID,
  input       	SRC_EMPTY,
  input       	SRC_FULL,
  input       	DST_EMPTY,
  input       	DST_FULL,
  input       	WR_EMPTY,
  input       	WR_FULL,
  output       	BUSY,
  output       	SRC_RD,
  output       	DST_RD,
  output       	WR_WR,
  output [63:0]	PIXEL_DATA,
  output [3:0]	ERROR
);

wire            wStInValid;
wire            wFinishSt1;
wire            wFinishSt2;
wire   [31:0]   wColorSt1;
wire   [31:0]   wColorSt2;
wire   [31:0]   wDstSt1, wDstSt2;
wire   [31:0]   wSrc1, wSrc2;
wire   [31:0]   wDst1, wDst2;

wire   [7:0]    wColorBlendA1, wColorBlendA2;
wire   [7:0]    wColorBlendR1, wColorBlendR2;
wire   [7:0]    wColorBlendG1, wColorBlendG2;
wire   [7:0]    wColorBlendB1, wColorBlendB2;
wire   [3:0]    wFinishBlend1, wFinishBlend2;

wire    [31:0]    wA1, wA2;
wire    [31:0]    wB1, wB2;
wire    [31:0]    wC1, wC2;
wire    [31:0]    wD1, wD2;
wire    [31:0]    wE1, wE2;

reg             rSrcRd;
reg             rDstRd;

reg    [31:0]    rSrc1;
reg    [31:0]    rSrc2;
reg              rSrcValid;

reg    [31:0]    rDst1;
reg    [31:0]    rDst2;
reg              rDstValid;

reg             rWrWR;
reg    [63:0]   rPixelData;
//-------------------------------------------------------------------------
//データをレジスタで受ける
//-------------------------------------------------------------------------
//SRC
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rSrc1 <= 0;
        else if(INIT)
                rSrc1 <= 0;
        else if(READYPAT_PIXEL)
                rSrc1 <= REG_SETFCOLOR;
        else
                rSrc1 <= SRC_DATA[63:32];
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rSrc2 <= 0;
        else if(INIT)
                rSrc2 <= 0;
        else if(READYPAT_PIXEL)
                rSrc2 <= REG_SETFCOLOR;
        else
                rSrc2 <= SRC_DATA[31:0];
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rSrcValid <= 0;
        else if(INIT)
                rSrcValid <= 0;
        else if(READYPAT_PIXEL)
                rSrcValid <= 1;
        else
                rSrcValid <= SRC_VALID;
end
//DST
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rDst1 <= 0;
        else if(INIT)
                rDst1 <= 0;
        else
                rDst1 <= DST_DATA[63:32];
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rDst2 <= 0;
        else if(INIT)
                rDst2 <= 0;
        else
                rDst2 <= DST_DATA[31:0];
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rDstValid <= 0;
        else if(INIT)
                rDstValid <= 0;
        else
                rDstValid <= DST_VALID;
end
//-------------------------------------------------------------------------
//BUSY作成
//-------------------------------------------------------------------------
assign BUSY = 0;
//-------------------------------------------------------------------------
//RD作成
//-------------------------------------------------------------------------
always @* begin
        if(READYPAT_PIXEL && !DST_EMPTY && !WR_FULL)
                rDstRd <= 1;
        else if(READYBIT_PIXEL && !SRC_EMPTY && !DST_EMPTY && !WR_FULL)
                rDstRd <= 1;
        else
                rDstRd <= 0;
end
always @* begin
        if(READYBIT_PIXEL && !SRC_EMPTY && !DST_EMPTY && !WR_FULL)
                rSrcRd <= 1;
        else
                rSrcRd <= 0;
end
assign DST_RD = rDstRd;
assign SRC_RD = rSrcRd;
//-------------------------------------------------------------------------
//VALID作成
//-------------------------------------------------------------------------
assign wStInValid = rSrcValid & rDstValid;
//-------------------------------------------------------------------------
//透過色
//-------------------------------------------------------------------------
assign wSrc1 = rSrc1;
assign wSrc2 = rSrc2;
assign wDst1 = rDst1;
assign wDst2 = rDst2;
st st1
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .MASK(REG_SETSCOLOR_MASK),
        .SRC(wSrc1),
        .DST(wDst1),
        .LIMIT_L(REG_SETSCOLOR_L),
        .LIMIT_H(REG_SETSCOLOR_H),
        .INVALID(wStInValid),
        .ST_ON(REG_SETSTMODE),
        .OUTCOLOR(wColorSt1),
        .DST_ST(wDstSt1),
        .FINISH(wFinishSt1)
);
st st2
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .MASK(REG_SETSCOLOR_MASK),
        .SRC(rSrc2),
        .DST(rDst2),
        .LIMIT_L(REG_SETSCOLOR_L),
        .LIMIT_H(REG_SETSCOLOR_H),
        .INVALID(wStInValid),
        .ST_ON(REG_SETSTMODE),
        .OUTCOLOR(wColorSt2),
        .DST_ST(wDstSt2),
        .FINISH(wFinishSt2)
);
//-------------------------------------------------------------------------
//ブレンド
//-------------------------------------------------------------------------
function [31:0] wX;
        input [2:0] CMPMODE;
        input [31:0] SRC_X;
        input [31:0] DST_X;
        input [31:0] SRCCA;
        input [31:0] SRC_A;
        input [31:0] DST_A;
        input [31:0] COEF0;
        input [31:0] COEF1;
        if(CMPMODE == 3'b000)
                wX = SRC_X;
        else if(CMPMODE == 3'b001)
                wX = DST_X;
        else if(CMPMODE == 3'b010)
                wX = SRCCA;
        else if(CMPMODE == 3'b011)
                wX = SRC_A;
        else if(CMPMODE == 3'b100)
                wX = DST_A;
        else if(CMPMODE == 3'b101)
                wX = COEF0;
        else if(CMPMODE == 3'b110)
                wX = COEF1;
        else
                wX = SRC_X;
endfunction
assign wA1 = wX(
        REG_SETBLENDALPHA_A,
        wColorSt1,
        wDstSt1,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt1[31:24]}},
        {4{wDstSt1[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wA2 = wX(
        REG_SETBLENDALPHA_A,
        wColorSt2,
        wDstSt2,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt2[31:24]}},
        {4{wDstSt2[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wB1 = wX(
        REG_SETBLENDALPHA_B,
        wColorSt1,
        wDstSt1,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt1[31:24]}},
        {4{wDstSt1[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wB2 = wX(
        REG_SETBLENDALPHA_B,
        wColorSt2,
        wDstSt2,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt2[31:24]}},
        {4{wDstSt2[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wC1 = wX(
        REG_SETBLENDALPHA_C,
        wColorSt1,
        wDstSt1,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt1[31:24]}},
        {4{wDstSt1[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wC2 = wX(
        REG_SETBLENDALPHA_C,
        wColorSt2,
        wDstSt2,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt2[31:24]}},
        {4{wDstSt2[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wD1 = wX(
        REG_SETBLENDALPHA_D,
        wColorSt1,
        wDstSt1,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt1[31:24]}},
        {4{wDstSt1[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wD2 = wX(
        REG_SETBLENDALPHA_D,
        wColorSt2,
        wDstSt2,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt2[31:24]}},
        {4{wDstSt2[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wE1 = wX(
        REG_SETBLENDALPHA_E,
        wColorSt1,
        wDstSt1,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt1[31:24]}},
        {4{wDstSt1[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);
assign wE2 = wX(
        REG_SETBLENDALPHA_E,
        wColorSt2,
        wDstSt2,
        {4{REG_SETBLENDALPHA_SRCCA}},
        {4{wColorSt2[31:24]}},
        {4{wDstSt2[31:24]}},
        REG_SETBLENDALPHA_COEF0,
        REG_SETBLENDALPHA_COEF1
);

blend blendA1
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA1[31:24]),
        .B(wB1[31:24]),
        .C(wC1[31:24]),
        .D(wD1[31:24]),
        .E(wE1[31:24]),
        .INVALID(wFinishSt1),
        .OUT(wColorBlendA1),
        .FINISH(wFinishBlend1[3])
);
blend blendA2
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA2[31:24]),
        .B(wB2[31:24]),
        .C(wC2[31:24]),
        .D(wD2[31:24]),
        .E(wE2[31:24]),
        .INVALID(wFinishSt2),
        .OUT(wColorBlendA2),
        .FINISH(wFinishBlend2[3])
);
blend blendR1
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA1[23:16]),
        .B(wB1[23:16]),
        .C(wC1[23:16]),
        .D(wD1[23:16]),
        .E(wE1[23:16]),
        .INVALID(wFinishSt1),
        .OUT(wColorBlendR1),
        .FINISH(wFinishBlend1[2])
);
blend blendR2
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA2[23:16]),
        .B(wB2[23:16]),
        .C(wC2[23:16]),
        .D(wD2[23:16]),
        .E(wE2[23:16]),
        .INVALID(wFinishSt2),
        .OUT(wColorBlendR2),
        .FINISH(wFinishBlend2[2])
);
blend blendG1
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA1[15:8]),
        .B(wB1[15:8]),
        .C(wC1[15:8]),
        .D(wD1[15:8]),
        .E(wE1[15:8]),
        .INVALID(wFinishSt1),
        .OUT(wColorBlendG1),
        .FINISH(wFinishBlend1[1])
);
blend blendG2
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA2[15:8]),
        .B(wB2[15:8]),
        .C(wC2[15:8]),
        .D(wD2[15:8]),
        .E(wE2[15:8]),
        .INVALID(wFinishSt2),
        .OUT(wColorBlendG2),
        .FINISH(wFinishBlend2[1])
);
blend blendB1
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA1[7:0]),
        .B(wB1[7:0]),
        .C(wC1[7:0]),
        .D(wD1[7:0]),
        .E(wE1[7:0]),
        .INVALID(wFinishSt1),
        .OUT(wColorBlendB1),
        .FINISH(wFinishBlend1[0])
);
blend blendB2
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .BLEND_ON(!REG_SETBLENDOFF),
        .A(wA2[7:0]),
        .B(wB2[7:0]),
        .C(wC2[7:0]),
        .D(wD2[7:0]),
        .E(wE2[7:0]),
        .INVALID(wFinishSt2),
        .OUT(wColorBlendB2),
        .FINISH(wFinishBlend2[0])
);
//-------------------------------------------------------------------------
//出力処理
//-------------------------------------------------------------------------
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rPixelData <= 0;
        else if(INIT)
                rPixelData <= 0;
        else if(REG_SETBLENDOFF)
                rPixelData <= {wColorSt1, wColorSt2};
        else
                rPixelData <= {
        wColorBlendA1, wColorBlendR1, wColorBlendG1, wColorBlendB1,
        wColorBlendA2, wColorBlendR2, wColorBlendG2, wColorBlendB2
        };
end
assign PIXEL_DATA = rPixelData;
//-------------------------------------------------------------------------
//WR
//-------------------------------------------------------------------------
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rWrWR <= 0;
        else if(INIT)
                rWrWR <= 0;
        else if(REG_SETBLENDOFF && wFinishSt1 && wFinishSt2)
                rWrWR <= 1;
        else if(!REG_SETBLENDOFF && (wFinishBlend1 == 4'b1111) && (wFinishBlend2 == 4'b1111))
                rWrWR <= 1;
        else
                rWrWR <= 0;
end
assign WR_WR = rWrWR;
//-------------------------------------------------------------------------
//ERROR
//とりあえずエラーなし
//-------------------------------------------------------------------------
assign ERROR = 0;
endmodule
