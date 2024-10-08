`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------
reg clock;
reg clock25;

always #0.5 clock    = ~clock;
always #2.0 clock25  = ~clock25;

initial begin clock = 1; clock25 = 0; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end
// ---------------------------------------------------------------------

reg  [ 7:0] sram[1048576];  // 46 Kb
wire [19:0] address;        // 2^20 = 1Mb
wire [ 7:0] data_out;       // Данные, которые пойдут на запись
reg  [ 7:0] data_in;        // Данные для чтения из памяти
wire        write_ena;      // Сигнал на запись в память

always @(posedge clock) begin

    data_in <= sram[ address ];
    if (write_ena) sram[ address ] <= data_out;

end

// ---------------------------------------------------------------------

endmodule
