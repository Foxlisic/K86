module de0
(
      // Reset
      input              RESET_N,

      // Clocks
      input              CLOCK_50,
      input              CLOCK2_50,
      input              CLOCK3_50,
      inout              CLOCK4_50,

      // DRAM
      output             DRAM_CS,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output      [12:0] DRAM_A,
      output      [1:0]  DRAM_B,
      inout       [15:0] DRAM_DQ,
      output             DRAM_CAS,
      output             DRAM_RAS,
      output             DRAM_W,
      output             DRAM_L,
      output             DRAM_U,

      // GPIO
      inout       [35:0] GPIO_0,
      inout       [35:0] GPIO_1,

      // 7-Segment LED
      output      [6:0]  HEX0,
      output      [6:0]  HEX1,
      output      [6:0]  HEX2,
      output      [6:0]  HEX3,
      output      [6:0]  HEX4,
      output      [6:0]  HEX5,

      // Keys
      input       [3:0]  KEY,

      // LED
      output      [9:0]  LEDR,

      // PS/2
      inout              PS2_CLK,
      inout              PS2_DAT,
      inout              PS2_CLK2,
      inout              PS2_DAT2,

      // SD-Card
      output             SD_CLK,
      inout              SD_CMD,
      inout       [3:0]  SD_DATA,

      // Switch
      input       [9:0]  SW,

      // VGA
      output      [3:0]  VGA_R,
      output      [3:0]  VGA_G,
      output      [3:0]  VGA_B,
      output             VGA_HS,
      output             VGA_VS
);
// -----------------------------------------------------------------------------
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;
// -----------------------------------------------------------------------------
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;
// -----------------------------------------------------------------------------
wire        rst_n, clock, clkhi;
wire [12:0] vga_a;
wire [ 7:0] vga_i;
// -----------------------------------------------------------------------------
wire        w256 = a  < 20'h40000;                       // COMMON 256k
wire        w32  = a >= 20'h40000 && a < 20'h48000;      // COMMON 32k
wire        w8a  = a >= 20'hB8000 && a < 20'hBA000;      // VIDEO MEMORY 8k
wire        w8b  = a >= 20'hA0000 && a < 20'hA2000;      // VIDEO HI 8k
wire        w4b  = a >= 20'hFF000;                       // BIOS 4k
// -----------------------------------------------------------------------------
wire [19:0] a;
wire [ 7:0] o;
wire        w;
wire [ 7:0] i = (w256 ? i256 : w32 ? i32 : w8a ? i8a : w8b ? i8b : w4b ? i4 : 8'hFF);
wire [ 7:0] i256, i32, i8a, i8b, i4;
// -----------------------------------------------------------------------------
pll u0
(
    // Источник тактирования
    .clkin  (CLOCK_50),
    // Производные частоты
    .m25    (clock),
    .m100   (clkhi),
    .rst_n  (rst_n)
);
// -----------------------------------------------------------------------------
ibm A1
(
    .clock  (clock),
    .r      (VGA_R),
    .g      (VGA_G),
    .b      (VGA_B),
    .hs     (VGA_HS),
    .vs     (VGA_VS),
    .a      (vga_a),
    .i      (vga_i)
);
// -----------------------------------------------------------------------------
m8a M1
(
    .c  (clkhi),
    .a  (a[12:0]),
    .d  (o),
    .w  (w & w8a),
    .q  (i8a),
    .ax (vga_a),
    .qx (vga_i)
);
// -----------------------------------------------------------------------------
endmodule

`include "../ibm.v"
