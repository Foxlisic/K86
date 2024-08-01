`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk; // 100 Mhz

initial begin clk = 1; #3250 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// 20 bit 2^20 = ...
reg [7:0] memory[ 1048576 ];

wire [19:0] address;
wire [ 7:0] data_out;
reg  [ 7:0] data_in;
reg  [ 7:0] data_tm;
reg  [ 1:0] div   = 2'b00; // (2 битный счетчик) 00 01 10 11
reg         clk25 = 1'b0;

// Инициализация. Из файла rom/rom.hex читается в регистры memory (8битные) с адреса 0
initial begin $readmemh("rom/rom.hex", memory, 20'h0000); end

// Тактовый делитель
always @(posedge clk) begin

    case (div)

        /* 0->1 */ 2'b00: {div, clk25} <= 3'b01_0;
        /* 1->2 */ 2'b01: {div, clk25} <= 3'b10_0;
        /* 2->3 */ 2'b10: {div, clk25} <= 3'b11_1;
        /* 3->0 */ 2'b11: {div, clk25} <= 3'b00_1;

    endcase

end

// Контроллер памяти
always @(posedge clk) begin

    // Запись в ЦПУ
    data_in <= data_tm;
    data_tm <= memory[ address ];

    // Из ЦПУ
    if (we) memory[ address ] <= data_out;

end

// ---------------------------------------------------------------------

cpu CPU(

    clk25,          // 25 Mhz | 100 Mhz
    address,        // 20 bit (1mb) 46 kb
    data_in,        // 8 bit данные из памяти
    data_out,       // 8 bit данные в память
    we              // write enable (=1) сигнал о том, что данные пишутся

);

endmodule
