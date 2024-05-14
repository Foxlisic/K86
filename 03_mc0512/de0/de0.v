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
    output reg  [9:0]  LEDR,

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
wire we_bios = (address >= 20'hFF000); // 4K BIOS

wire        we, pr, pw;
wire [19:0] address;
wire [15:0] pa;
reg  [ 7:0] pin;
wire [ 7:0] out, in_data, in_char, in_bios;
wire [ 7:0] in =
    we_char ? in_char :
    we_data ? in_data :
    we_bios ? in_bios :
        8'hFF;

cpu IntelCore
(
    .clock      (clock_25),
    .ce         (1'b1),
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we),
    .pin        (pin),
    .pa         (pa),
    .pr         (pr),
    .pw         (pw)
);

// -----------------------------------------------------------------------------
// Внутрисхемная память
// -----------------------------------------------------------------------------

// 00000..1FFFF 128K
base M1
(
    .clock (clock_100),
    .a     (address[16:0]),
    .d     (out),
    .q     (in_data),
    .w     (we & we_data)
);

// FF000..FFFFF 4K
bios M2
(
    .clock (clock_100),
    .a     (address[11:0]),
    .d     (out),
    .q     (in_bios),
    .w     (we & we_bios)
);

// B8000-B8FFF 4K
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
font T3(.clock(clock_100), .a0(font_address), .q0(font_data));

// -----------------------------------------------------------------------------
// Текстовый терминал. Выводит на экран 8x8 шрифт из данных в памяти `char`
// -----------------------------------------------------------------------------

gpu T1
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
    .font_data      (font_data),
    .cursor         (cursor),
);

// -----------------------------------------------------------------------------
// Клавиатура
// -----------------------------------------------------------------------------

wire        kb_done;
wire [7:0]  kb_data;
reg         kb_hit;
reg  [7:0]  kb_key;

/*
kbd KBD
(
    .clock      (clock_25),
    .ps_clock   (PS2_CLK),
    .ps_data    (PS2_DAT),
    .done       (kb_done),
    .data       (kb_data)
);
*/

// Контроллер клавиатуры
ps2 KBD
(
    .CLOCK_25           (clock_25),
    .PS2_CLK            (PS2_CLK),
    .PS2_DAT            (PS2_DAT),
    .received_data      (kb_data),
    .received_data_en   (kb_done),
);

// -----------------------------------------------------------------------------
// УПРАВЛЕНИЕ ПОРТАМИ
// -----------------------------------------------------------------------------

reg [10:0] cursor;
reg [ 7:0] vga_reg_id;

always @(posedge clock_25) begin

    // Получение скан-кода с клавиатуры // vect <= 1'b0; intr <= ~intr;
    if (kb_done) begin kb_key <= kb_data; kb_hit <= 1; end

    if (pw)
    case (pa)
    // VGA порты
    16'h3D4: vga_reg_id <= out;
    16'h3D5: case (vga_reg_id)
        8'h0E: cursor[10:8] <= out;
        8'h0F: cursor[ 7:0] <= out;
    endcase
    endcase

    // Чтение из портов
    if (pr)
    case (pa)
    16'h060: begin pin <= kb_key; end
    16'h064: begin pin <= kb_hit; kb_hit <= 0; end
    16'h3D4: begin pin <= vga_reg_id; end
    16'h3D5: case (vga_reg_id)
        8'h0E: pin <= cursor[10:8];
        8'h0F: pin <= cursor[ 7:0];
    endcase
    endcase

end

endmodule

`include "../cpu.v"
`include "../gpu.v"
`include "../kbd.v"
`include "../ps2.v"

