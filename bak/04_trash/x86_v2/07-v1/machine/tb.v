`timescale 10ns / 1ns

module tb;

// ---------------------------------------------------------------------
reg clock_25;
reg clock_50;
reg clock;
// ---------------------------------------------------------------------
always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #2.0 clock_25 = ~clock_25;
// ---------------------------------------------------------------------
initial begin clock = 0; clock_25 = 0; clock_50 = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); $readmemh("tb.hex", memory, 0); end
// ---------------------------------------------------------------------
reg [7:0] memory[65536];    // Общая память
// ---------------------------------------------------------------------

wire [ 7:0] data_out = memory[ address_ff ];
wire [31:0] address;        // 4Gb
reg  [15:0] address_ff;     // 64Kb, 46k + 64mb SDRAM / 16 bit
wire        we;             // Write Enabled
wire [ 7:0] data_in;        // То что запишется в память из процессора

always @(posedge clock) begin

    if (we) memory[address_ff] <= data_in;
    address_ff <= address[15:0];

end
// ---------------------------------------------------------------------

cpu CPU88
(
    .clock      (clock_25),
    .reset_n    (1'b1),
    .locked     (1'b1),
    .halt       (1'b0),
    // Обращение к памяти
    .address    (address),
    .i_data     (data_out),
    .o_data     (data_in),
    .we         (we)
);

endmodule
