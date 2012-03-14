module draw_wrbuf
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [63:0]	PIXEL_DATA,
  input       	WRSEL,
  input       	BUF_WR,
  input       	BUF_RD,
  output [63:0]	DRW_VRAMWDATA,
  output       	DATAVALID,
  output       	EMPTY_PIXEL,
  output       	EMPTY_VRAM,
  output       	FULL_PIXEL,
  output       	FULL_VRAM,
  output       	BUF_OVER,
  output       	BUF_UNDER
);

wire                    empty_fifo;
wire                    full_fifo;
wire                    almostEmpty_fifo, almostFull_fifo;
wire    [8:0]           dataCount;
//-------------------------------------------------------------------------
//FIFO呼び出し
//stanard fifoにする。
//-------------------------------------------------------------------------
fifoSecond_64in64out_512depth wr_fifo
(
        .clk          (CLK),
        .din          (PIXEL_DATA),
        .rd_en        (BUF_RD),
        .srst         (INIT),
        .wr_en        (BUF_WR),
        .dout         (DRW_VRAMWDATA),
        .empty        (empty_fifo),
        .almost_empty (almostEmpty_fifo),
        .full         (full_fifo),
        .almost_full (almostFull_fifo),
        .overflow     (BUF_OVER),
        .valid        (DATAVALID),
        .underflow    (BUF_UNDER),
        .data_count   (dataCount)
);
//-------------------------------------------------------------------------
//出力処理
//-------------------------------------------------------------------------
assign EMPTY_PIXEL = empty_fifo;
assign EMPTY_VRAM = empty_fifo;
assign FULL_PIXEL = full_fifo;
assign FULL_VRAM = full_fifo;
endmodule
