module sdrd_FAT32ctrl
(
input                CLK 
input                RST_X 
input                SPI_BUSY 
input                SPI_INIT 
input                FAT32BUF_EMPTY 
input                PICENTRY_EMPTY 
input                PICENTRY_FULL 
input      [511:0]   FATIN_PRM 
input                FATIN_VALID 

output               FAT32BUF_RD 
output               FAT32BUF_RSTS 
output               PICENTRY_WR 
output     [31:0]    PICENTRY_DATA 
output               PICENTRY_RD 
output     [31:0]    FATOUT_ACCESS_ADR 
output     [1:0]     FATOUT_DATATYPE 
);
