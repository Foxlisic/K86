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

    // BASE
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

    // VIDAC
    memory[20'hC0000] = 8'h06;

    memory[20'hC0001] = 8'hA0; memory[20'hC0002] = 8'h00; // x1
    memory[20'hC0003] = 8'h64; memory[20'hC0004] = 8'h00; // y1

    memory[20'hC0005] = 8'h04; memory[20'hC0006] = 8'h00; // x2
    memory[20'hC0007] = 8'h03; memory[20'hC0008] = 8'h00; // y2

    memory[20'hC0009] = 8'hAA; // color
    memory[20'hC000A] = 8'h00;

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
wire [17:0] vidac_a;
reg  [ 7:0] vidac_i;
wire [ 7:0] vidac_o;
wire        vidac_w;

always @(posedge clock_hi) begin

    in      <= memory[address];
    vidac_i <= memory[vidac_a + 20'hA0000];

    if (we) memory[address] <= out;
    if (vidac_w) memory[address] <= vidac_o;

end

// Описание подключения CPU
// =====================================================================

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

// Подключить VIDAC
// =====================================================================

vidac VIDAC
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .cmd        (1'b1),
    .page       (1'b0),
    .a          (vidac_a),
    .i          (vidac_i),
    .o          (vidac_o),
    .w          (vidac_w)
);

endmodule
