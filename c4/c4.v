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
// -----------------------------------------------------------------------------
assign BUZZ = 1'b1;
assign DIG  = 4'b1111;
assign LED  = 4'b1111;
// -----------------------------------------------------------------------------
assign {VGA_R, VGA_G, VGA_B} = {vga_r[3], vga_g[3], vga_b[3]};
// -----------------------------------------------------------------------------
wire clock, clock_100, rst_n;
wire [ 3:0] vga_r, vga_g, vga_b;
wire [12:0] vga_a;
wire [ 7:9] vga_i;
// -----------------------------------------------------------------------------
wire w_m32k = a <  20'h08000;                   // 32K RAM
wire w_m4k  = a >= 20'h08000 && a < 20'h09000;  // 4K RAM
wire w_m8k  = a >= 20'hB8000 && a < 20'hBA000;  // 8K VIDEO
wire w_m2k  = a >= 20'hFF800;                   // 2K BIOS
// -----------------------------------------------------------------------------
wire [19:0] a;
wire [ 7:0] i32, i8, i4, i2;
wire [ 7:0] i = w_m32k ? i32 : w_m8k ? i8 : w_m4k ? i4 : w_m2k ? i2 : 8'hFF;
wire [ 7:0] o;
wire        w;
// -----------------------------------------------------------------------------
pll UPLL
(
    .clock      (CLOCK),
    .c0         (clock),
    .c1         (clock_100),
    .locked     (rst_n)
);
// -----------------------------------------------------------------------------
c86 T1
(
    .clock  (clock),
    .rst_n  (rst_n),
    .ce     (1'b1),
    .a      (a),
    .i      (i),
    .o      (o),
    .w      (w)
);
// -----------------------------------------------------------------------------
m32 M1
(
    .c  (clock_100),
    .a  (a[14:0]),
    .d  (o),
    .w  (w & w_m32k),
    .q  (i32)
);
m8 M2
(
    .c  (clock_100),
    .a  (a[12:0]),
    .d  (o),
    .w  (w & w_m8k),
    .q  (i8),
    .ax (vga_a),
    .qx (vga_i)
);
m4 M3
(
    .c  (clock_100),
    .a  (a[11:0]),
    .d  (o),
    .w  (w & w_m4k),
    .q  (i4)
);
m2 M4
(
    .c  (clock_100),
    .a  (a[10:0]),
    .d  (o),
    .w  (w & w_m2k),
    .q  (i2)
);
// -----------------------------------------------------------------------------
ibm A1
(
    .clock  (clock),
    .r      (vga_r),
    .g      (vga_g),
    .b      (vga_b),
    .hs     (VGA_HS),
    .vs     (VGA_VS),
    .a      (vga_a),
    .i      (vga_i)
);
// -----------------------------------------------------------------------------
endmodule

`include "../c86.v"
`include "../ibm.v"
