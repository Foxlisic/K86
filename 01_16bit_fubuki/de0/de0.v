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

// Объявление проводов
// ---------------------------------------------------------------------
wire        clock_25, clock_100, clock_50, locked;
wire [19:0] address;
wire [ 7:0] port_i, port_o, irq_in, out;
wire        port_w, port_r, irq_sig, we;
wire [15:0] port_a;
wire [11:0] cursor;
wire        videomode; // 0=TEXT; 1=320x200

// DAC для 256 цветов
reg  [ 7:0] dac_a;
reg  [15:0] dac_d;
wire [ 7:0] dac_av;
wire [15:0] dac_q, dac_qv;
reg         dac_w;

// проводка к памяти
wire [15:0] main_a;
wire [15:0] video_a;
wire [11:0] font_a;
wire [ 7:0] font_q, video_q;
wire [ 7:0] in_main, in_font, in_video;

// Совмещенная видеопамять. При записи в B8000h записывает в 8000h
wire we_main  = (address <  20'h10000);
wire we_video = (address >= 20'hA0000 && address < 20'hB92C0); // 80x30 символов
wire we_font  = (address >= 20'hBC000 && address < 20'hBD000);

// Выбор источника памяти
wire [ 7:0] in =
    we_main  ? in_main  :
    we_video ? in_video :
    we_font  ? in_font  : 8'hFF;

// Генератор частот
// ---------------------------------------------------------------------

pll PLL0
(
    .clkin     (CLOCK_50),
    .m25       (clock_25),
    .m50       (clock_50),
    .m100      (clock_100),
    .locked    (locked)
);

// Интерфейс процессора
// ---------------------------------------------------------------------

core C86
(
    // Основное
    .clock      (clock_25),
    .ce         (1'b1),
    .cfg_ip0    (1'b1),         // Начинать с 0000:0100h
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we),

    // Порты ввода-вывода
    .port_a     (port_a),
    .port_w     (port_w),
    .port_r     (port_r),
    .port_i     (port_i),
    .port_o     (port_o),

    // PIC
    .irq        (irq_sig),
    .irq_in     (irq_in)
);

// Видеопроцессор
// ---------------------------------------------------------------------

video VIDEO
(
    .clock      (clock_25),
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // ---
    .videomode  (videomode),
    .cursor     (cursor),
    .font_a     (font_a),
    .font_q     (font_q),
    .video_a    (video_a),
    .video_q    (video_q)
);

// Клавиатура
// ---------------------------------------------------------------------

// Память
// ---------------------------------------------------------------------

// 64K основной памяти
mem_main M0
(
    .clock      (clock_100),
    .a          (address[15:0]),
    .q          (in_main),
    .d          (out),
    .w          (we && we_main),
);

// 64K видеопамяти
mem_video M1
(
    .clock      (clock_100),
    .a          (address[15:0]),
    .q          (in_video),
    .d          (out),
    .w          (we && we_video),
    .ax         (video_a),
    .qx         (video_q)
);

// 4K шрифты
mem_font M2
(
    .clock      (clock_100),
    .a          (address[11:0]),
    .q          (in_font),
    .d          (out),
    .w          (we && we_font),
    .ax         (font_a),
    .qx         (font_q)
);

// Палитра
mem_dac M3
(
    .clock      (clock_100),
    .a          (dac_a),
    .d          (dac_o),
    .w          (dac_w),
    .q          (dac_q),
);

endmodule

`include "../core.v"
`include "../video.v"
`include "../ps2.v"
