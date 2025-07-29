module c4
(
	input           RESET_N,
	input           CLOCK,          // 50 MHZ
    input   [3:0]   KEY,
    output  [3:0]   LED,
    output          BUZZ,           // Пищалка
    input           RX,             // Прием
    output          TX,             // Отправка
    output          SCL,            // Температурный сенсор :: LM75
    inout           SDA,
    output          I2C_SCL,        // Память 1Кб :: AT24C08
    inout           I2C_SDA,
    output          PS2_CLK,
    inout           PS2_DAT,
    input           IR,             // Инфракрасный приемник
    output          VGA_R,
    output          VGA_G,
    output          VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    output  [ 3:0]  DIG,            // 4x8 Семисегментный
    output  [ 7:0]  SEG,
    inout   [ 7:0]  LCD_D,          // LCD экран
    output          LCD_E,
    output          LCD_RW,
    output          LCD_RS,
    inout   [15:0]  SDRAM_DQ,
    output  [11:0]  SDRAM_A,        // Адрес
    output  [ 1:0]  SDRAM_B,        // Банк
    output          SDRAM_RAS,      // Строка
    output          SDRAM_CAS,      // Столбце
    output          SDRAM_WE,       // Разрешение записи
    output          SDRAM_L,        // LDQM
    output          SDRAM_U,        // UDQM
    output          SDRAM_CKE,      // Активация тактов
    output          SDRAM_CLK,      // Такты
    output          SDRAM_CS        // Выбор чипа (=0)
);

assign BUZZ = 1'b1;
assign DIG  = 4'b1111;

// ---------------------------------------------------------------------
wire clock_25, clock_100, locked;

pll UPLL
(
    .clock      (CLOCK),
    .c0         (clock_25),
    .c1         (clock_100),
    .locked     (locked)
);
// ---------------------------------------------------------------------

wire [14:0] vga_a;
wire [ 7:0] vga_d;

vga UVGA
(
    .clock      (clock_25),
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    .ax         (vga_a),
    .dx         (vga_d),
);

// ---------------------------------------------------------------------

wire [19:0] address;
wire [ 7:0] out, in;
wire        we;

memory MEM
(
    .clock      (clock_100),
    // Процессор
    .a          (address[14:0]),
    .q          (in),
    .d          (out),
    .w          (we),
    // Адаптер
    .ax         (vga_a),
    .qx         (vga_d),
);

// ---------------------------------------------------------------------
core CORE
(
    .clock      (clock_25),
    .ce         (1'b1),
    .reset_n    (locked),
    .cfg_ip0    (1'b1),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule

`include "../core.v"
