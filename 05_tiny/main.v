`timescale 10ns / 1ns

module main;

// ---------------------------------------------------------------------

reg clk;
reg clock;

always #0.5 clk   = ~clk;
always #2.5 clock = ~clock;

initial begin clk = 1; clock = 0; #2000 $finish; end
initial begin $dumpfile("main.vcd"); $dumpvars(0, main); end

// ---------------------------------------------------------------------

reg [7:0] memory[1024*1024];
initial $readmemh("memory.hex", memory, 20'h00000);

// ---------------------------------------------------------------------

wire [19:0] pc;
reg  [47:0] instr;
reg  [15:0] data;
wire [19:0] address;
wire        store;
wire [15:0] write;

always @(posedge clk) begin

    // Считывание из памяти быстрокода
    instr <= {memory[pc+5], memory[pc+4], memory[pc+3], memory[pc+2], memory[pc+1], memory[pc]};
    data  <= {memory[address+1], memory[address]};
    
    if (store) {memory[address+1], memory[address]} <= write;

end

cpu TINY8086(clock, pc, instr, data, address, store, write);

endmodule
