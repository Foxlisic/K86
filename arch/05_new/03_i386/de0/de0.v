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

assign SD_DATA[0] = 1'bZ;

// High-Impendance-State
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// Вывод семисега
reg [23:0] u;

seg7 H0(.d4(u[23:20]), .hex(HEX5), .c(CLOCK_50), .e(1'b0));
seg7 H1(.d4(u[19:16]), .hex(HEX4), .c(CLOCK_50), .e(1'b0));
seg7 H2(.d4(u[15:12]), .hex(HEX3), .c(CLOCK_50), .e(1'b0));
seg7 H3(.d4(u[ 11:8]), .hex(HEX2), .c(CLOCK_50), .e(1'b0));
seg7 H4(.d4(u[  7:4]), .hex(HEX1), .c(CLOCK_50), .e(1'b0));
seg7 H5(.d4(u[  3:0]), .hex(HEX0), .c(CLOCK_50), .e(1'b0));

// ---------------------------------------------------------------------
wire reset_n, clock_25, clock_50, clock_75, clock_100, clock_106;

// Клавиатура
wire [ 7:0] kb_data;
wire        kb_done;
reg         kbd_hit;
reg [ 7:0]  kbd_dat;

// Контроллер прерываний
reg [ 2:0]  vect8;
reg [ 7:0]  irq_in;
reg         irq_pend;           // 0=Прерывание не выполняется =1 В процессе
reg         irq_sig;            // FlipFlop для процессора

// Таймер https://wiki.osdev.org/Programmable_Interval_Timer
reg [ 4:0]  timer_sub;
reg [15:0]  timer_cnt;
reg [15:0]  timer_max;


pll u0
(
    // Источник тактирования
    .clkin  (CLOCK_50),
    .locked (reset_n),

    // Производные частоты
    .m25    (clock_25),
    .m50    (clock_50),
    .m75    (clock_75),
    .m100   (clock_100),
    .m106   (clock_106),
);

// Процессорный модуль
// ---------------------------------------------------------------------

wire [19:0] address;
wire [ 7:0] out;
wire        we;
wire [15:0] port_a;
reg  [ 7:0] port_i;
wire [ 7:0] port_o;
wire        port_w, port_r;

// Определение области видеопамяти
wire [ 7:0] in_common, in_video, in_font, in_hires;

wire        we_common = address  < 20'h20000;
wire        we_video  = address >= 20'hB8000 && address < 20'hB9000;
wire        we_font   = address >= 20'hC0000 && address < 20'hC1000;
wire        we_hires  = address >= 20'hA0000 && address < 20'hC0000; // 2x64K под видеопамять

// Получение данных из разных областей видеопамяти
wire [ 7:0] in =
    we_video    ? in_video :
    we_font     ? in_font :
    we_hires    ? in_hires :
    we_common   ? in_common :
                  8'hFF;

core CORE
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce         (1'b1),
    .a          (address),
    .i          (in),
    .o          (out),
    .w          (we),
    .intr       (irq_sig),
    .intn       (irq_in),

    .port_a     (port_a),
    .port_w     (port_w),
    .port_r     (port_r),
    .port_i     (port_i),
    .port_o     (port_o)

);

// Видеопроцессор
// ---------------------------------------------------------------------

reg  [ 7:0] dac_a, dac_ax;
reg  [11:0] cursor;
reg  [ 3:0] cursor_start, cursor_end;
reg  [ 7:0] vga_reg;
reg         vga_retrace;
wire        vretrace;
reg  [ 7:0] videomode;  // 0=TEXT; 1=320x200

video VD
(
    // ----
    .clock      (clock_25),
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // ----
    .cursor         (cursor),
    .video_a        (video_a),
    .video_q        (video_q),
    .font_a         (font_a),
    .font_q         (font_q),
    .dac_a          (dac_av),
    .dac_q          (dac_qv),
    .videomode      (videomode),
    .cursor_start   (cursor_start),
    .cursor_end     (cursor_end),
    .hires_a        (hires_a),
    .hires_q        (hires_q)
);

// Блочная память
// ---------------------------------------------------------------------

wire [11:0] font_a, video_a;
wire [16:0] hires_a;
wire [ 7:0] font_q, video_q, hires_q;

reg  [15:0] dac_d;
wire [15:0] dac_q;
reg         dac_w;
wire [ 7:0] dac_av;
wire [15:0] dac_qv;
reg  [ 1:0] dac_cnt;

// 128K общей памяти
mem_common M0
(
    .clock      (clock_100),
    .a          (address[16:0]),
    .q          (in_common),
    .d          (out),
    .w          (we & we_common)
);

// 4K FONT
mem_font M1
(
    .clock      (clock_100),
    .a          (font_a),
    .q          (font_q),
    .ax         (address[11:0]),
    .qx         (in_font),
    .dx         (out),
    .wx         (we & we_font)
);

// 4K VIDEO TEXT
mem_video M2
(
    .clock      (clock_100),
    .a          (video_a),
    .q          (video_q),
    .ax         (address[11:0]),
    .qx         (in_video),
    .dx         (out),
    .wx         (we & we_video)
);

// 128K 640x400x16
mem_hires M3
(
    .clock      (clock_100),
    .a          (hires_a),
    .q          (hires_q),
    .ax         (address[16:0]),
    .qx         (in_hires),
    .dx         (out),
    .wx         (we & we_hires)
);

// 1K Палитра
mem_dac M4
(
    .clock      (clock_100),
    .a          (dac_a),
    .d          (dac_d),
    .w          (dac_w),
    .q          (dac_q),
    .ax         (dac_av),
    .qx         (dac_qv),
);


// Карта SD
// ---------------------------------------------------------------------

wire        busy, error;
reg         command, sd_rw;
reg [31:0]  sd_lba;

sd SD
(
    .clock      (clock_25),
    .reset_n    (reset_n),

    // Физический интерфейс
    .cs         (SD_DATA[3]),   // Выбор чипа
    .sclk       (SD_CLK),       // Тактовая частота
    .miso       (SD_DATA[0]),   // Входящие данные
    .mosi       (SD_CMD),       // Исходящие

    // Отсылка команды
    .command    (command),      // DO CMD
    .rw         (sd_rw),        // 0=READ 1=WRITE
    .lba        (sd_lba),       // 0 SECTOR
    .busy       (busy),
    .error      (error)
);

// -- Подключить модуль памяти (1К)

// ---------------------------------------------------------------------
// Управление портами и IRQ
// ---------------------------------------------------------------------

always @(posedge clock_25)
if (reset_n == 0 || RESET_N == 0) begin

    cursor          <= 0;
    cursor_start    <= 14;
    cursor_end      <= 15;
    videomode       <= 0;

end else begin

    dac_w <= 0;

    // Срабатывание IRQ
    // Пока прерывание не будет обработано (irq_pend), новое вызвано не будет
    // -----------------------------------------------------------------

    if (vect8 && irq_pend == 0) begin

        irq_sig  <= ~irq_sig;
        irq_pend <= 1;

        if      (vect8[0]) begin vect8[0] <= 0; irq_in <= 8;  end   // Таймер
        else if (vect8[1]) begin vect8[1] <= 0; irq_in <= 9;  end   // Клавиатура
        else if (vect8[2]) begin vect8[2] <= 0; irq_in <= 10; end   // VRetrace

    end

    // Запись в порты
    // -----------------------------------------------------------------
    if (port_w)
    case (port_a)

    // Контроллер прерываний
    16'h0020: begin irq_pend <= 0; end  // EOI
    16'h00A0: begin end                 // IRQMASK

    // Запись палитры
    16'h03C8: begin dac_ax <= port_o; dac_cnt <= 0; end
    16'h03C9: case (dac_cnt)
        0: begin dac_cnt <= 1; dac_d[11:8] <= port_o[5:2]; end
        1: begin dac_cnt <= 2; dac_d[ 7:4] <= port_o[5:2]; end
        2: begin dac_cnt <= 0; dac_d[ 3:0] <= port_o[5:2];
                 dac_w   <= 1; dac_a       <= dac_ax;
                 dac_ax  <= dac_ax + 1; end
    endcase
    // Управление VGA, курсором
    16'h03D4: begin vga_reg <= port_o; end
    16'h03D5: case (vga_reg)

        8'h0A: cursor_start <= port_o[3:0]; // 5-й бит отключает курсор
        8'h0B: cursor_end   <= port_o[3:0];
        8'h0E: cursor[11:8] <= port_o[3:0];
        8'h0F: cursor[ 7:0] <= port_o;

    endcase

    // Переключение видеорежима
    16'h03D8: begin videomode <= port_o; end
    endcase

    // Чтение из портов
    // -----------------------------------------------------------------
    if (port_r)
    case (port_a)
    16'h0060: begin port_i <= kbd_dat; end
    16'h0061: begin port_i <= kbd_hit; kbd_hit <= 0; end
    16'h0064: begin port_i <= {PS2_CLK2, PS2_DAT2, 2'b00, PS2_CLK, PS2_DAT}; end
    16'h03DA: begin port_i <= {vga_retrace, 2'b00}; vga_retrace <= 0; end
    endcase

    // Установка PEND для прерываний
    // -----------------------------------------------------------------

    // Клавиатура
    if (kb_done)  begin vect8[1] <= 1; kbd_hit <= 1; kbd_dat <= kb_data; end
    if (vretrace) begin vect8[2] <= 1; vga_retrace <= 1; end

    // Снижение скорости 25 Мгц до 1,25 мгц
    if (timer_sub == 20) begin

        timer_sub <= 0;
        timer_cnt <= timer_cnt + 1;

        // Срабатывание таймера, достигая timer_max (это ~18 Гц)
        if (timer_cnt == timer_max) begin vect8[0] <= 1; timer_cnt <= 1; end

    end else timer_sub <= timer_sub + 1;

end

endmodule

`include "../core.v"
