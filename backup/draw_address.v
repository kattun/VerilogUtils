module draw_address
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [22:0]	REG_SETFRAME_VRAMADR,
  input [9:0]	REG_SETFRAME_WIDTH,
  input [9:0]	REG_SETFRAME_HEIGHT,
  input [9:0]	REG_SETDRAWAREA_POSX,
  input [9:0]	REG_SETDRAWAREA_POSY,
  input [9:0]	REG_SETDRAWAREA_SIZX,
  input [9:0]	REG_SETDRAWAREA_SIZY,
  input       	REG_SETTEXTURE_FMT,
  input [22:0]	REG_SETTEXTURE_VRAMADR,
  input [9:0]	REG_SETTEXTURE_WIDTH,
  input [9:0]	REG_SETTEXTURE_HEIGHT,
  input [10:0]	REG_PATBLT_DPOSX,
  input [10:0]	REG_PATBLT_DPOSY,
  input [9:0]	REG_PATBLT_DSIZX,
  input [9:0]	REG_PATBLT_DSIZY,
  input [10:0]	REG_BITBLT_DPOSX,
  input [10:0]	REG_BITBLT_DPOSY,
  input [9:0]	REG_BITBLT_DSIZX,
  input [9:0]	REG_BITBLT_DSIZY,
  input [9:0]	REG_BITBLT_SPOSX,
  input [9:0]	REG_BITBLT_SPOSY,
  input       	READYPAT_ADD,
  input       	READYBIT_ADD,
  input       	STARTBLT_ADD,
  input       	BUSY_VRAMCTRL,
  output       	BUSY_ADD,
  output [8:0]	OVA_SPOSX,
  output [13:0]	OVA_SPOSY,
  output [8:0]	OVA_DPOSX,
  output [13:0]	OVA_DPOSY,
  output [8:0]	OVA_WIDTH,
  output [9:0]	OVA_HEIGHT,
  output [1:0]	VALID,
  output       	STARTBLT,
  output [3:0]	ERROR_ADD
);

wire            wASValid;

wire            wAvainitIn;
wire            wAvainit;
wire            wAvaexe;
wire [10:0]      wAvax;
wire [14:0]     wAvay;
wire [9:0]      wAvaw, wAvah;
wire            wAvafinish;
wire [10:0]      wAvaAxIn;
wire [14:0]     wAvaAyIn;
wire [10:0]      wAvaBxIn;
wire [14:0]     wAvaByIn;

wire [10:0]      wBltx;
wire [14:0]     wBlty;
wire [9:0]      wBltw, wBlth;

wire            wDstinitIn;
wire            wDstinit;
wire            wDstexe;
wire [10:0]      wDstx;
wire [14:0]     wDsty;
wire [9:0]      wDstw, wDsth;
wire            wDstfinish;
wire            wDstfinishp;

wire            wFininitIn;
wire            wFininit;
wire            wFinexe;
wire [10:0]      wFinx;
wire [14:0]     wFiny;
wire [9:0]      wFinw, wFinh;
wire            wFinfinish;
wire            wfinishp;
wire [10:0]      wFinAxIn;
wire [14:0]     wFinAyIn;
wire [10:0]      wFinBxIn;
wire [14:0]     wFinByIn;

wire            wStartBltpIn;

reg             r_Avaexe;
reg             r_Dstexe;
reg [10:0]       r_Bltx;
reg [14:0]      r_Blty;
reg [9:0]       r_Bltw, r_Blth;
reg             r_Finexe;
reg [8:0]       r_ovaSposx;
reg [13:0]      r_ovaSposy;
reg [8:0]       r_ovaDposx;
reg [13:0]      r_ovaDposy;
reg [9:0]       r_ovaWidth;
reg [9:0]       r_ovaHeight;
reg [1:0]       r_valid;
reg             internalBusy;

parameter SRC           = 2'd1;
parameter DS            = 2'd2;
parameter WR            = 2'd3;
//-------------------------------------------------------------------------
//BUSY信号
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                internalBusy <= 0;
        else if(INIT)
                internalBusy <= 0;
        else if(wASValid)
                internalBusy <= 0;
        else if(STARTBLT_ADD)
                internalBusy <= 1;
end
assign BUSY_ADD = STARTBLT_ADD | internalBusy | BUSY_VRAMCTRL;
//-------------------------------------------------------------------------
//address計算
//Available Area = フレーム領域∧描画領域
//Blt Area = BLT命令のDPOS, DSIZで作られる領域
//Real Area = Avalilable Area ∧ Blt Area
//-------------------------------------------------------------------------
//Available Area 計算
assign wAvainitIn = INIT | STARTBLT_ADD;
plusegen initAva_pls
(
        .CLK(CLK),
        .RST_X(RST_X),
        .IN(wAvainitIn),
        .OUT(wAvainit)
);
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Avaexe <= 0;
        else if(INIT)
                r_Avaexe <= 0;
        else if(wAvainit)
                r_Avaexe <= 1;
        else
                r_Avaexe <= 0;
end
assign wAvaexe = r_Avaexe;

assign wAvaAxIn = {1'b0, REG_SETFRAME_VRAMADR[8:0], 1'b0};
assign wAvaAyIn = {1'b0, REG_SETFRAME_VRAMADR[22:9]};
assign wAvaBxIn = {1'b0, (REG_SETDRAWAREA_POSX + {REG_SETFRAME_VRAMADR[8:0], 1'b0})};
assign wAvaByIn = {1'b0, REG_SETDRAWAREA_POSY + REG_SETFRAME_VRAMADR[22:9]};
overarea ava_ova
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(wAvainit),
        .Ax(wAvaAxIn),
        .Ay(wAvaAyIn),
        .Aw(REG_SETFRAME_WIDTH),
        .Ah(REG_SETFRAME_HEIGHT),
        .Bx(wAvaBxIn),
        .By(wAvaByIn),
        .Bw(REG_SETDRAWAREA_SIZX),
        .Bh(REG_SETDRAWAREA_SIZY),
        .EXE(wAvaexe),
        .OVAx(wAvax),
        .OVAy(wAvay),
        .OVAw(wAvaw),
        .OVAh(wAvah),
        .FINISH(wAvafinish)
);
//Blt Area 計算
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Bltx <= 0;
        else if(INIT)
                r_Bltx <= 0;
        else if(READYPAT_ADD)
                // REG_PATBLT_DPOSX は 11bit (signed)
                r_Bltx <= REG_PATBLT_DPOSX + (REG_SETFRAME_VRAMADR[8:0]<<1);
        else if(READYBIT_ADD)
                r_Bltx <= REG_BITBLT_DPOSX + (REG_SETFRAME_VRAMADR[8:0]<<1);
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Blty <= 0;
        else if(INIT)
                r_Blty <= 0;
        else if(READYPAT_ADD)
                // REG_PATBLT_DPOSY は 11bit (signed)
                r_Blty <= {{4{REG_PATBLT_DPOSY[10]}}, REG_PATBLT_DPOSY}
                          + (REG_SETFRAME_VRAMADR[22:9]);
        else if(READYBIT_ADD)
                r_Blty <= {{4{REG_BITBLT_DPOSY[10]}}, REG_BITBLT_DPOSY}
                          + (REG_SETFRAME_VRAMADR[22:9]);
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Bltw <= 0;
        else if(INIT)
                r_Bltw <= 0;
        else if(READYPAT_ADD)
                r_Bltw <= REG_PATBLT_DSIZX;
        else if(READYBIT_ADD)
                r_Bltw <= REG_BITBLT_DSIZX;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Blth <= 0;
        else if(INIT)
                r_Blth <= 0;
        else if(READYPAT_ADD)
                r_Blth <= REG_PATBLT_DSIZY;
        else if(READYBIT_ADD)
                r_Blth <= REG_BITBLT_DSIZY;
end
//Dst Area 計算
assign wDstinitIn = INIT | wAvafinish;
plusegen initDst_pls
(
        .CLK(CLK),
        .RST_X(RST_X),
        .IN(wDstinitIn),
        .OUT(wDstinit)
);
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Dstexe <= 0;
        else if(INIT)
                r_Dstexe <= 0;
        else if(wDstinit)
                r_Dstexe <= 1;
        else
                r_Dstexe <= 0;
end
assign wDstexe = r_Dstexe;

assign wBltx = r_Bltx;
assign wBlty = r_Blty;
assign wBltw = r_Bltw;
assign wBlth = r_Blth;
overarea dst_ova
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(wDstinit),
        .Ax(wAvax),
        .Ay(wAvay),
        .Aw(wAvaw),
        .Ah(wAvah),
        .Bx(wBltx),
        .By(wBlty),
        .Bw(wBltw),
        .Bh(wBlth),
        .EXE(wDstexe),
        .OVAx(wDstx),
        .OVAy(wDsty),
        .OVAw(wDstw),
        .OVAh(wDsth),
        .FINISH(wDstfinish)
);
//Fin Area 計算
assign wFininitIn = INIT | wDstfinish;
plusegen initFin_pls
(
        .CLK(CLK),
        .RST_X(RST_X),
        .IN(wFininitIn),
        .OUT(wDstfinishp)
);
assign wFininit = wDstfinishp;
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_Finexe <= 0;
        else if(INIT)
                r_Finexe <= 0;
        else if(wFininit && READYBIT_ADD)
                r_Finexe <= 1;
        else
                r_Finexe <= 0;
end
assign wFinexe = r_Finexe;

assign wFinAxIn = {1'b0, REG_SETTEXTURE_VRAMADR[8:0], 1'b0};
assign wFinAyIn = {1'b0, REG_SETTEXTURE_VRAMADR[22:9]};
assign wFinBxIn = {1'b0, (REG_BITBLT_SPOSX + {REG_SETTEXTURE_VRAMADR[8:0], 1'b0})};
assign wFinByIn = {1'b0, REG_BITBLT_SPOSY + REG_SETTEXTURE_VRAMADR[22:9]};

overarea fin_ova
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(wFininit),
        .Ax(wFinAxIn),
        .Ay(wFinAyIn),
        .Aw(REG_SETTEXTURE_WIDTH),
        .Ah(REG_SETTEXTURE_HEIGHT),
        .Bx(wFinBxIn),
        .By(wFinByIn),
        .Bw(wDstw),
        .Bh(wDsth),
        .EXE(wFinexe),
        .OVAx(wFinx),
        .OVAy(wFiny),
        .OVAw(wFinw),
        .OVAh(wFinh),
        .FINISH(wFinfinish)
);
plusegen finFin_pls
(
        .CLK(CLK),
        .RST_X(RST_X),
        .IN(wFinfinish),
        .OUT(wfinishp)
);

//-------------------------------------------------------------------------
//出力処理
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaSposx <= 0;
        else if(INIT)
                r_ovaSposx <= 0;
        else if(wfinishp)
                r_ovaSposx <= wFinx[9:0]>>1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaSposy <= 0;
        else if(INIT)
                r_ovaSposy <= 0;
        else if(wfinishp)
                r_ovaSposy <= wFiny[13:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaDposx <= 0;
        else if(INIT)
                r_ovaDposx <= 0;
        else if(wDstfinishp)
                r_ovaDposx <= wDstx[9:0]>>1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaDposy <= 0;
        else if(INIT)
                r_ovaDposy <= 0;
        else if(wDstfinishp)
                r_ovaDposy <= wDsty[13:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaWidth <= 0;
        else if(INIT)
                r_ovaWidth <= 0;
        else if(READYPAT_ADD && wDstfinishp)
                r_ovaWidth <= wDstw>>1;
        else if(READYBIT_ADD && wfinishp)
                r_ovaWidth <= wFinw>>1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ovaHeight <= 0;
        else if(INIT)
                r_ovaHeight <= 0;
        else if(READYPAT_ADD && wDstfinishp)
                r_ovaHeight <= wDsth;
        else if(READYBIT_ADD && wfinishp)
                r_ovaHeight <= wFinh;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_valid <= 0;
        else if(INIT)
                r_valid <= 0;
        else if(STARTBLT_ADD)
                r_valid <= 0;
        else if(READYPAT_ADD && wDstfinishp)
                r_valid <= 2'b01;
        else if(READYBIT_ADD && wfinishp)
                r_valid <= 2'b10;
end
// internal busy用。下げるの遅いと問題発生
assign wASValid = (|r_valid) & !STARTBLT_ADD;

assign OVA_SPOSX = r_ovaSposx;
assign OVA_SPOSY = r_ovaSposy;
assign OVA_DPOSX = r_ovaDposx;
assign OVA_DPOSY = r_ovaDposy;
assign OVA_WIDTH = r_ovaWidth;
assign OVA_HEIGHT = r_ovaHeight;
assign VALID   = r_valid;
assign ERROR_ADD = 0;           //機能拡張してsegmentation faultしたらエラーとかに使うかも。

assign wStartBltpIn = | r_valid;
plusegen startBltp
(
        .CLK(CLK),
        .RST_X(RST_X),
        .IN(wStartBltpIn),
        .OUT(STARTBLT)
);
endmodule
