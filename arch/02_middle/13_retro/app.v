`timescale 10ns / 1ns
module tb;

/*
 * 8088 ПЛИС ПРОЦЕССОРНЫЙ МОДУЛЬ
 */

// ---------------------------------------------------------------------
reg         clock, clock_25, reset_n;
always #0.5 clock       = ~clock;
always #2.0 clock_25    = ~clock_25;
// ---------------------------------------------------------------------
initial begin reset_n = 0; clock = 0; clock_25 = 0; #3.0 reset_n = 1; #2500 $finish; end
initial begin $dumpfile("app.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------

reg  [ 7:0] ram[1048576];
wire [19:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;

// 4096 ROM BASIC I/O SYSTEM :: 20'hFF000
initial $readmemh("boot.hex", ram, 20'hFFFF0);

// Формируется логика чтения и записи в память
always @(posedge clock)
begin

    in <= ram[address];
    if (we) ram[address] <= out;

end

// ---------------------------------------------------------------------
// Подключение процессора
// ---------------------------------------------------------------------

k8088 AMDK62
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .chipen     (1'b1),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule
