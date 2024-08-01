`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 0; #3250 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

// Не инициализировать для Icarus Verilog
wire init_en = 0;

// CPU
wire kcpu; wire [31:0] A32; wire [ 7:0] Di; wire [ 7:0] Do; wire Dw; 

// SDRAM
wire [11:0] sdram_addr;
wire [ 1:0] sdram_bank;
wire [15:0] sdram_dq;
wire        sdram_ldqm;
wire        sdram_udqm;
wire        sdram_ras;
wire        sdram_cas;
wire        sdram_we;

// VGA
wire kvga; 
wire [9:0]  vgax; wire [9:0]  vgay;
wire [9:0]  vgad; wire        vgaw;

sdram SDRAM(

    /* Такты */
    init_en, clk, kcpu, kvga,
    
    /* Интерфейс */
    A32, Di, Do, Dw,
    
    /* Контроллер */
    sdram_addr, sdram_bank, sdram_dq,
    sdram_ldqm, sdram_udqm, 
    sdram_ras,  sdram_cas, sdram_we,
    
    /* VGA, sdram_dq[7:0] --> внутренняя память */
    vgax, vgay, vgad, vgaw
);

/* Эмуляция физического чипа SDRAM */
sdramphys EMULSDRAM(
    
    clk,
    sdram_addr, sdram_bank, sdram_dq,
    sdram_ldqm, sdram_udqm, 
    sdram_ras,  sdram_cas, sdram_we
);


// ---------------------------------------------------------------------

endmodule
