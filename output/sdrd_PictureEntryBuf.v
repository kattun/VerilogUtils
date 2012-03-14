module sdrd_PictureEntryBuf
(
input                CLK 
input                RST_X 
input                WR 
input                RD 
input      [31:0]    INPUT 

output               EMPTY 
output               FULL 
output     [31:0]    OUTPUT 
output               VALID 
);
