module marsohod2(

    /* ----------------
     * Archectural Marsohod2
     * ---------------- */

    // CLOCK    100 Mhz
    input   wire        clk,

    // LED      4
    output  reg  [3:0]  led,

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

    /* ----------------
     * Extension Shield
     * ---------------- */

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

assign sdram_addr = o_addr[11:0];

reg  [1:0] d25 = 1'b0;
always @(negedge clk) d25 <= d25 + 1'b1;

wire [19:0] o_addr;
wire [7:0]  o_data;
wire [7:0]  i_data;

mem_ram16k RAM16K(

    .clock   (clk),    
    // .addr_rd (o_addr[13:0]),
    // .q       (),
    .addr_wr (o_addr[13:0]),
    .data_wr (o_data),
    .wren    (o_write),
    .qw      (i_data)

);

// @TODO выполнить "прослойку" o_write -> память wren, важно

// Процессор. Просто процессор.
cpu CPU(

    d25[1],
    1'b0,
    o_addr,
    i_data,
    o_data,
    o_write

);

endmodule
