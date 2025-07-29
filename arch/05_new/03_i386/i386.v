`timescale 10ns / 1ns
module i386;

// Тестбенчевые сигналы
// =============================================================================
reg reset_n;
reg clock_hi; always #0.5 clock_hi = ~clock_hi;
reg clock_25; always #2.0 clock_25 = ~clock_25;

initial begin $dumpfile("i386.vcd"); $dumpvars(0, i386); $readmemh("i386.hex", ram, 16'h0100); end
initial begin clock_hi = 0; intr = 0; clock_25 = 0; reset_n = 0; #3.0 reset_n = 1; #8.0 intr = 1; #5000 $finish; end

// Контроллер блочной памяти
// =============================================================================

reg         intr;
reg  [ 7:0] ram[65536];
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;
wire [19:0] address;

always @(posedge clock_hi) begin in <= ram[address]; if (we) ram[address] <= out; end

// Подключить няшный процессор
// =============================================================================
core CORE
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce         (1'b1),
    .a          (address),
    .i          (in),
    .o          (out),
    .w          (we),
    .intr       (intr),
    .intn       (8'h03)
);

endmodule
