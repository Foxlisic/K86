module marsohod2
(
    input   wire        clk,
    output  wire [3:0]  led,
    input   wire [1:0]  keys,
    output  wire        adc_clock_20mhz,
    input   wire [7:0]  adc_input,
    output  wire        sdram_clock,
    output  wire [11:0] sdram_addr,
    output  wire [1:0]  sdram_bank,
    inout   wire [15:0] sdram_dq,
    output  wire        sdram_ldqm,
    output  wire        sdram_udqm,
    output  wire        sdram_ras,
    output  wire        sdram_cas,
    output  wire        sdram_we,
    output  wire [4:0]  vga_r,
    output  wire [5:0]  vga_g,
    output  wire [4:0]  vga_b,
    output  wire        vga_hs,
    output  wire        vga_vs,
    input   wire        ftdi_rx,
    output  wire        ftdi_tx,
    inout   wire [1:0]  usb0,
    inout   wire [1:0]  usb1,
    output  wire        sound_left,
    output  wire        sound_right,
    inout   wire        ps2_keyb_clk,
    inout   wire        ps2_keyb_dat,
    inout   wire        ps2_mouse_clk,
    inout   wire        ps2_mouse_dat
);

// Генерация частот
wire locked;
wire clock_25;

pll unit_pll
(
    .clk       (clk),
    .m25       (clock_25),
    .locked    (locked)
);

// -----------------------------------------------------------------------------

wire [19:0] address;
wire [ 7:0] o_data;
wire        we;

// Роутинг памяти 32+8=40 Kb
wire        ram_common = address < 20'h08000;
wire        ram_cga    = address > 20'hB8000 && address < 20'hBC000;

wire [ 7:0] i_data_common;
wire [ 7:0] i_data_cga;
wire [ 7:0] i_data = ram_cga ? i_data_cga : i_data_common;

cpu CPU16
(
    .clock      (clock_25),
    .reset_n    (keys[0]),
    .locked     (locked),

    // Физический интерфейс ввода-вывода
    .address    (address),
    .i_data     (i_data),
    .o_data     (o_data),
    .we         (we)
);

// -----------------------------------------------------------------------------

wire [12:0] cga_address;
wire [ 7:0] cga_data;

cga CGA
(
    .clock_25   (clock_25),

    // Интерфейс
    .R          (vga_r[4:1]), 
    .G          (vga_g[5:2]), 
    .B          (vga_b[4:1]),
    .HS         (vga_hs),
    .VS         (vga_vs),

    // Память
    .address    (cga_address),
    .data       (cga_data),
);

// Модули памяти
// -----------------------------------------------------------------------------

// Внутрисхемная память 32 Кб
mem UnitMem
(
    .clock     (clock),
    .address_a (address[14:0]),
    .q_a       (i_data_common),
    .data_a    (o_data),
    .wren_a    (we & ram_common)
);

// Память видеоадаптера 8 Кб
cga8k CGASTORE
(
    .clock      (clock),
    .address_a  (cga_address),
    .q_a        (cga_data),
    // Чтение и запись с процессора
    .address_b  (address[12:0]),
    .q_b        (i_data_cga),
    .data_b     (o_data),
    .wren_b     (we & ram_cga),
);

// -----------------------------------------------------------------------------

endmodule

`include "../cpu.v"
