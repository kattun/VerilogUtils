module draw_regctrl_buf
(
  input 		CLK,
  input 		RST_X,
  input 		INIT,
  input [31:0]	INDATA,
  input       	BUF_WR,
  input       	BUF_RD,
  output [31:0]	OUTDATA,
  output       	DATAVALID,
  output       	FULL_REG,
  output       	EMPTY_REG,
  output [10:0]	WCOUNT,
  output       	FULL_DEC,
  output       	EMPTY_DEC,
  output [1:0]	ERR_BUF
);

wire full_fifo, empty_fifo, over_fifo, under_fifo;
wire fvalid;
wire [31:0] fout;
wire [9:0]  wWcount;
//-------------------------------------------------------------------------
//FIFOの生成
//-------------------------------------------------------------------------
fifoSecond_32in32out_1024depth cmd_fifo
(
        .clk          (CLK),
        .din          (INDATA),
        .rd_en        (BUF_RD),
        .rst          (!RST_X),
        .wr_en        (BUF_WR),
        .data_count (wWcount),
        .dout         (fout),
        .empty        (empty_fifo),
        .full         (full_fifo),
        .overflow     (over_fifo),
        .valid        (fvalid),
        .underflow    (under_fifo)
);

//-------------------------------------------------------------------------
//出力処理
//-------------------------------------------------------------------------
assign OUTDATA = fout;
assign DATAVALID = fvalid;
assign FULL_REG = full_fifo;
assign EMPTY_REG = empty_fifo;
assign FULL_DEC = full_fifo;
assign EMPTY_DEC = empty_fifo;
assign ERR_BUF = {over_fifo, under_fifo};
assign WCOUNT[10] = 0;
assign WCOUNT[9:0] = wWcount;

endmodule
