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
wire [15:0] port_a;
reg  [ 7:0] port_i;
wire [ 7:0] port_o, out;
wire        port_w, port_r, we;
reg  [11:0] cursor;
reg  [ 3:0] cursor_start, cursor_end;
reg  [ 7:0] vga_reg;
reg         vga_retrace;
wire        vretrace;
reg         videomode;  // 0=TEXT; 1=320x200
reg         videopage;

// DAC для 256 цветов
reg  [ 7:0] dac_a, dac_ax;
reg  [15:0] dac_d;
wire [15:0] dac_q;
reg         dac_w;
wire [ 7:0] dac_av;
wire [15:0] dac_qv;
reg [ 1:0]  dac_cnt;

// проводка к памяти
wire [15:0] main_a;
wire [16:0] video_a;
wire [11:0] font_a;
wire [ 7:0] font_q, video_q;
wire [ 7:0] in_main, in_font, in_video, in_vidac, in_texture;

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

// Видеоускоритель
reg         vidac_cmd;
reg         vidac_page;
wire [17:0] vidac_a;
wire [ 7:0] vidac_i, vidac_o, vidac_tx, vidac_ty, vidac_td;
wire        vidac_w;
wire        vidac_bsy;

// Распределение памяти
wire we_main    = (address <  20'h10000);                        // 64К  Память программы
wire we_video   = (address >= 20'hA0000 && address < 20'hC0000); // 128К Видеопамять
wire we_vidac   = (address >= 20'hC0000 && address < 20'hD0000); // 64К  Программа видак
wire we_texture = (address >= 20'hD0000 && address < 20'hD8000); // 32К  Текстуры 256x128
wire we_font    = (address >= 20'hD8000 && address < 20'hB9000); // 4К   Шрифты 256 символов

// Выбор источника памяти
wire [ 7:0] in =
    we_main  ? in_main  :
    we_video ? in_video :
    we_vidac ? in_vidac :
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
    .cfg_ip0    (1'b1),             // Начинать с 0000:0100h
    .reset_n    (locked & RESET_N),
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
    .page       (videopage),
    .cursor     (cursor),
    .font_a     (font_a),
    .font_q     (font_q),
    .video_a    (video_a),
    .video_q    (video_q),
    .dac_a      (dac_av),
    .dac_q      (dac_qv),
    .vretrace   (vretrace)
);

vidac VIDAC
(
    .clock      (clock_25),
    .reset_n    (locked),
    .cmd        (vidac_cmd),
    .page       (vidac_page),
    // Видеопамять
    .a          (vidac_a),
    .i          (vidac_a[17] ? vidac_i : in_video),
    .o          (vidac_o),
    .w          (vidac_w),
    .bsy        (vidac_bsy),
    // Текстура
    .tx         (vidac_tx),
    .ty         (vidac_ty),
    .td         (vidac_td)
);

// Клавиатура
// ---------------------------------------------------------------------

ps2 KBD
(
    .clock      (clock_25),
    .ps_clock   (PS2_CLK),
    .ps_data    (PS2_DAT),
    .done       (kb_done),
    .data       (kb_data)
);

// Память
// ---------------------------------------------------------------------

// 64K основной памяти
mem_main M0
(
    .clock      (clock_100),
    .a          (address[15:0]),
    .q          (in_main),
    .d          (out),
    .w          (we && we_main)
);

// 128K видеопамяти
// Если работает VIDAC, то память недоступна для чтения и записи
mem_video M1
(
    .clock      (clock_100),
    .a          (vidac_bsy ? vidac_a[16:0]  : address[16:0]),
    .d          (vidac_bsy ? vidac_o        : out),
    .q          (in_video),
    .w          (we && we_video || (vidac_w && !vidac_a[17])),
    .ax         (video_a),
    .qx         (video_q)
);

// 64K видеопамять VIDAC
mem_vidac M2
(
    .clock      (clock_100),
    .a          (address[15:0]),
    .q          (in_vidac),
    .d          (out),
    .w          (we && we_vidac),
    .ax         (vidac_a[15:0]),
    .qx         (vidac_i),
    .dx         (vidac_o),
    .wx         (vidac_w && vidac_a[17])
);

// 32K текстурная память 256x128
mem_texture M3
(
    .clock      (clock_100),
    .a          (address[14:0]),
    .q          (in_texture),
    .d          (out),
    .w          (we && we_texture),
    .ax         ({vidac_ty[6:0], vidac_tx[7:0]}),
    .qx         (vidac_td)
);

// 4K шрифты
mem_font M4
(
    .clock      (clock_100),
    .a          (address[11:0]),
    .q          (in_font),
    .d          (out),
    .w          (we && we_font),
    .ax         (font_a),
    .qx         (font_q)
);

// 1K Палитра
mem_dac M5
(
    .clock      (clock_100),
    .a          (dac_a),
    .d          (dac_d),
    .w          (dac_w),
    .q          (dac_q),
    .ax         (dac_av),
    .qx         (dac_qv),
);

// Управление портами и IRQ
// ---------------------------------------------------------------------

always @(posedge clock_25)
if (locked == 0 || RESET_N == 0) begin

    cursor          <= 0;
    cursor_start    <= 14;
    cursor_end      <= 15;

end else begin

    dac_w       <= 0;
    vidac_cmd   <= 0;

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
    16'h0020: begin irq_pend <= 0; end // EOI
    16'h00A0: begin end // IRQMASK

    // Выбор видеостраницы, запрос на VIDAC
    16'h0300: begin vidac_cmd <= 1; vidac_page <= port_o[0]; end
    16'h03C0: begin videopage <= port_o[0]; end

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
    16'h03D8: begin videomode <= port_o[1]; end
    endcase

    // Чтение из портов
    // -----------------------------------------------------------------
    if (port_r)
    case (port_a)
    16'h0060: begin port_i <= kbd_dat; end
    16'h0061: begin port_i <= kbd_hit; kbd_hit <= 0; end
    16'h0300: begin port_i <= {vidac_page, vidac_bsy}; end
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
`include "../video.v"
`include "../vidac.v"
`include "../ps2.v"
