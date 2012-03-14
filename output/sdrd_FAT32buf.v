module sdrd_FAT32buf
(
input                CLK 
input                RSTS 
input                WR 
input                RD 
input      [255:0]   INPUT 

output               EMPTY 
output               FULL 
output     [511:0]   OUTPUT 
output               VALID 
);
