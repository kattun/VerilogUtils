module draw_regctrl_reg
(
  input 		CLK,
  input 		RST_X,
  input 		INIT,
  input [11:0]	ERROR,
  input 		WORKINGDRW,
  input 		CIF_DRWSEL,
  input [3:0]	CIF_REGWRITE,
  input 		CIF_REGREAD,
  input [3:0]	CIF_REGADR,
  input [31:0]	CIF_REGWDATA,
  input       	RBUF_FULL,
  input       	RBUF_EMPTY,
  input [10:0]	RBUF_WCOUNT,
  output [31:0]	DRW_REGRDATA,
  output [31:0]	CMD,
  output       	ERR_REG,
  output 		INIT_REG,
  output       	EXE_FLAG,
  output       	BUF_WR,
  output [9:0]	REQ_ON_COUNT,
  output [9:0]	REQ_OFF_COUNT
);

// アドレス
parameter A_DRAWCTRL    = 0;
parameter A_DRAWSTAT    = 1;
parameter A_DRAWBUFSTAT = 2;
parameter A_DRAWCMD     = 3;
parameter A_REQ_ON_COUNT  = 4;
parameter A_REQ_OFF_COUNT = 5;
// A_DEBUGを最大値にすること。
parameter A_DEBUG     = 6;

// exeは1,0で意味を持つ
parameter INIT_EXE      = 2;

//write処理用
reg [1:0] r_EXE;
reg [31:0] r_CMD;
reg [3:0]  rWrSave;
reg [3:0] r_DEBUG; // 今のところversion用
wire      wWrPlus;

//read処理用
reg [31:0] r_REGDATA;

//ERR処理用
reg [11:0] rErrSave;
reg r_ERR;

//INIT処理用
reg init_reg;

//EXE_FLAG処理用
reg exe_reg;

//REQ 用
reg [9:0] r_REQ_ON_COUNT;
reg [9:0] r_REQ_OFF_COUNT;
//write処理-------------------------------------------------------------
//EXE
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_EXE <= INIT_EXE;
        else if(INIT)
                r_EXE <= INIT_EXE;
        else if( CIF_DRWSEL == 1 && CIF_REGWRITE[0] == 1 && CIF_REGADR == A_DRAWCTRL ) begin
                r_EXE <= CIF_REGWDATA[0];
        end
end

//CMD
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_CMD <= 0;
        else if(INIT)
                r_CMD <= 0;
        else if( CIF_DRWSEL == 1 && CIF_REGADR == A_DRAWCMD ) begin
                if(CIF_REGWRITE[3] == 1)
                        r_CMD[31:24] <= CIF_REGWDATA[31:24];
                if(CIF_REGWRITE[2] == 1)
                        r_CMD[23:16] <= CIF_REGWDATA[23:16];
                if(CIF_REGWRITE[1] == 1)
                        r_CMD[15:8] <= CIF_REGWDATA[15:8];
                if(CIF_REGWRITE[0] == 1)
                        r_CMD[7:0] <= CIF_REGWDATA[7:0];
        end
end
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rWrSave <= 0;
        else if(INIT)
                rWrSave <= 0;
        else if(!CIF_DRWSEL)
                rWrSave <= 0;
        else if(CIF_REGADR != A_DRAWCMD)
                rWrSave <= 0;
        else begin
                if(CIF_REGWRITE[3] == 1)
                        rWrSave[3] <= 1'b1;
                else if(wWrPlus)
                        rWrSave[3] <= 0;

                if(CIF_REGWRITE[2] == 1)
                        rWrSave[2] <= 1'b1;
                else if(wWrPlus)
                        rWrSave[2] <= 0;

                if(CIF_REGWRITE[1] == 1)
                        rWrSave[1] <= 1'b1;
                else if(wWrPlus)
                        rWrSave[1] <= 0;

                if(CIF_REGWRITE[0] == 1)
                        rWrSave[0] <= 1'b1;
                else if(wWrPlus)
                        rWrSave[0] <= 0;
        end
end
assign wWrPlus = &(rWrSave);

//REQ
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_REQ_ON_COUNT <= 0;
        else if(INIT)
                r_REQ_ON_COUNT <= 0;
        else if( CIF_DRWSEL == 1 && CIF_REGADR == A_REQ_ON_COUNT ) begin
                r_REQ_ON_COUNT[9:0] <= CIF_REGWDATA[9:0];
        end
end

always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_REQ_OFF_COUNT <= 0;
        else if(INIT)
                r_REQ_OFF_COUNT <= 0;
        else if( CIF_DRWSEL == 1 && CIF_REGADR == A_REQ_OFF_COUNT ) begin
                r_REQ_OFF_COUNT[9:0] <= CIF_REGWDATA[9:0];
        end
end
//debug
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_DEBUG <= 0;
        else
                r_DEBUG <= 8;
end

//read処理---------------------------------------------------------
//r_REGDATA

wire wErrDetect = |(ERROR);
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                rErrSave <= 0;
        else if(INIT)
                rErrSave <= 0;
        else if(wErrDetect)
                rErrSave <= ERROR;
end

always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_REGDATA <= 0;
        else if(INIT)
                r_REGDATA <= 0;
        else if( CIF_DRWSEL == 1 && CIF_REGREAD == 1) begin
                case ( CIF_REGADR )
                        A_DRAWCTRL: begin
                                r_REGDATA[0]      <= r_EXE[0];
                                r_REGDATA[31:1]   <= 31'b0;
                        end

                        A_DRAWSTAT: begin
                                r_REGDATA[31:28]  <= 4'b0;
                                r_REGDATA[27:16]  <= rErrSave;
                                r_REGDATA[15:1]  <= 15'b0;
                                r_REGDATA[0]    <= WORKINGDRW;
                        end

                        A_DRAWBUFSTAT: begin
                                r_REGDATA[31:18]  <= 13'b0;
                                r_REGDATA[17]  <= RBUF_FULL;
                                r_REGDATA[16]  <= RBUF_EMPTY;
                                r_REGDATA[15:11]  <= 5'b0;
                                r_REGDATA[10:0]   <= RBUF_WCOUNT;
                        end

                        A_REQ_ON_COUNT: begin
                                r_REGDATA[31:10]   <= 0;
                                r_REGDATA[9:0]    <= r_REQ_ON_COUNT[9:0];
                        end

                        A_REQ_OFF_COUNT: begin
                                r_REGDATA[31:10]   <= 0;
                                r_REGDATA[9:0]    <= r_REQ_OFF_COUNT[9:0];
                        end

                        A_DEBUG: begin
                                r_REGDATA[31:4]   <= 0;
                                r_REGDATA[3:0]    <= r_DEBUG;
                        end

                        default:
                                r_REGDATA[31:0]     <= r_REGDATA[31:0];
                endcase // case ( CIF_REGADR )

        end      // else if
end         // always

//ERROR処理-------------------------------------------------------------
// とりあえずアドレスが変だったらエラーにする。
// 他にデバックに必要になったら追加
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X )
                r_ERR <= 0;
        else if(INIT)
                r_ERR <= 0;
        else if( (CIF_DRWSEL == 1) && (CIF_REGADR > A_DEBUG) ) begin
                r_ERR <= 1;
        end
end
//INIT処理-------------------------------------------------------------
//EXE = 0の命令が来たらinterrgenに知らせる
always @* begin
        if(r_EXE == 0)
                init_reg <= 1;
        else
                init_reg <= 0;
end
//EXE_FLAG処理-------------------------------------------------------------
//EXE = 1の命令が来たらdecに知らせる
always @* begin
        if(r_EXE == 1)
                exe_reg <= 1;
        else
                exe_reg <= 0;
end

//BUF_WR処理-------------------------------------------------------------
//ifの条件などはCMDと同じ
        /*
        always @ (posedge CLK or negedge RST_X) begin
                if( !RST_X )
                        r_WR <= 0;
                else if(INIT)
                        r_WR <= 0;
                else if( CIF_DRWSEL == 1 && CIF_REGADR == A_DRAWCMD )
                        r_WR <= 1;
                else
                        r_WR <= 0;
        end
        */

       //-------------------------------------------------------------------------
       //出力処理
       //-------------------------------------------------------------------------
       assign DRW_REGRDATA = r_REGDATA;
       assign ERR_REG = r_ERR;
       plusegen initpls
       (
               .CLK(CLK),
               .RST_X(RST_X),
               .OUT(INIT_REG),
               .IN(init_reg)
       );

       plusegen exepls
       (
               .CLK(CLK),
               .RST_X(RST_X),
               .OUT(EXE_FLAG),
               .IN(exe_reg)
       );
       assign CMD = r_CMD;
       assign BUF_WR = wWrPlus;

       assign REQ_ON_COUNT = r_REQ_ON_COUNT;
       assign REQ_OFF_COUNT = r_REQ_OFF_COUNT;
       endmodule
