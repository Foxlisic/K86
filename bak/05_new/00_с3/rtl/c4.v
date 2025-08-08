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

wire [11:0] ram_a, rom_a;
wire [ 7:0] ram_i, rom_i;
wire [10:0] cursor;

video U1
(
    .clock      (clock_25),

    // Физический интерфейс
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),

    // Подключение к видеопамяти и шрифтам
    .ram_a      (ram_a),
    .rom_a      (rom_a),
    .ram_i      (ram_i),
    .rom_i      (rom_i),
    .cursor     (cursor)
);

vram U2
(
    .clock      (~clock_25),
    .a          (ram_a),
    .q          (ram_i)
);

vrom U3
(
    .clock      (~clock_25),
    .a          (rom_a),
    .q          (rom_i)
);

assign LED = KEY;

endmodule
