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
    input   wire [3:0]  k4,
    output  wire [7:0]  hex,
    output  wire [3:0]  en7
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

adapter DSUBAdapter
(
    .CLOCK  (clock_25),
    .VGA_R  (vga_r[4:1]),
    .VGA_G  (vga_g[5:2]),
    .VGA_B  (vga_b[4:1]),
    .VGA_HS (vga_hs),
    .VGA_VS (vga_vs)
);

endmodule
