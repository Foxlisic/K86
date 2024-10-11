`timescale 10ns / 1ns
module tb;

// Тестбенчевые сигналы
// =============================================================================
reg reset_n;
reg clock_hi; always #0.5 clock_hi = ~clock_hi;
reg clock_25; always #2.0 clock_25 = ~clock_25;

initial begin

    $readmemh("tb.hex", memory, 9'h100);
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    clock_hi = 0;
    clock_25 = 0;
    reset_n  = 0;

    memory[20'h00000] = 8'hA4; memory[20'h00010] = 8'h03;
    memory[20'h00001] = 8'hDD; memory[20'h00011] = 8'hDE;
    memory[20'h00002] = 8'hEF; memory[20'h00012] = 8'h01;
    memory[20'h00003] = 8'hBA; memory[20'h00013] = 8'hBE;

    // JMP FAR 0000:0000
    memory[20'hFFFF0] = 8'hEA;
    memory[20'hFFFF1] = 8'h00;
    memory[20'hFFFF2] = 8'h01;
    memory[20'hFFFF3] = 8'h00;
    memory[20'hFFFF4] = 8'h00;

    #3.0  reset_n = 1;
    #2000 $finish;

end

// Контроллер блочной памяти
// =============================================================================

reg  [ 7:0] memory[1024*1024];
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;
wire [19:0] address;

always @(posedge clock_hi) begin in <= memory[address]; if (we) memory[address] <= out; end

// Описание подключения CPU
// =============================================================================

core CPU
(
    .clock      (clock_25),
    .ce         (1'b1),
    .cfg_ip0    (1'b1),
    .reset_n    (reset_n),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule
