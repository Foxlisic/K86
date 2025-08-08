`timescale 10ns / 1ns
module tb;

// ---------------------------------------------------------------------
reg clock;
reg clock_25;
reg clock_50;

always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #2.0 clock_25 = ~clock_25;

initial begin clock = 0; clock_25 = 0; clock_50 = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------
initial begin $readmemh("tb.hex", memory, 0); end
// ---------------------------------------------------------------------

reg  [ 7:0]     memory[1024*1024];
wire [19:0]     address;    // 46 kb
reg  [ 7:0]     i_data;
wire [ 7:0]     o_data;
wire            we;         // =1 Write Enabled

always @(posedge clock) begin

    i_data <= memory[ address ];
    if (we) memory[ address ] <= o_data;

end

// ---------------------------------------------------------------------

cpu CPU16
(
    .clock      (clock_25),
    .reset_n    (1'b1),
    .locked     (1'b1),

    // Физический интерфейс ввода-вывода
    .address    (address),
    .i_data     (i_data),
    .o_data     (o_data),
    .we         (we)
);

endmodule
