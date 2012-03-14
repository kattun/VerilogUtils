module draw_srcbuf
(
  input       	CLK,
  input       	RST_X,
  input       	INIT,
  input [63:0]	VIF_RDATA,
  input       	VIF_DRWRDATAVLD,
  input       	SRCSEL,
  input       	BUF_RD,
  output [63:0]	DATA,
  output       	DATAVALID,
  output       	EMPTY_PIXEL,
  output       	EMPTY_VRAM,
  output       	FULL_PIXEL,
  output       	FULL_VRAM,
  output       	BUF_OVER,
  output       	BUF_UNDER
);

reg     [63:0]          rData;
reg                     rValid;
reg                     rSrcsel;
wire                    empty_fifo;
wire                    full_fifo;

wire                    almostEmpty_fifo, almostFull_fifo;
wire    [8:0]           dataCount;

//-------------------------------------------------------------------------
//入力データ拾い
//-------------------------------------------------------------------------
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rData <= 0;
        else if(INIT)
                rData <= 0;
        else
                rData <= VIF_RDATA;
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rValid <= 0;
        else if(INIT)
                rValid <= 0;
        else
                rValid <= VIF_DRWRDATAVLD;
end
always @(posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rSrcsel <= 0;
        else if(INIT)
                rSrcsel <= 0;
        else
                rSrcsel <= SRCSEL;
end
//-------------------------------------------------------------------------
//FIFO呼び出し
//stanard fifoにする。
//-------------------------------------------------------------------------
fifoSecond_64in64out_512depth src_fifo
(
        .clk          (CLK),
        .din          (rData),
        .rd_en        (BUF_RD),
        .srst         (INIT),
        .wr_en        (rValid & rSrcsel),
        .dout         (DATA),
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
