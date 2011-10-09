module sdrd_SPIctrl
(
  input             CLK,
  input             RST_X,
  input   [31:0]    SPIN_ACCESS_ADR,
  input   [1:0]    SPIN_DATATYPE,
  input             BUFFULL,
  input             DO,
  output             BUSY,
  output             INIT,
  output             FAT32BUF_WR,
  output   [255:0]    FAT32BUF_DATA,
  output  reg        CS,
  output  reg        DI,
  output             GND1,
  output             VCC,
  output             SCLK,
  output             GND2,
  output   [3:0]    DEBUG
);


//---------------------------------------------------------------
//prm, reg, wire
//---------------------------------------------------------------
// data type
parameter FAT32         = 2'd1;
parameter RGB           = 2'd2;

// state machine
parameter INIT_CS       = 5'd0;
parameter INIT_CMD0     = 5'd1;
parameter INIT_RES0     = 5'd2;
parameter INIT_CMD1     = 5'd3;
parameter INIT_RES1     = 5'd4;
parameter IDLE          = 5'd5;
parameter READ_CMD17    = 5'd6;
parameter READ_TOKEN    = 5'd7;

// SD access parameter
parameter CS_H_COUNT    = 80;

// CMD make func
parameter START         = 2'b01;
parameter CRC           = 7'b1001010;
parameter UN_CRC        = 7'b0;
parameter STOP          = 1'b1;

// R1 length for count
parameter CMD_R1_LEN    = 6'd48;
parameter RES_R1_LEN    = 4'd8;
parameter NORES_MAX     = 7'd80;
parameter HEAD_LEN      = 9'd8;
parameter DATA_LEN      = 13'd4096;
parameter CRC_LEN       = 9'd16;

// buffering size
parameter BUF_FAT32_LEN = 9'd256;
parameter BUF_RGB_LEN   = 7'd64;

// state machine
reg     [4:0]           current, next;

/* finish */
wire                    finish_CS;

wire                    miss_RES0;
wire                    miss_RES1;
wire                    miss_RES17;

wire                    finish_RES;
wire                    finish_RES0;
wire                    finish_RES1;
wire                    finish_RES17;
reg                     finish_RES17_reg_for_valid_data;

wire                    finish_CMD;
wire                    finish_CMD0; 
wire                    finish_CMD1;
wire                    finish_CMD17;

wire                    finish_count_do_data;
wire                    finish_count_CRC;
wire                    finish_READ_TOKEN;


/* noRES valid */
wire                    noRES_CMD0;
wire                    noRES_CMD1;
wire                    noRES_CMD17;
wire                    noRES;


// ERROR
wire                    err = 0;    // for remove, fatal error

/* counter */
reg     [6:0]           count_CS;
reg     [5:0]           count_CMD;
reg     [3:0]           count_RES;
reg     [6:0]           count_noRES;
reg     [12:0]          count_do_data;
reg     [3:0]           count_CRC;

/* valid */
wire                    valid_count_CMD;
wire                    valid_count_RES;
wire                    valid_count_noRES;
wire                    valid_do_data;
wire                    valid_count_CRC;

reg                     reg_valid_count_RES;
wire                    wire_valid_count_RES;
reg                     reg_valid_do_data;
wire                    wire_valid_do_data;
reg                     reg_valid_count_CRC;

/* input data reg */
reg     [31:0]          addr;
reg     [1:0]           dataType;

reg     [7:0]           do_RES;

// reg                     srDO;

wire                    valid_buffer_FAT;
wire                    valid_buffer_RGB;
wire                    finish_buffer_FAT;
wire                    finish_buffer_RGB;
reg     [8:0]           count_buffer_FAT;
reg     [6:0]           count_buffer_RGB;
reg     [255:0]         buffer_FAT;
reg     [63:0]          buffer_RGB;

/* cmd wire */
wire    [47:0]          wire_CMD0;
wire	  [47:0]        wire_CMD1;
wire	  [47:0]        wire_CMD17;

/* for fifo */

// dsp
wire   [63:0]           do_dsp_fifo_din   ;
wire                    do_dsp_fifo_wr    ;
wire                    do_dsp_fifo_rd    ;
wire                    do_dsp_fifo_full  ;
wire                    do_dsp_fifo_empty ;
wire                    do_dsp_fifo_valid ;
wire   [63:0]           do_dsp_fifo_dout  ;

//---------------------------------------------------------------
//keep input
//---------------------------------------------------------------
// by fat32ctrl
always @ (posedge CLK or negedge RST_X) begin
        if( !RST_X ) begin
                addr     <= 32'b0;
                dataType <= 2'b0;
        end
        else begin
                addr     <= SPIN_ACCESS_ADR;
                dataType <= SPIN_DATATYPE;
        end
end

/* shift regster */
// DO
// always @ (posedge CLK or negedge RST_X) begin
//         if( !RST_X)
        //                 srDO <= 1'b0;
        //         else
                //                 srDO <= DO;
                // end

                /* buffer */
                //fat32 data
                //valid
                assign valid_buffer_FAT = valid_do_data & (dataType == 2'b01);

                //count
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                count_buffer_FAT <= 9'b0;
                        else if( finish_buffer_FAT )
                                count_buffer_FAT <= 9'b0;
                        else if( valid_buffer_FAT )
                                count_buffer_FAT <= count_buffer_FAT + 9'b1;
                end

                //finish
                assign finish_buffer_FAT = (count_buffer_FAT == BUF_FAT32_LEN - 1);

                // buffer
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                buffer_FAT <= 256'b0;
                        else if( finish_buffer_FAT )
                                buffer_FAT <= 256'b0;
                        else if( valid_buffer_FAT )
                                buffer_FAT[count_buffer_FAT] <= DO;
                end

                //dsp data
                //valid
                assign valid_buffer_RGB = valid_do_data & (dataType == 2'b10);

                //count
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                count_buffer_RGB <= 7'b0;
                        else if( finish_buffer_FAT )
                                count_buffer_RGB <= 7'b0;
                        else if( valid_buffer_FAT )
                                count_buffer_RGB <= count_buffer_RGB + 7'b1;
                end

                //finish
                assign finish_buffer_RGB = (count_buffer_RGB == BUF_RGB_LEN - 1);

                // buffer
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                buffer_RGB <= 64'b0;
                        else if( finish_buffer_RGB )
                                buffer_RGB <= 64'b0;
                        else if( valid_buffer_RGB )
                                buffer_RGB[count_buffer_RGB] <= DO;
                end



                //dsp data
                assign do_dsp_fifo_wr           = valid_buffer_RGB;
                assign do_dsp_fifo_din          = buffer_RGB;
                assign do_dsp_fifo_rd           = !do_dsp_fifo_empty;
                fifo_fwft_64in64out_128depth do_dsp_fifo
                (
                        .clk            (CLK                    ),
                        .rst            (!RST_X                 ),
                        .din            (do_dsp_fifo_din        ),
                        .wr_en          (do_dsp_fifo_wr         ),
                        .rd_en          (do_dsp_fifo_rd         ),
                        .full           (do_dsp_fifo_full       ),
                        .empty          (do_dsp_fifo_empty      ),
                        .valid          (do_dsp_fifo_valid      ),
                        .dout           (do_dsp_fifo_dout       )
                );


                //---------------------------------------------------------------
                // state machine
                //---------------------------------------------------------------
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                current <= INIT_CS;
                        else
                                current <= next;
                end

                always @* begin
                        case(current)
                                INIT_CS: begin
                                        if( finish_CS )
                                                next <= INIT_CMD0;
                                        else
                                                next <= INIT_CS;
                                end
                                INIT_CMD0: begin
                                        if( finish_CMD0 )
                                                next <= INIT_RES0;
                                        else
                                                next <= INIT_CMD0;
                                end
                                INIT_RES0: begin
                                        if( noRES_CMD0 | miss_RES0 )
                                                next <= INIT_CS;
                                        else if( finish_RES0 )
                                                next <= INIT_CMD1;
                                        else if( err )
                                                next <= INIT_CS;
                                        else
                                                next <= INIT_RES0;
                                end
                                INIT_CMD1: begin
                                        if( finish_CMD1 )
                                                next <= INIT_RES1;
                                        else
                                                next <= INIT_CMD1;
                                end
                                INIT_RES1: begin
                                        if( noRES_CMD1 | miss_RES1 )
                                                next <= INIT_CMD1;
                                        else if( finish_RES1 )
                                                next <= IDLE;
                                        else if( err )
                                                next <= INIT_CS;
                                        else
                                                next <= INIT_RES1;
                                end
                                IDLE: begin
                                        if( dataType != 2'b0 )
                                                next <= READ_CMD17;
                                        else if( err )
                                                next <= INIT_CS;
                                        else
                                                next <= IDLE;
                                end
                                READ_CMD17: begin
                                        if( finish_CMD17 )
                                                next <= READ_TOKEN;
                                        else if( err )
                                                next <= INIT_CS;
                                        else
                                                next <= READ_CMD17;
                                end
                                READ_TOKEN: begin
                                        if( noRES_CMD17 | miss_RES17 )
                                                next <= READ_CMD17;
                                        else if( finish_READ_TOKEN )
                                                next <= IDLE;
                                        else if( err )
                                                next <= INIT_CS;
                                        else
                                                next <= READ_TOKEN;
                                end
                        endcase
                end

                //---------------------------------------------------------------
                // CS
                //---------------------------------------------------------------
                // count_CS
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                count_CS <= 7'b0;
                        else if(count_CS >= CS_H_COUNT)
                                count_CS <= 7'b0;
                        else if(current == INIT_CS)
                                count_CS <= count_CS + 7'b1;
                end

                assign finish_CS = (count_CS == CS_H_COUNT);


                //---------------------------------------------------------------
                // CMD
                //---------------------------------------------------------------
                // valid_count_CMD
                assign valid_count_CMD = (current == INIT_CMD0) | (current == INIT_CMD1) | (current == READ_CMD17);

                // count_CMD
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                count_CMD <= 6'b0;
                        else if(count_CMD == CMD_R1_LEN - 1)
                                count_CMD <= 6'b0;
                        else if( valid_count_CMD )
                                count_CMD <= count_CMD + 6'b1;
                end

                // finish_CMD
                assign finish_CMD = (count_CMD == CMD_R1_LEN - 1);

                // finish_CMD0
                assign finish_CMD0 = finish_CMD & (current == INIT_CMD0);
                // finish_CMD1
                assign finish_CMD1 = finish_CMD & (current == INIT_CMD1);
                // finish_CMD17
                assign finish_CMD17 = finish_CMD & (current == READ_CMD17);


                //---------------------------------------------------------------
                // CMD function
                //---------------------------------------------------------------
                function [47:0] CMD;
                        input [5:0]     CMD_NUM;
                        input [31:0]    CMD_ARG;
                        case(CMD_NUM)
                                6'd0    : CMD = {START, CMD_NUM, CMD_ARG, CRC, STOP};
                                6'd1    : CMD = {START, CMD_NUM, CMD_ARG, UN_CRC, STOP};
                                6'd17   : CMD = {START, CMD_NUM, CMD_ARG, UN_CRC, STOP};
                                6'd24   : CMD = {START, CMD_NUM, CMD_ARG, UN_CRC, STOP};
                                default : CMD = 48'b0;
                        endcase
                endfunction

                //---------------------------------------------------------------
                // RES
                //---------------------------------------------------------------
                /* RES */
                // wire_valid_count_RES
                assign wire_valid_count_RES = ((current == INIT_RES0) | (current == INIT_RES1) | (current == READ_TOKEN)) & (DO == 1'b0);

                // reg_valid_count_RES
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                reg_valid_count_RES <= 1'b0;
                        else if( count_RES == RES_R1_LEN)
                                reg_valid_count_RES <= 1'b0; 
                        else if( wire_valid_count_RES )
                                reg_valid_count_RES <= 1'b1;

                end
                // valid_count_RES
                assign valid_count_RES = wire_valid_count_RES | reg_valid_count_RES;

                // count_RES
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                count_RES <= 3'b0;
                        else if(count_RES == RES_R1_LEN)
                                count_RES <= 3'b0;
                        else if( valid_count_RES )
                                count_RES <= count_RES + 3'b1;
                end

                // finish_RES
                assign finish_RES = (count_RES == RES_R1_LEN);
                // finish_RES0
                assign finish_RES0 = finish_RES & (current == INIT_RES0);
                // finish_RES1
                assign finish_RES1 = finish_RES & (current == INIT_RES1);
                // finish_RES17
                assign finish_RES17 = finish_RES & (current == READ_TOKEN);
                // finish_RES17_reg_for_valid_data
                always @ (posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                finish_RES17_reg_for_valid_data <= 1'b0;
                        else if( valid_do_data )
                                finish_RES17_reg_for_valid_data <= 1'b0;
                        else if( finish_RES17 )
                                finish_RES17_reg_for_valid_data <= 1'b1;
                end

                // miss RES
                assign miss_RES0 = finish_RES0 & (do_RES[7:0] != 8'b0000_0001);
                assign miss_RES1 = finish_RES1 & (do_RES[7:0] != 8'b0000_0000);
                assign miss_RES17 = finish_RES17 & (do_RES[7:0] != 8'b0000_0000);

                //do_RES(Data Out RESponse)
                // rvカウントは[7:0]で初期値が７,最後が0でなければならないから、-1のまま。
                wire [3:0] wire_rv_count_RES = (RES_R1_LEN - 1) - count_RES;

                always @(posedge CLK or negedge RST_X) begin
                        if( !RST_X )
                                do_RES <= 8'b0;
                        else if( valid_count_RES )
                                do_RES[wire_rv_count_RES] <= DO;
                        else
                                do_RES <= 8'b0;
                end


                /*no RES */
                // valid_count_noRES
                assign valid_count_noRES = (
                        (current == INIT_RES0) 
                        | (current == INIT_RES1)
                        | (current == READ_TOKEN)
                        )
                        & (!valid_count_RES);


                        // count_noRES
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        count_noRES <= 7'b0;
                                else if(count_noRES == NORES_MAX)
                                        count_noRES <= 7'b0;
                                else if(count_RES != 4'b0)
                                        count_noRES <= 7'b0;
                                else if( valid_count_noRES )
                                        count_noRES <= count_noRES + 7'b1;
                        end

                        //noRES
                        assign noRES = (count_noRES == NORES_MAX) & valid_count_RES;
                        assign noRES_CMD0 = noRES & (current == INIT_RES0);
                        assign noRES_CMD1 = noRES & (current == INIT_RES1);
                        assign noRES_CMD17 = noRES & (current == READ_TOKEN);


                        /* data */
                        // wire_valid_do_data
                        assign wire_valid_do_data = finish_RES17_reg_for_valid_data & (DO == 1'b0);

                        // reg_valid_do_data
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        reg_valid_do_data <= 1'b0;
                                else if( wire_valid_do_data )
                                        reg_valid_do_data <= 1'b1;
                                else if( count_do_data == DATA_LEN-1)
                                        reg_valid_do_data <= 1'b0;
                        end

                        //valid_do_data
                        assign valid_do_data = reg_valid_do_data;

                        // count_do_data
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        count_do_data <= 9'b0;
                                else if( finish_count_do_data )
                                        count_do_data <= 9'b0;
                                else if( valid_do_data )
                                        count_do_data <= count_do_data + 9'b1;
                        end

                        // finish_count_do_data
                        assign finish_count_do_data = (count_do_data == DATA_LEN - 1);


                        /* CRC */
                        // reg_valid_count_CRC
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        reg_valid_count_CRC <= 1'b0;
                                else if( finish_count_do_data )
                                        reg_valid_count_CRC <= 1'b1;
                                else if( count_CRC == CRC_LEN-1)
                                        reg_valid_count_CRC <= 1'b0;
                        end

                        // valid_count_CRC
                        assign valid_count_CRC = reg_valid_count_CRC;

                        // count_CRC
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        count_CRC <= 4'b0;
                                else if( finish_count_CRC )
                                        count_CRC <= 4'b0;
                                else if( valid_count_CRC )
                                        count_CRC <= count_CRC + 9'b1;
                        end

                        // finish_count_CRC
                        assign finish_count_CRC = (count_CRC == CRC_LEN - 1);

                        /* finish READ_TOKEN */
                        assign finish_READ_TOKEN = finish_count_CRC;


                        //---------------------------------------------------------------
                        //output
                        //---------------------------------------------------------------
                        /* to FAT32_ctrl */
                        assign SPI_BUSY = !(current == IDLE);
                        assign SPI_INIT = (current < IDLE);

                        assign SPIOUT_FATPRM    = do_fat_fifo_dout;
                        assign SPIOUT_FAT_VALID = do_fat_fifo_valid;

                        /* to dsp */
                        assign SPIOUT_RGBWR     = do_dsp_fifo_valid;
                        assign SPIOUT_RGBDATA   = do_dsp_fifo_dout;

                        /* to SD card */
                        // CS
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        CS <= 1'b0;
                                else if(current == INIT_CS)
                                        CS <= 1'b1;
                                else
                                        CS <= 1'b0;
                        end

                        // DI
                        assign wire_CMD0 = CMD(6'd0, 32'd0);
                        assign wire_CMD1 = CMD(6'd1, 32'd0);
                        assign wire_CMD17 = CMD(6'd17, addr);
                        
                        wire [5:0] wire_rv_countCMD = (CMD_R1_LEN - 1) - count_CMD;
                        always @ (posedge CLK or negedge RST_X) begin
                                if( !RST_X )
                                        DI <= 1'b0;
                                else if( !valid_count_CMD )
                                        DI <= 1'b0;
                                else begin
                                        case(current)
                                                INIT_CMD0  : DI <= wire_CMD0[wire_rv_countCMD];
                                                INIT_CMD1  : DI <= wire_CMD1[wire_rv_countCMD];
                                                READ_CMD17 : DI <= wire_CMD17[wire_rv_countCMD];
                                                default    : DI <= 1'b0;
                                        endcase
                                end
                        end


                        /* const value*/
                        assign SCLK = CLK;
                        assign VCC  = 1'b1;
                        assign GND1 = 1'b0;
                        assign GND2 = 1'b0;
                        assign DEBUG = count_noRES[3:0];


                        endmodule
