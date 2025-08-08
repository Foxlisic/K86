`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg  clk;
reg  clk25;

always #0.5 clk   = ~clk;
always #2.0 clk25 = ~clk25;

initial begin clk = 1; clk25 = 0; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

endmodule
