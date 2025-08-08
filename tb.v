`timescale 10ns / 1ns
module tb;
// -----------------------------------------------------------------------------
reg         clock, reset_n;
always #2.0 clock = ~clock;
// -----------------------------------------------------------------------------
initial begin reset_n = 0; clock = 0; #3.0 reset_n = 1; #2500 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); $readmemh("mem.hex", memory, 0); end
// -----------------------------------------------------------------------------
reg  [31:0] memory[1024*1024];
wire [31:0] a;
reg  [31:0] i;
wire [31:0] o;
wire        w;
// -----------------------------------------------------------------------------
always @(negedge clock)
begin
    if (w) memory[a[19:2]] <= o;
    #0.5 i <= memory[a[19:2]];      // Симуляция задержки получения данных
end
// -----------------------------------------------------------------------------
c32 C1
(
    .clock      (clock),
    .reset_n    (reset_n),
    .ce         (1'b1),
    .a          (a),
    .i          (i),
    .o          (o),
    .w          (w)
);
endmodule
