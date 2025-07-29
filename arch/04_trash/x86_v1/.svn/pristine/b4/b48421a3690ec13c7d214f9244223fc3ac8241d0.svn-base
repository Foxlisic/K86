`timescale 10ns / 1ns
module tb;

// -------------------------------------------------------------------------
reg clock;
reg clock_25;
reg clock_50;

always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #2.0 clock_25 = ~clock_25;

initial begin clock = 0; clock_25 = 0; clock_50 = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("mem.hex", memory); end

// Драйвер памяти
// -------------------------------------------------------------------------

reg  [ 7:0] memory[1048576];
wire [19:0] address;
reg  [ 7:0] din;
wire [ 7:0] dout;
wire        we;

always @(posedge clock) begin
    
    din <= memory[address];
    if (we) memory[address] <= dout;
    
end

// Процессор
// -------------------------------------------------------------------------

cpu86 CPU86Unit
(
    .clock      (clock_25),
    .reset_n    (1'b1),
    .locked     (1'b1),
    .address    (address),
    .din        (din),
    .dout       (dout),
    .we         (we)
);

endmodule
