module marsohod2
(
    input           clk,
    output   [3:0]  led,
    input    [1:0]  keys,
    output          adc_clock_20mhz,
    input    [7:0]  adc_input,
    output          sdram_clock,
    output   [11:0] sdram_addr,
    output   [1:0]  sdram_bank,
    inout    [15:0] sdram_dq,
    output          sdram_ldqm,
    output          sdram_udqm,
    output          sdram_ras,
    output          sdram_cas,
    output          sdram_we,
    output   [4:0]  vga_r,
    output   [5:0]  vga_g,
    output   [4:0]  vga_b,
    output          vga_hs,
    output          vga_vs,
    input           ftdi_rx,
    output          ftdi_tx,
    inout    [1:0]  usb0,
    inout    [1:0]  usb1,
    output          sound_left,
    output          sound_right,
    inout           ps2_keyb_clk,
    inout           ps2_keyb_dat,
    inout           ps2_mouse_clk,
    inout           ps2_mouse_dat
);

// Для чтения с GPU
wire [11:0] char_address, font_address;
wire [ 7:0] char_data,    font_data;

// -----------------------------------------------------------------------------
// Генерация частот
// -----------------------------------------------------------------------------
wire locked, clock_25, clock_100;

pll unit_pll
(
    .clk       (clk),
    .m25       (clock_25),
    .m100      (clock_100),
    .locked    (locked)
);

// -----------------------------------------------------------------------------
// ЦЕНТРАЛЬНЫЙ ПРОЦЕССОР
// -----------------------------------------------------------------------------

wire we_data = (address <  20'h08000); // 32K RAM
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
    // Тестово
    .pin        (adc_input),
    .pa         (sdram_dq[15:0]),
    .pr         (sdram_addr[0]),
    .pw         (sdram_addr[1])
);

// -----------------------------------------------------------------------------
// Внутрисхемная память
// 32K RAM
// 8K  TEXT
// 4K  BIOS
// -----------------------------------------------------------------------------

base M1
(
    .clock (clock_100),
    .a     (address[14:0]),
    .d     (out),
    .q     (in_data),
    .w     (we & we_data)
);

// $B8000-$B8FFF 4K
char T2
(
    .clock  (clock_100),

    // Обмен данными с процессором
    .a      (address[11:0]),
    .d      (out),
    .q      (in_char),
    .w      (we & we_char),

    // Видеоадаптер
    .ax     (char_address),
    .qx     (char_data)
);

// Шрифты 4K
font T3(.clock  (clock_100), .a(font_address), .q(font_data));

// -----------------------------------------------------------------------------
// Текстовый терминал. Выводит на экран 8x8 шрифт из данных в памяти `char`
// -----------------------------------------------------------------------------

text T1
(
    // Опорная частота 25 мгц
    .clock  (clock_25),

    // Выходные данные
    .r      (vga_r[4:1]),
    .g      (vga_g[5:2]),
    .b      (vga_b[4:1]),
    .hs     (vga_hs),
    .vs     (vga_vs),

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

