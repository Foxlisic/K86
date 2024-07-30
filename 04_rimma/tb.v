`timescale 10ns / 1ns

/*
 * Эмулятор DownGrade88
 */

module tb;

// ---------------------------------------------------------------------
reg clock, clock25, reset_n;

always #0.5 clock       = ~clock;
always #2.0 clock25     = ~clock25;

initial begin reset_n = '0; clock = '0; clock25 = '0; #2.5 reset_n = '1; #2500 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------

reg  [ 7:0] memory[1048576];
wire [19:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;

initial $readmemh("tb.hex", memory, '0);

// Формируется логика чтения и записи в память
always @(posedge clock) begin in <= memory[address]; if (we) memory[address] <= out; end

// ---------------------------------------------------------------------

core IntelCore9xxxTurbo
(
    .clock      (clock25),
    .reset_n    (reset_n),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule
