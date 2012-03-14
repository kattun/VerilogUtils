module draw_regctrl
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [11:0]	ERROR,
  input       	CIF_DRWSEL,
  input [3:0]	CIF_REGWRITE,
  input       	CIF_REGREAD,
  input [3:0]	CIF_REGADR,
  input [31:0]	CIF_REGWDATA,
  input       	BUSY_PIXEL,
  input       	BUSY_ADD,
  input       	BUSY_INTERR,
  input       	WORKINGDRW,
  output [31:0]	DRW_REGRDATA,
  output       	REG_EODL,
  output [22:0]	REG_SETFRAME_VRAMADR,
  output [9:0]	REG_SETFRAME_WIDTH,
  output [9:0]	REG_SETFRAME_HEIGHT,
  output [9:0]	REG_SETDRAWAREA_POSX,
  output [9:0]	REG_SETDRAWAREA_POSY,
  output [9:0]	REG_SETDRAWAREA_SIZX,
  output [9:0]	REG_SETDRAWAREA_SIZY,
  output       	REG_SETTEXTURE_FMT,
  output [22:0]	REG_SETTEXTURE_VRAMADR,
  output [9:0]	REG_SETTEXTURE_WIDTH,
  output [9:0]	REG_SETTEXTURE_HEIGHT,
  output [31:0]	REG_SETFCOLOR,
  output       	REG_SETSTMODE,
  output [3:0]	REG_SETSCOLOR_MASK,
  output [31:0]	REG_SETSCOLOR_L,
  output [31:0]	REG_SETSCOLOR_H,
  output       	REG_SETBLENDOFF,
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
  output       	READYPAT_ADD,
  output       	READYBIT_ADD,
  output       	STARTBLT_ADD,
  output       	READYPAT_PIXEL,
  output       	READYBIT_PIXEL,
  output       	STARTBLT_PIXEL,
  output [3:0]	ERROR_REGCTRL,
  output       	INIT_REGCTRL,
  output [9:0]	REQ_ON_COUNT,
  output [9:0]	REQ_OFF_COUNT
);

//reg out
wire err_RegOut;
wire exe_RegDec, wr_RegBuf;
wire [31:0] data_RegBuf;

//buf out
wire full_BufReg, empty_BufReg;
wire [10:0] wcount_BufReg;
wire full_BufDec, empty_BufDec;
wire [31:0] data_BufDec;
wire valid_BufDec;
wire [1:0] err_BufOut;

//dec out
wire rd_DecBuf;
wire err_DecOut;

assign ERROR_REGCTRL[3:0] = {err_DecOut, err_BufOut, err_RegOut};


draw_regctrl_reg regctrl_reg
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .ERROR(ERROR),
        .WORKINGDRW(WORKINGDRW),
        .CIF_DRWSEL(CIF_DRWSEL),
        .CIF_REGWRITE(CIF_REGWRITE),
        .CIF_REGREAD(CIF_REGREAD),
        .CIF_REGADR(CIF_REGADR),
        .CIF_REGWDATA(CIF_REGWDATA),
        .RBUF_FULL(full_BufReg),
        .RBUF_EMPTY(empty_BufReg),
        .RBUF_WCOUNT(wcount_BufReg),

        .DRW_REGRDATA(DRW_REGRDATA),
        .CMD(data_RegBuf),
        .ERR_REG(err_RegOut),
        .INIT_REG(INIT_REGCTRL),
        .EXE_FLAG(exe_RegDec),
        .BUF_WR(wr_RegBuf),
        .REQ_ON_COUNT(REQ_ON_COUNT),
        .REQ_OFF_COUNT(REQ_OFF_COUNT)
);

draw_regctrl_buf regctrl_buf
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .INDATA(data_RegBuf),
        .BUF_WR(wr_RegBuf),
        .BUF_RD(rd_DecBuf),

        .OUTDATA(data_BufDec),
        .DATAVALID(valid_BufDec),
        .FULL_REG(full_BufReg),
        .EMPTY_REG(empty_BufReg),
        .WCOUNT(wcount_BufReg),
        .FULL_DEC(full_BufDec),
        .EMPTY_DEC(empty_BufDec),
        .ERR_BUF(err_BufOut)
);

draw_regctrl_dec regctrl_dec
(
        .CLK(CLK),
        .RST_X(RST_X),
        .INIT(INIT),
        .EXE(exe_RegDec),
        .BUSY_PIXEL(BUSY_PIXEL),
        .BUSY_ADD(BUSY_ADD),
        .BUSY_INTERR(BUSY_INTERR),
        .BUFDATA(data_BufDec),
        .DATAVALID(valid_BufDec),
        .FULL(full_BufDec),
        .EMPTY(empty_BufDec),

        .BUF_RD(rd_DecBuf),
        .EODL(REG_EODL),
     .REG_SETFRAME_VRAMADR      (REG_SETFRAME_VRAMADR),
     .REG_SETFRAME_WIDTH        (REG_SETFRAME_WIDTH),
     .REG_SETFRAME_HEIGHT       (REG_SETFRAME_HEIGHT),
     .REG_SETDRAWAREA_POSX      (REG_SETDRAWAREA_POSX),
     .REG_SETDRAWAREA_POSY      (REG_SETDRAWAREA_POSY),
     .REG_SETDRAWAREA_SIZX      (REG_SETDRAWAREA_SIZX),
     .REG_SETDRAWAREA_SIZY      (REG_SETDRAWAREA_SIZY),
     .REG_SETTEXTURE_FMT    (REG_SETTEXTURE_FMT),
     .REG_SETTEXTURE_VRAMADR    (REG_SETTEXTURE_VRAMADR),
     .REG_SETTEXTURE_WIDTH      (REG_SETTEXTURE_WIDTH),
     .REG_SETTEXTURE_HEIGHT     (REG_SETTEXTURE_HEIGHT),
     .REG_SETFCOLOR             (REG_SETFCOLOR),
     .REG_SETSTMODE             (REG_SETSTMODE),
     .REG_SETSCOLOR_MASK        (REG_SETSCOLOR_MASK),
     .REG_SETSCOLOR_L           (REG_SETSCOLOR_L),
     .REG_SETSCOLOR_H           (REG_SETSCOLOR_H),
     .REG_SETBLENDOFF           (REG_SETBLENDOFF),
     .REG_SETBLENDALPHA_A       (REG_SETBLENDALPHA_A),
     .REG_SETBLENDALPHA_B       (REG_SETBLENDALPHA_B),
     .REG_SETBLENDALPHA_C       (REG_SETBLENDALPHA_C),
     .REG_SETBLENDALPHA_D       (REG_SETBLENDALPHA_D),
     .REG_SETBLENDALPHA_E       (REG_SETBLENDALPHA_E),
     .REG_SETBLENDALPHA_SRCCA   (REG_SETBLENDALPHA_SRCCA),
     .REG_SETBLENDALPHA_COEF0   (REG_SETBLENDALPHA_COEF0),
     .REG_SETBLENDALPHA_COEF1   (REG_SETBLENDALPHA_COEF1),
     .REG_PATBLT_DPOSX          (REG_PATBLT_DPOSX),
     .REG_PATBLT_DPOSY          (REG_PATBLT_DPOSY),
     .REG_PATBLT_DSIZX          (REG_PATBLT_DSIZX),
     .REG_PATBLT_DSIZY          (REG_PATBLT_DSIZY),
     .REG_BITBLT_DPOSX          (REG_BITBLT_DPOSX),
     .REG_BITBLT_DPOSY          (REG_BITBLT_DPOSY),
     .REG_BITBLT_DSIZX          (REG_BITBLT_DSIZX),
     .REG_BITBLT_DSIZY          (REG_BITBLT_DSIZY),
     .REG_BITBLT_SPOSX          (REG_BITBLT_SPOSX),
     .REG_BITBLT_SPOSY          (REG_BITBLT_SPOSY),
     .READYPAT_ADD              (READYPAT_ADD),
     .READYBIT_ADD              (READYBIT_ADD),
     .STARTBLT_ADD              (STARTBLT_ADD),
     .READYPAT_PIXEL               (READYPAT_PIXEL),
     .READYBIT_PIXEL               (READYBIT_PIXEL),
     .STARTBLT_PIXEL            (STARTBLT_PIXEL),
        .ERR_DEC(err_DecOut)
);
endmodule
