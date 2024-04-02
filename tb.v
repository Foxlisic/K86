`timescale 10ns / 1ns

/*
 * K86
 */

module tb;

// ---------------------------------------------------------------------
reg         clock, clock25, reset_n;

always #0.5 clock       = ~clock;
always #2.0 clock25     = ~clock25;

initial begin reset_n = '0; clock = '0; clock25 = '0; #3.0 reset_n = '1; #2500 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------

reg  [ 7:0] memory[1048576];
wire [19:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;

initial begin

    $readmemh("tb.hex", memory, 20'h0000);

    memory[20'hFFFF0] = 8'hEA; // Instinct
    memory[20'hFFFF1] = 8'h00; // Insult
    memory[20'hFFFF2] = 8'h00; // Infakct
    memory[20'hFFFF3] = 8'h00; // Megademo
    memory[20'hFFFF4] = 8'h00; // Party

end

// Формируется логика чтения и записи в память
always @(posedge clock) begin in <= memory[address]; if (we) memory[address] <= out; end

// ---------------------------------------------------------------------

K86 SephironTurboXCore
(
    .clock      (clock25),
    .ce         (1'b1),
    .reset_n    (reset_n),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule
