module draw_interrgen
(
  input       	CLK,
  input       	RST_X,
  input       	INITCMND,
  input       	EODL,
  input [3:0]	EREG,
  input [3:0]	EADD,
  input [3:0]	EPIXEL,
  input [3:0]	EVRAM,
  input       	OVER_SRC,
  input       	OVER_DST,
  input       	OVER_WR,
  input       	UNDER_SRC,
  input       	UNDER_DST,
  input       	UNDER_WR,
  input       	WORKING_VRAM,
  output       	INIT_REG,
  output       	INIT_ADD,
  output       	INIT_PIXEL,
  output       	INIT_VRAM,
  output       	INIT_SRC,
  output       	INIT_DST,
  output       	INIT_WR,
  output [11:0]	ERROR_REG,
  output       	DRW_ERRINT,
  output       	DRW_INT,
  output       	BUSY,
  output       	WORKINGDRW
);
// INITCMND はHアクティブ
wire error_src, error_dst, error_wr;
wire ierror;            // interrgenエラー用。一応作った

//ERRINT用
reg r_ERRINT1, r_ERRINT2;

//INT用
reg r_EODL;

assign error_src = OVER_SRC | UNDER_SRC;
assign error_dst = OVER_DST | UNDER_DST;
assign error_wr = OVER_WR | UNDER_WR;
assign ierror = 0;      //今のところ用となし

assign ERROR_REG[0] = {EREG[0] | EADD[0] | EPIXEL[0] | EVRAM[0] | UNDER_SRC | UNDER_DST | UNDER_WR};
assign ERROR_REG[1] = {EREG[1] | EADD[1] | EPIXEL[1] | EVRAM[1] | OVER_SRC | OVER_DST | OVER_WR};
assign ERROR_REG[2] = {EREG[2] | EADD[2] | EPIXEL[2] | EVRAM[2]};
assign ERROR_REG[3] = {EREG[3] | EADD[3] | EPIXEL[3] | EVRAM[3]};
assign ERROR_REG[11:4] = {error_wr, error_dst, error_src, |EVRAM, |EPIXEL, |EADD, |EREG ,ierror};

assign  INIT_REG  = INITCMND | EODL;
assign  INIT_ADD  = INITCMND | EODL;
assign  INIT_PIXEL = INITCMND | EODL;
assign  INIT_VRAM = INITCMND | EODL;
assign  INIT_SRC  = INITCMND | EODL;
assign  INIT_DST  = INITCMND | EODL;
assign  INIT_WR   = INITCMND | EODL;

//ERRINT
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ERRINT1 <= 0;
        else if(INITCMND)
                r_ERRINT1 <= 0;
        else if( error_wr | error_dst | error_src | EVRAM > 0 | EPIXEL > 0 | EADD > 0 | EREG > 0 | ierror)           //どこかのエラーフラグが立ったら
                r_ERRINT1 <= 1;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ERRINT2 <= 0;
        else if(INITCMND)
                r_ERRINT2 <= 0;
        else if( r_ERRINT1 == 1 )
                r_ERRINT2 <= 1;
end
assign DRW_ERRINT = r_ERRINT1 & ~r_ERRINT2;

//INT
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_EODL <= 0;
        else if(INITCMND)
                r_EODL <= 0;
        else if( EODL == 1 )
                r_EODL <= 1;
        else
                r_EODL <= 0;
end
assign DRW_INT = r_EODL;

//WORKINGDRW
assign WORKINGDRW = WORKING_VRAM;

//BUSY
assign BUSY = 0;
endmodule
