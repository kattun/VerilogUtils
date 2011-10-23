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
