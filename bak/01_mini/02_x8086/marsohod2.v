module marsohod2(

    // CLOCK    100 Mhz
    input   wire        clk,

    // LED      4 
    output  wire [3:0]  led,

    // KEYS     2
    input   wire [1:0]  keys,

    // ADC      8 bit
    output  wire        adc_clock_20mhz,
    input   wire [7:0]  adc_input,

    // SDRAM
    output  wire        sdram_clock,
    output  wire [11:0] sdram_addr,
    output  wire [1:0]  sdram_bank,
    inout   wire [15:0] sdram_dq,
    output  wire        sdram_ldqm,
    output  wire        sdram_udqm,
    output  wire        sdram_ras,
    output  wire        sdram_cas,
    output  wire        sdram_we,

    // VGA
    output  wire [4:0]  vga_red,
    output  wire [5:0]  vga_green,
    output  wire [4:0]  vga_blue,
    output  wire        vga_hs,
    output  wire        vga_vs,

    // FTDI (PORT-B)
    input   wire        ftdi_rx,
    output  wire        ftdi_tx,

    // ----------------
    // Шилд расширения
    // ----------------

    // USB-A    2 pins
    inout   wire [1:0]  usb,

    // SOUND    2 channel
    output  wire        sound_left,
    output  wire        sound_right,

    // PS/2     keyb / mouse
    inout   wire [1:0]  ps2_keyb,
    inout   wire [1:0]  ps2_mouse   
);
// ---------------------------------------------------------------------

assign sound_left = clk;
assign sound_right = clock;
assign sdram_addr = o_addr;

wire locked;
wire clock;     // 10.00

wire        m_ready = 1'b1;     // @TODO Готовность памяти
wire [19:0] o_addr;
wire [15:0] o_data;
wire        o_wr;

// В зависимости от адреса
// $Cxxxx -- извлечение данных из ROM (32 кб + зеркало)
wire [15:0] i_data = o_addr[19:16] == 4'hC ? i_data_rom : 1'b0;

// Память BIOS
// ---------------------------------------------------------------------

// Задействован только $C0000-$C7FFF (BIOS)
wire [15:0] i_data_rom;

rom ROM(

    .clock (clk), 
    .addr_rd(o_addr[14:1]),  // 14+1 бит (32 кб)
    .q(i_data_rom)

);

// Генератор частоты 10 Mhz
// ---------------------------------------------------------------------
pll PLL(

    .clk        (clk),          // Входящие 100 Мгц
    .locked     (locked),       // 0 - устройство генератора ещё не сконфигурировано, 1 - готово и стабильно
    .clock      (clock)         // 10,0 Mhz    

    // добавить 25 Мгц
);

// Управляющий модуль SDRAM

// Видеоадаптер (текстовый режим)

// Клавиатура PS/2

// Звук

// Центральный процессор
// ---------------------------------------------------------------------
processor(

    .clock      (clock),
    .locked     (locked),
    
    .m_ready    (m_ready),
    .o_addr     (o_addr),
    .i_data     (i_data),
    .o_data     (o_data),
    .o_wr       (o_wr)
        
);

endmodule
