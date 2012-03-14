/* bug fix */
/*
2011/01/20      wrバッファがemptyになったらbusyを解いてしまい、
                リセットされてしまうので、
                最後の１pixelがかけてしまうことがある。
                busy がreq&ack見て受理されるまで待つよう修正

2011/01/23      SETWRの時にも!EMPTY_WRBUFの条件をつけておかないと、pixelgenが終
                わってなくてWRBUFが空の時にunderしてしまうぞ
                SETWR状態の時にWRBUFがEMPTYのとき、正しく動くように処理しなければならない。
                (未修正)

2011/01/24      width = 2, height = 2　で動くように修正
                fifoに同期リセットがかかってない等も修正

                width = 0, height = 0　で動くように修正(overareaも)
*/
module draw_vramctrl
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [8:0]	OVA_SPOSX,
  input [13:0]	OVA_SPOSY,
  input [8:0]	OVA_DPOSX,
  input [13:0]	OVA_DPOSY,
  input [8:0]	OVA_WIDTH,
  input [9:0]	OVA_HEIGHT,
  input [1:0]	VALID,
  input       	STARTBLT,
  input       	FULL_SRCBUF,
  input       	FULL_DSTBUF,
  input       	EMPTY_WRBUF,
  input       	VIF_DRWRDATAVLD,
  input       	VIF_DRWACK,
  input [9:0]	ONCOUNT,
  input [9:0]	OFFCOUNT,
  output       	DRW_VRAMREQ,
  output       	DRW_VRAMWRITE,
  output [22:0]	DRW_VRAMADR,
  output [7:0]	DRW_VRAMDMASK,
  output       	SRCSEL,
  output       	DSTSEL,
  output       	WRSEL,
  output       	WORKING,
  output       	BUSY_VRAM,
  output       	RD_VRAMWR,
  output [3:0]	ERROR
);

parameter IDLE  =       0;
parameter ZERO =        1;
parameter SRC   =       2;
parameter SRC_WAIT =    3;
parameter DST   =       4;
parameter DST_WAIT =    5;
parameter SETWR =       6;
parameter WR    =       7;
parameter WR_SRCWAIT =  8;
parameter WR_DSTWAIT =  9;

parameter PAT   = 1;
parameter BIT   = 2;

//for state machine
reg [4:0] current, next;

reg rBusyVram;
reg rVIF_valid;
reg [8:0] hcount;
reg [8:0] hcountValid;
reg [13:0] vcountSrc;
reg [13:0] vcountDst;
reg [13:0] vcountWr;

//for vram
wire            wReq;
//reg             rVramWr;
reg             rSreq, rASreq;
reg [22:0]      rAdr;
reg [2:0]       rBufSel;
reg             rWorking;
reg [9:0]       reqWaitCount;
reg             validMaxFlag;

//-------------------------------------------------------------------------
//reqWait
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                reqWaitCount <= 0;
        else if(INIT)
                reqWaitCount <= 0;
        else if( current == SRC_WAIT || current == DST_WAIT
                || current == WR_SRCWAIT || current == WR_DSTWAIT)
                reqWaitCount <= reqWaitCount + 1;
        else
                reqWaitCount <= 0;
end
//-------------------------------------------------------------------------
//カウンタ
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                hcount <= 0;
        else if(INIT)
                hcount <= 0;
        else if(!(wReq && VIF_DRWACK))
                hcount <= hcount;
        else if(hcount == OVA_WIDTH - 1)
                hcount <= 0;
        else
                hcount <= hcount + 1;
end
// VIF_DRWRDATAVLDが来てからのデータ数をカウント
// BUFのfifoとwrを合わせる

always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rVIF_valid <= 0;
        else if(INIT)
                rVIF_valid <= 0;
        else
                rVIF_valid <= VIF_DRWRDATAVLD;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                hcountValid <= 0;
        else if(INIT)
                hcountValid <= 0;
        else if(!rVIF_valid)
                hcountValid <= hcountValid;
        else if((hcountValid >= OVA_WIDTH - 1) && ((current == SRC_WAIT) || (current == DST_WAIT)))
                hcountValid <= 0;
        else
                hcountValid <= hcountValid + 1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                validMaxFlag <= 0;
        else if(INIT)
                validMaxFlag <= 0;
        else if( (current == SRC || current == DST || current == WR) && (hcountValid == 0) )
                validMaxFlag <= 0;
        else if(hcountValid == OVA_WIDTH - 1 && rVIF_valid )
                validMaxFlag <= 1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                vcountSrc <= 0;
        else if(INIT)
                vcountSrc <= 0;
        else if(!(wReq && VIF_DRWACK))
                vcountSrc <= vcountSrc;
        else if(!(current == SRC))
                vcountSrc <= vcountSrc;
        else if((vcountSrc == OVA_HEIGHT - 1) && (hcount == OVA_WIDTH -1))
                vcountSrc <= 0;
        else if(hcount == OVA_WIDTH - 1) 
                vcountSrc <= vcountSrc + 1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                vcountDst <= 0;
        else if(INIT)
                vcountDst <= 0;
        else if(!(wReq && VIF_DRWACK))
                vcountDst <= vcountDst;
        else if(!(current == DST))
                vcountDst <= vcountDst;
        else if((vcountDst == OVA_HEIGHT - 1) && (hcount == OVA_WIDTH - 1))
                vcountDst <= 0;
        else if(hcount == OVA_WIDTH - 1)
                vcountDst <= vcountDst + 1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                vcountWr <= 0;
        else if(INIT)
                vcountWr <= 0;
        else if(!(wReq && VIF_DRWACK))
                vcountWr <= vcountWr;
        else if(!(current == WR))
                vcountWr <= vcountWr;
        else if((vcountWr== OVA_HEIGHT - 1) && (hcount == OVA_WIDTH - 1))
                vcountWr <= 0;
        else if(hcount == OVA_WIDTH - 1)
                vcountWr <= vcountWr + 1;
end

//-------------------------------------------------------------------------
//状態遷移
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                current <= IDLE;
        else if(INIT)
                current <= IDLE;
        else
                current <= next;
end
always @* begin
        case(current)
                IDLE: begin
                        if(STARTBLT && (OVA_WIDTH == 0 || OVA_HEIGHT == 0))
                                next <= ZERO;
                        else if( STARTBLT && VALID == BIT )
                                next <= SRC;
                        else if( STARTBLT && VALID == PAT )
                                next <= DST;
                        else
                                next <= IDLE;
                end
                ZERO: begin
                                next <= IDLE;
                end
                SRC: begin
                        if(!(wReq && VIF_DRWACK))
                                next <= SRC;
                        else if(hcount == OVA_WIDTH - 1)
                                next <= SRC_WAIT;
                        else
                                next <= SRC;
                end
                SRC_WAIT: begin
                        //if(!(rVIF_valid))
                        //        next <= SRC_WAIT;
                        if(reqWaitCount < ONCOUNT)
                                next <= SRC_WAIT;
                        else if(validMaxFlag)
                                next <= DST;
                        //else if(hcountValid == OVA_WIDTH - 1)
                        //        next <= DST;
                        else
                                next <= SRC_WAIT;
                end
                DST: begin
                        if(!(wReq && VIF_DRWACK))
                                next <= DST;
                        else if(hcount == OVA_WIDTH - 1)
                                next <= DST_WAIT;
                        else
                                next <= DST;
                end
                DST_WAIT: begin
                        //if(!(rVIF_valid))
                        //       next <= DST_WAIT;
                        if(reqWaitCount < ONCOUNT)
                                next <= DST_WAIT;
                        else if(validMaxFlag)
                                next <= SETWR;
                        //else if(hcountValid == OVA_WIDTH - 1)
                        //        next <= SETWR;
                        else
                                next <= DST_WAIT;
                end
                SETWR: begin
                        //WRBUFから一番最初に呼び出すとき、このステートで制御
                        //した方が都合がいい。
                        //なくしちゃだめ
                        if(EMPTY_WRBUF)
                                next <= SETWR;
                        else
                                next <= WR;
                end
                WR: begin
                        if(!(wReq && VIF_DRWACK))
                                next <= WR;
                        else if((hcount == OVA_WIDTH - 1) && (vcountWr == OVA_HEIGHT - 1))
                                next <= IDLE;
                        else if((VALID == PAT) && (hcount == OVA_WIDTH - 1) && (vcountWr < OVA_HEIGHT - 1))
                                next <= WR_DSTWAIT;
                        else if((VALID == BIT) && (hcount == OVA_WIDTH - 1) && (vcountWr < OVA_HEIGHT - 1))
                                next <= WR_SRCWAIT;
                        else
                                next <= WR;
                end
                WR_SRCWAIT: begin
                        if(reqWaitCount > ONCOUNT)
                                next <= SRC;
                        else
                                next <= WR_SRCWAIT;
                end

                WR_DSTWAIT: begin
                        if(reqWaitCount > ONCOUNT)
                                next <= DST;
                        else
                                next <= WR_DSTWAIT;
                end
        endcase
end
//-------------------------------------------------------------------------
//REQ信号
//-------------------------------------------------------------------------
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rSreq <= 0;
        else if(INIT)
                rSreq <= 0;
        else if((current == SRC && FULL_SRCBUF) || (current == DST && FULL_DSTBUF) 
                || (current == WR && EMPTY_WRBUF && VIF_DRWACK))
                rSreq <= 0;
        else if(current == SRC || current == DST || current == WR)
                rSreq <= 1;
        else
                rSreq <= 0;
end
always @* begin
        if( !RST_X )
                rASreq <= 0;
        else if(INIT)
                rASreq <= 0;
        else if((current == SRC && FULL_SRCBUF) || (current == DST && FULL_DSTBUF))
                rASreq <= 0;
        else if(current == SRC || current == DST || current == WR)
                rASreq <= 1;
        else
                rASreq <= 0;
end
assign wReq = rSreq & rASreq;
assign DRW_VRAMREQ = wReq;
//-------------------------------------------------------------------------
//VRAMWRITE信号
//-------------------------------------------------------------------------
//2011/01/24 
//vramへの書き込み信号は、req&ackと同期をとるべきだから、非同期式にするのが筋？
//そしてバグの元setwrのステートを削ろう
//setwr削るとWRBUFからの読み出しがまにあわないじゃんｗｗｗ
/*
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rVramWr <= 0;
        else if(INIT)
                rVramWr <= 0;
        else if(current == SETWR || current == WR)
                rVramWr <= 1;
        else
                rVramWr <= 0;
end
assign DRW_VRAMWRITE = rVramWr;
*/
assign DRW_VRAMWRITE = (current == WR);
//-------------------------------------------------------------------------
//RD_VRAMWR信号(WRBUFへのリード信号)
//-------------------------------------------------------------------------
//emptyの条件も必要（cur == WR の最後の方にアンダーしてしまうだろう）
// 2011/01/23 SETWRの時にも!EMPTY_WRBUFの条件をつけておかないと、pixelgenが終
// わってなくてWRBUFが空の時にunderしてしまうぞ
assign RD_VRAMWR = (current == SETWR) ? !EMPTY_WRBUF : (current == WR) & (wReq) & (VIF_DRWACK) & (!EMPTY_WRBUF);
//-------------------------------------------------------------------------
//アドレス
//-------------------------------------------------------------------------
always @* begin
        if( !RST_X )
                rAdr <= 0;
        else if(INIT)
                rAdr <= 0;
        else if(current == SRC)
                rAdr <= {OVA_SPOSY + vcountSrc, OVA_SPOSX + hcount};
        else if(current == DST)
                rAdr <= {OVA_DPOSY + vcountDst, OVA_DPOSX + hcount};
        else if(current == WR)
                rAdr <= {OVA_DPOSY + vcountWr, OVA_DPOSX + hcount};
        else
                rAdr <= 0;
end
assign DRW_VRAMADR = rAdr;
//-------------------------------------------------------------------------
//VRAMに書き込むデータのMASK
//-------------------------------------------------------------------------
assign DRW_VRAMDMASK = 8'b0000_0000;
//-------------------------------------------------------------------------
//バッファセレクト信号
//-------------------------------------------------------------------------
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rBufSel <= 0;
        else if(INIT)
                rBufSel <= 0;
        else if(current == SRC || current == SRC_WAIT)
                rBufSel <= SRC;
        else if(current == DST || current == DST_WAIT)
                rBufSel <= DST;
        else if(current == WR)
                rBufSel <= WR;
        else
                rBufSel <= 0;
end
assign SRCSEL = (rBufSel == SRC);
assign DSTSEL = (rBufSel == DST);
assign WRSEL  = (rBufSel == WR);
//-------------------------------------------------------------------------
//BUSY信号
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rBusyVram <= 0;
        else if(INIT)
                rBusyVram <= 0;
        else if(STARTBLT)
                rBusyVram <= 1;
        else if(OVA_WIDTH == 0 || OVA_HEIGHT == 0)
                rBusyVram <= 0;
        else if((current == WR) && ((hcount == OVA_WIDTH - 1) && (vcountWr == OVA_HEIGHT - 1)) && ((wReq) & (VIF_DRWACK)))
                rBusyVram <= 0;
end
assign BUSY_VRAM = STARTBLT | rBusyVram;
//-------------------------------------------------------------------------
//WORKING
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rWorking <= 0;
        else if(INIT)
                rWorking <= 0;
        else if(current == IDLE)
                rWorking <= 0;
        else
                rWorking <= 1;
end
assign WORKING = rWorking;
//-------------------------------------------------------------------------
//ERROR
//とりあえず0
//-------------------------------------------------------------------------
assign ERROR = 0;
endmodule
