module draw_regctrl_dec
(
  input 		CLK,
  input 		RST_X,
  input 		INIT,
  input       	EXE,
  input 		BUSY_PIXEL,
  input 		BUSY_ADD,
  input 		BUSY_INTERR,
  input [31:0]	BUFDATA,
  input       	DATAVALID,
  input       	FULL,
  input       	EMPTY,
  output       	BUF_RD,
  output 		EODL,
  output [22:0]	REG_SETFRAME_VRAMADR,
  output [9:0]	REG_SETFRAME_WIDTH,
  output [9:0]	REG_SETFRAME_HEIGHT,
  output [9:0]	REG_SETDRAWAREA_POSX,
  output [9:0]	REG_SETDRAWAREA_POSY,
  output [9:0]	REG_SETDRAWAREA_SIZX,
  output [9:0]	REG_SETDRAWAREA_SIZY,
  output 		REG_SETTEXTURE_FMT,
  output [22:0]	REG_SETTEXTURE_VRAMADR,
  output [9:0]	REG_SETTEXTURE_WIDTH,
  output [9:0]	REG_SETTEXTURE_HEIGHT,
  output [31:0]	REG_SETFCOLOR,
  output 		REG_SETSTMODE,
  output [3:0]	REG_SETSCOLOR_MASK,
  output [31:0]	REG_SETSCOLOR_L,
  output [31:0]	REG_SETSCOLOR_H,
  output 		REG_SETBLENDOFF,
  output [2:0]	REG_SETBLENDALPHA_A,
  output [2:0]	REG_SETBLENDALPHA_B,
  output [2:0]	REG_SETBLENDALPHA_C,
  output [2:0]	REG_SETBLENDALPHA_D,
  output [2:0]	REG_SETBLENDALPHA_E,
  output [7:0]	REG_SETBLENDALPHA_SRCCA,
  output [31:0]	REG_SETBLENDALPHA_COEF0,
  output [31:0]	REG_SETBLENDALPHA_COEF1,
  output [10:0]	REG_PATBLT_DPOSX,
  output [10:0]	REG_PATBLT_DPOSY,
  output [9:0]	REG_PATBLT_DSIZX,
  output [9:0]	REG_PATBLT_DSIZY,
  output [10:0]	REG_BITBLT_DPOSX,
  output [10:0]	REG_BITBLT_DPOSY,
  output [9:0]	REG_BITBLT_DSIZX,
  output [9:0]	REG_BITBLT_DSIZY,
  output [9:0]	REG_BITBLT_SPOSX,
  output [9:0]	REG_BITBLT_SPOSY,
  output 		READYPAT_ADD,
  output 		READYBIT_ADD,
  output 		STARTBLT_ADD,
  output 		READYPAT_PIXEL,
  output 		READYBIT_PIXEL,
  output 		STARTBLT_PIXEL,
  output       	ERR_DEC
);

//memo: exeは1clkパルス


parameter IDLE  = 0;
parameter CMD1 = 1;
parameter CMD2 = 2;
parameter CMD3 = 3;
parameter CMD4 = 4;

parameter NOP = 0;
parameter P_EODL = 8'h0F;
parameter SETFRAME = 8'h20;
parameter SETDRAWAREA = 8'h21;
parameter SETTEXTURE = 8'h22;
parameter SETFCOLOR = 8'h23;
parameter SETSTMODE = 8'h30;
parameter SETSCOLOR = 8'h31;
parameter SETBLENDOFF = 8'h32;
parameter SETBLENDALPHA = 8'h33;
parameter PATBLT = 8'h81;
parameter BITBLT = 8'h82;

//exe保持
reg exe_valid;

//Cbuf

// state machine
reg [3:0] current, next;
reg sNextCmd1;

// dcmd用
reg [7:0] cmdName;
reg [31:0] r_stkdata;
//reg             rStkValid;
reg r_eodl;
reg [22:0]	r_setframe_vramadr;
reg [9:0]	r_setframe_width;
reg [9:0]	r_setframe_height;
reg [9:0]	r_setdrawarea_posx;
reg [9:0]	r_setdrawarea_posy;
reg [9:0]	r_setdrawarea_sizx;
reg [9:0]	r_setdrawarea_sizy;
reg      	r_settexture_fmt;
reg [22:0]	r_settexture_vramadr;
reg [9:0]	r_settexture_width;
reg [9:0]	r_settexture_height;
reg [31:0]	r_setfcolor;
reg       	r_setstmode;
reg [3:0]	r_setscolor_mask;
reg [31:0]	r_setscolor_l;
reg [31:0]	r_setscolor_h;
reg      	r_setblendoff;
reg [2:0]	r_setblendalpha_a;
reg [2:0]	r_setblendalpha_b;
reg [2:0]	r_setblendalpha_c;
reg [2:0]	r_setblendalpha_d;
reg [2:0]	r_setblendalpha_e;
reg [7:0]	r_setblendalpha_srcca;
reg [31:0]	r_setblendalpha_coef0;
reg [31:0]	r_setblendalpha_coef1;
reg [10:0]	r_patblt_dposx;
reg [10:0]	r_patblt_dposy;
reg [9:0]	r_patblt_dsizx;
reg [9:0]	r_patblt_dsizy;
reg [10:0]	r_bitblt_dposx;
reg [10:0]	r_bitblt_dposy;
reg [9:0]	r_bitblt_dsizx;
reg [9:0]	r_bitblt_dsizy;
reg [9:0]	r_bitblt_sposx;
reg [9:0]	r_bitblt_sposy;

// RD条件
reg  sEmpty;
wire ifRead;
wire executable;
wire wAnyBusy;
assign wAnyBusy = BUSY_PIXEL | BUSY_ADD | BUSY_INTERR;
assign ifRead = !EMPTY & exe_valid & !wAnyBusy;
assign executable = exe_valid & !wAnyBusy;
// ready用
reg             r_readyBitAdd, r_readyPatAdd, r_readyPatPixel, r_readyBitPixel;

// start用
reg r_start;
//-------------------------------------------------------------------------
//exe信号を保持
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                exe_valid <= 0;
        else if(INIT)
                exe_valid <= 0;
        else if(EXE)
                exe_valid <= 1;

end
//-------------------------------------------------------------------------
//状態遷移
//-------------------------------------------------------------------------
//cmdName
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                cmdName <= 0;
        else if(INIT)
                cmdName <= 0;
        else if(!executable)
                cmdName <= cmdName;
        else if(next == CMD1)
                cmdName <= BUFDATA[31:24];
end
//r_stkdata
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_stkdata <= 0;
        else if(INIT)
                r_stkdata <= 0;
        else if(!executable)
                r_stkdata <= r_stkdata;
        else
                r_stkdata <= BUFDATA;
end
//rStkValid
/*
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rStkValid <= 0;
        else if(INIT)
                rStkValid <= 0;
        else
                rStkValid <= DATAVALID;
end
*/
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                current <= IDLE;
        else if(INIT)
                current <= IDLE;
        else
                current <= next;
end
//始まりを調整
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                sNextCmd1 <= IDLE;
        else if(INIT)
                sNextCmd1 <= IDLE;
        else if(executable)
                sNextCmd1 <= 1;
end
//コマンド読み終わりを調整
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                sEmpty <= 0;
        else if(INIT)
                sEmpty <= 0;
        else if(EMPTY)
                sEmpty <= 1;
        else
                sEmpty <= 0;
end

always @* begin
        case(current)
                IDLE: begin
                        if(sNextCmd1)
                                next <= CMD1;
                        else
                                next <= IDLE;
                end
                CMD1: begin
                        if(!executable)
                                next <= CMD1;
                        else if(
                                r_stkdata[31:24] == P_EODL        ||
                                r_stkdata[31:24] == NOP           ||
                                r_stkdata[31:24] == SETSTMODE     ||
                                r_stkdata[31:24] == SETBLENDOFF
                        )
                        next <= CMD1;
                        else if(
                                r_stkdata[31:24] == SETFRAME       ||
                                r_stkdata[31:24] == SETDRAWAREA    ||
                                r_stkdata[31:24] == SETTEXTURE     ||
                                r_stkdata[31:24] == SETFCOLOR      ||
                                r_stkdata[31:24] == SETSCOLOR      ||
                                r_stkdata[31:24] == SETBLENDALPHA  ||
                                r_stkdata[31:24] == PATBLT         ||
                                r_stkdata[31:24] == BITBLT           
                        )
                        next <= CMD2;
                        else
                                next <= CMD1;
                end
                CMD2: begin
                        if(!executable)
                                next <= CMD2;
                        else if(
                                cmdName == SETFRAME       ||
                                cmdName == SETDRAWAREA    ||
                                cmdName == SETTEXTURE     ||
                                cmdName == SETSCOLOR      ||
                                cmdName == SETBLENDALPHA  ||
                                cmdName == PATBLT         ||
                                cmdName == BITBLT           
                        )
                                next <= CMD3;
                        else
                                next <= CMD1;
                end
                CMD3: begin
                        if(!executable)
                                next <= CMD3;
                        else if(cmdName == BITBLT)
                                next <= CMD4;
                        else
                                next <= CMD1;
                end
                CMD4: begin
                        if(!executable)
                                next <= CMD4;
                        else
                                next <= CMD1;
                end
        endcase
end

//-------------------------------------------------------------------------
//コマンド解析
//-------------------------------------------------------------------------
//EODL
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_eodl <= 0;
        else if(INIT)
                r_eodl <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == P_EODL && executable )
                r_eodl <= 1;
        else
                r_eodl <= 0;
end
//SETFRAME
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setframe_vramadr <= 0;
        else if(INIT)
                r_setframe_vramadr <= 0;
        else if(current == CMD2 && cmdName == SETFRAME && executable )
                r_setframe_vramadr <= r_stkdata[22:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setframe_width <= 0;
        else if(INIT)
                r_setframe_width <= 0;
        else if(current == CMD3 && cmdName == SETFRAME && executable )
                r_setframe_width <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setframe_height <= 0;
        else if(INIT)
                r_setframe_height <= 0;
        else if(current == CMD3 && cmdName == SETFRAME && executable )
                r_setframe_height <= r_stkdata[9:0];
end
//SETDRAWAREA
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setdrawarea_posx <= 0;
        else if(INIT)
                r_setdrawarea_posx <= 0;
        else if(current == CMD2 && cmdName == SETDRAWAREA && executable )
                r_setdrawarea_posx <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setdrawarea_posy <= 0;
        else if(INIT)
                r_setdrawarea_posy <= 0;
        else if(current == CMD2 && cmdName == SETDRAWAREA && executable )
                r_setdrawarea_posy <= r_stkdata[9:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setdrawarea_sizx <= 0;
        else if(INIT)
                r_setdrawarea_sizx <= 0;
        else if(current == CMD3 && cmdName == SETDRAWAREA && executable )
                r_setdrawarea_sizx <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setdrawarea_sizy <= 0;
        else if(INIT)
                r_setdrawarea_sizy <= 0;
        else if(current == CMD3 && cmdName == SETDRAWAREA && executable )
                r_setdrawarea_sizy <= r_stkdata[9:0];
end
//SETTEXTURE
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_settexture_fmt <= 0;
        else if(INIT)
                r_settexture_fmt <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETTEXTURE && executable )
                r_settexture_fmt <= r_stkdata[0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_settexture_vramadr <= 0;
        else if(INIT)
                r_settexture_vramadr <= 0;
        else if(current == CMD2 && cmdName == SETTEXTURE && executable )
                r_settexture_vramadr <= r_stkdata[22:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_settexture_width <= 0;
        else if(INIT)
                r_settexture_width <= 0;
        else if(current == CMD3 && cmdName == SETTEXTURE && executable )
                r_settexture_width <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_settexture_height <= 0;
        else if(INIT)
                r_settexture_height <= 0;
        else if(current == CMD3 && cmdName == SETTEXTURE && executable )
                r_settexture_height <= r_stkdata[9:0];
end
//SETFCOLOR
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setfcolor <= 0;
        else if(INIT)
                r_setfcolor <= 0;
        else if(current == CMD2 && cmdName == SETFCOLOR && executable )
                r_setfcolor <= r_stkdata[31:0];
end
//SETSTMODE
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setstmode <= 0;
        else if(INIT)
                r_setstmode <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETSTMODE && executable )
                r_setstmode <= r_stkdata[0];
end
//SETSCOLOR
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setscolor_mask <= 0;
        else if(INIT)
                r_setscolor_mask <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETSCOLOR && executable )
                r_setscolor_mask <= r_stkdata[3:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setscolor_l <= 0;
        else if(INIT)
                r_setscolor_l <= 0;
        else if(current == CMD2 && cmdName == SETSCOLOR && executable )
                r_setscolor_l <= r_stkdata[31:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setscolor_h <= 0;
        else if(INIT)
                r_setscolor_h <= 0;
        else if(current == CMD3 && cmdName == SETSCOLOR && executable )
                r_setscolor_h <= r_stkdata[31:0];
end
//SETBLENDOFF
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendoff <= 0;
        else if(INIT)
                r_setblendoff <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendoff <= 1;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendoff <= 0;
end
//SETBLENDALPHA
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_a <= 0;
        else if(INIT)
                r_setblendalpha_a <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_a <= r_stkdata[22:20];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_a <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_b <= 0;
        else if(INIT)
                r_setblendalpha_b <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_b <= r_stkdata[19:17];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_b <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_c <= 0;
        else if(INIT)
                r_setblendalpha_c <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_c <= r_stkdata[16:14];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_c <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_d <= 0;
        else if(INIT)
                r_setblendalpha_d <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_d <= r_stkdata[13:11];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_d <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_e <= 0;
        else if(INIT)
                r_setblendalpha_e <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_e <= r_stkdata[10:8];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_e <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_srcca <= 0;
        else if(INIT)
                r_setblendalpha_srcca <= 0;
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDALPHA && executable )
                r_setblendalpha_srcca <= r_stkdata[7:0];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_srcca <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_coef0 <= 0;
        else if(INIT)
                r_setblendalpha_coef0 <= 0;
        else if(current == CMD2 && cmdName == SETBLENDALPHA && executable )
                r_setblendalpha_coef0 <= r_stkdata[31:0];
        else if(current == CMD1 && r_stkdata[31:24] == SETBLENDOFF && executable )
                r_setblendalpha_coef0 <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_setblendalpha_coef1 <= 0;
        else if(INIT)
                r_setblendalpha_coef1 <= 0;
        else if(current == CMD3 && cmdName == SETBLENDALPHA && executable )
                r_setblendalpha_coef1 <= r_stkdata[31:0];
end
//PATBLT
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_patblt_dposx <= 0;
        else if(INIT)
                r_patblt_dposx <= 0;
        else if(current == CMD2 && cmdName == PATBLT && executable )
                r_patblt_dposx <= r_stkdata[26:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_patblt_dposy <= 0;
        else if(INIT)
                r_patblt_dposy <= 0;
        else if(current == CMD2 && cmdName == PATBLT && executable )
                r_patblt_dposy <= r_stkdata[10:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_patblt_dsizx <= 0;
        else if(INIT)
                r_patblt_dsizx <= 0;
        else if(current == CMD3 && cmdName == PATBLT && executable )
                r_patblt_dsizx <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_patblt_dsizy <= 0;
        else if(INIT)
                r_patblt_dsizy <= 0;
        else if(current == CMD3 && cmdName == PATBLT && executable )
                r_patblt_dsizy <= r_stkdata[9:0];
end
//BITBLT
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_dposx <= 0;
        else if(INIT)
                r_bitblt_dposx <= 0;
        else if(current == CMD2 && cmdName == BITBLT && executable )
                r_bitblt_dposx <= r_stkdata[26:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_dposy <= 0;
        else if(INIT)
                r_bitblt_dposy <= 0;
        else if(current == CMD2 && cmdName == BITBLT && executable )
                r_bitblt_dposy <= r_stkdata[10:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_dsizx <= 0;
        else if(INIT)
                r_bitblt_dsizx <= 0;
        else if(current == CMD3 && cmdName == BITBLT && executable )
                r_bitblt_dsizx <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_dsizy <= 0;
        else if(INIT)
                r_bitblt_dsizy <= 0;
        else if(current == CMD3 && cmdName == BITBLT && executable )
                r_bitblt_dsizy <= r_stkdata[9:0];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_sposx <= 0;
        else if(INIT)
                r_bitblt_sposx <= 0;
        else if(current == CMD4 && cmdName == BITBLT && executable )
                r_bitblt_sposx <= r_stkdata[25:16];
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_bitblt_sposy <= 0;
        else if(INIT)
                r_bitblt_sposy <= 0;
        else if(current == CMD4 && cmdName == BITBLT && executable )
                r_bitblt_sposy <= r_stkdata[9:0];
end
//-------------------------------------------------------------------------
//ready 生成
//-------------------------------------------------------------------------
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_readyBitAdd <= 0;
        else if(INIT)
                r_readyBitAdd <= 0;
        else if(current == CMD4 && cmdName == BITBLT)
                r_readyBitAdd <= 1;
        else if(current == CMD3 && cmdName == PATBLT)
                r_readyBitAdd <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_readyPatAdd <= 0;
        else if(INIT)
                r_readyPatAdd <= 0;
        else if(current == CMD3 && cmdName == PATBLT)
                r_readyPatAdd <= 1;
        else if(current == CMD4 && cmdName == BITBLT)
                r_readyPatAdd <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_readyBitPixel <= 0;
        else if(INIT)
                r_readyBitPixel <= 0;
        else if(current == CMD4 && cmdName == BITBLT)
                r_readyBitPixel <= 1;
        else if(current == CMD3 && cmdName == PATBLT)
                r_readyBitPixel <= 0;
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_readyPatPixel <= 0;
        else if(INIT)
                r_readyPatPixel <= 0;
        else if(current == CMD3 && cmdName == PATBLT)
                r_readyPatPixel <= 1;
        else if(current == CMD4 && cmdName == BITBLT)
                r_readyPatPixel <= 0;
end
//-------------------------------------------------------------------------
//出力処理
//-------------------------------------------------------------------------
assign BUF_RD = ifRead;
assign EODL = r_eodl;
assign REG_SETFRAME_VRAMADR =    r_setframe_vramadr;   
assign REG_SETFRAME_WIDTH =      r_setframe_width;     
assign REG_SETFRAME_HEIGHT =     r_setframe_height;    
assign REG_SETDRAWAREA_POSX =    r_setdrawarea_posx;   
assign REG_SETDRAWAREA_POSY =    r_setdrawarea_posy;   
assign REG_SETDRAWAREA_SIZX =    r_setdrawarea_sizx;   
assign REG_SETDRAWAREA_SIZY =    r_setdrawarea_sizy;   
assign REG_SETTEXTURE_FMT =      r_settexture_fmt;     
assign REG_SETTEXTURE_VRAMADR =  r_settexture_vramadr; 
assign REG_SETTEXTURE_WIDTH =    r_settexture_width;   
assign REG_SETTEXTURE_HEIGHT =   r_settexture_height;  
assign REG_SETFCOLOR =           r_setfcolor;          
assign REG_SETSTMODE =           r_setstmode;          
assign REG_SETSCOLOR_MASK =      r_setscolor_mask;     
assign REG_SETSCOLOR_L =         r_setscolor_l;        
assign REG_SETSCOLOR_H =         r_setscolor_h;        
assign REG_SETBLENDOFF =         r_setblendoff;        
assign REG_SETBLENDALPHA_A =     r_setblendalpha_a;    
assign REG_SETBLENDALPHA_B =     r_setblendalpha_b;    
assign REG_SETBLENDALPHA_C =     r_setblendalpha_c;    
assign REG_SETBLENDALPHA_D =     r_setblendalpha_d;    
assign REG_SETBLENDALPHA_E =     r_setblendalpha_e;    
assign REG_SETBLENDALPHA_SRCCA = r_setblendalpha_srcca;
assign REG_SETBLENDALPHA_COEF0 = r_setblendalpha_coef0;
assign REG_SETBLENDALPHA_COEF1 = r_setblendalpha_coef1;
assign REG_PATBLT_DPOSX =        r_patblt_dposx;       
assign REG_PATBLT_DPOSY =        r_patblt_dposy;       
assign REG_PATBLT_DSIZX =        r_patblt_dsizx;       
assign REG_PATBLT_DSIZY =        r_patblt_dsizy;       
assign REG_BITBLT_DPOSX =        r_bitblt_dposx;       
assign REG_BITBLT_DPOSY =        r_bitblt_dposy;       
assign REG_BITBLT_DSIZX =        r_bitblt_dsizx;       
assign REG_BITBLT_DSIZY =        r_bitblt_dsizy;       
assign REG_BITBLT_SPOSX =        r_bitblt_sposx;       
assign REG_BITBLT_SPOSY =        r_bitblt_sposy;       

//ready
assign READYBIT_ADD     =        r_readyBitAdd;
assign READYPAT_ADD     =        r_readyPatAdd;
assign READYBIT_PIXEL   =        r_readyBitPixel;
assign READYPAT_PIXEL   =        r_readyPatPixel;

//start
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_start <= 0;
        else if(INIT)
                r_start <= 0;
        else if((current == CMD4 && cmdName == BITBLT) || (current == CMD3 && cmdName == PATBLT))
                r_start <= 1;
        else
                r_start <= 0;
end
assign STARTBLT_ADD   = r_start;
assign STARTBLT_PIXEL = r_start;
//ERROR
//とりあえず０固定
assign ERR_DEC = 0;
//assign ERR_DEC = r_start;
endmodule
