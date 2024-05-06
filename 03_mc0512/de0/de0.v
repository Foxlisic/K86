module de0
(
    // Reset
    input              RESET_N,

    // Clocks
    input              CLOCK_50,
    input              CLOCK2_50,
    input              CLOCK3_50,
    input              CLOCK4_50,

    // DRAM
    output             DRAM_CKE,
    output             DRAM_CLK,
    output      [1:0]  DRAM_BA,
    output      [12:0] DRAM_ADDR,
    inout       [15:0] DRAM_DQ,
    output             DRAM_CAS_N,
    output             DRAM_RAS_N,
    output             DRAM_WE_N,
    output             DRAM_CS_N,
    output             DRAM_LDQM,
    output             DRAM_UDQM,

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

// MISO: Input Port
assign SD_DATA[0] = 1'bZ;

// SDRAM Enable
assign DRAM_CKE  = 0;   // 1=ChipEnable | 0=Disable
assign DRAM_CS_N = 1;   // 0=ChipSelect | 1=Unselect

// Z-state
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// LED OFF
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;

// Для чтения с GPU
wire [11:0] char_address, font_address;
wire [ 7:0] char_data,    font_data;

// --------------------------------------------------------------
// Генератор частот
// --------------------------------------------------------------

wire locked;
wire clock_25;

pll PLL0
(
    .clkin     (CLOCK_50),
    .m25       (clock_25),
    .m50       (clock_50),
    .m100      (clock_100),
    .locked    (locked)
);

// -----------------------------------------------------------------------------
// ЦЕНТРАЛЬНЫЙ ПРОЦЕССОР
// -----------------------------------------------------------------------------

wire we_data = (address <  20'h20000); // 128K RAM
wire we_char = (address >= 20'hB8000) && (address <= 20'hB8FFF); // 4K CHAR

wire        we, pr, pw;
wire [19:0] address;
wire [ 7:0] out, in_data, in_char;
wire [ 7:0] in =
    we_char ? in_char :
    we_data ? in_data :
        8'hFF;

core IntelCore
(
    .clock      (clock_25),
    .ce         (1'b1),
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we),
    .pr         (pr),
    .pw         (pw)
);

// -----------------------------------------------------------------------------
// Внутрисхемная память
// -----------------------------------------------------------------------------

base M1
(
    .clock (clock_100),
    .a     (address[16:0]),
    .d     (out),
    .q     (in_data),
    .w     (we & we_data)
);

// $B8000-$B8FFF 4K
char T2
(
    .clock  (clock_100),

    // Обмен данными с процессором
    .a0     (address[11:0]),
    .d0     (out),
    .q0     (in_char),
    .w0     (we & we_char),

    // Видеоадаптер
    .a1     (char_address),
    .q1     (char_data)
);

// Шрифты 4K
font T3(.clock  (clock_100), .a0 (font_address), .q0 (font_data));

// -----------------------------------------------------------------------------
// Текстовый терминал. Выводит на экран 8x8 шрифт из данных в памяти `char`
// -----------------------------------------------------------------------------

text T1
(
    // Опорная частота 25 мгц
    .clock  (clock_25),

    // Выходные данные
    .r      (VGA_R),
    .g      (VGA_G),
    .b      (VGA_B),
    .hs     (VGA_HS),
    .vs     (VGA_VS),

    // Доступ к памяти
    .char_address   (char_address),
    .font_address   (font_address),
    .char_data      (char_data),
    .font_data      (font_data)
);

endmodule

`include "../core.v"
`include "../text.v"
`include "module/base.v"
`include "module/char.v"
`include "module/font.v"

