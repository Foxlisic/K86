`timescale 10ns / 1ns
module tb;
// ---------------------------------------------------------------------
reg         clock, clock25, reset_n;
always #0.5 clock       = ~clock;
always #2.0 clock25     = ~clock25;
// ---------------------------------------------------------------------
initial begin reset_n = 0; clock = 0; clock25 = 0; #3.0 reset_n = 1; #10000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------
reg  [ 7:0] sdc[1024];
reg  [ 7:0] ram[512];
wire [ 8:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;
// ---------------------------------------------------------------------
initial begin $readmemh("sd.hex", sdc, 8'h00); end
// ---------------------------------------------------------------------
always @(posedge clock) begin in <= ram[address]; if (we) ram[address] <= out; end
// ---------------------------------------------------------------------
wire        mosi, cs, sclk;
reg         miso;
reg  [9:0]  c0 = 0;

// Эмулятор запросов к SPI
always @(posedge sclk) begin miso <= sdc[ c0[9:3] ][ ~c0[2:0] ]; c0 <= c0 + 1; end

sd SD
(
    .clock      (clock25),
    .reset_n    (reset_n),
    // ---
    .command    (1'b1),
    .rw         (1'b0),
    // ---
    .sclk       (sclk),
    .cs         (cs),
    .miso       (miso),
    .mosi       (mosi)
);

endmodule
