module k8088
(
    input                clock,         // 25 Мгц
    input                reset_n,       // Сброс процессора (=0)
    input                chipen,        // Активация (=1)
    output      [19:0]   address,       // Считываемый адрес
    input       [ 7:0]   in,            // Входящие данные
    output reg  [ 7:0]   out,           // Исходящие данные
    output reg           we             // Запись в память
);

// Выбор источника памяти в данный момент
assign address = cp ? {seg, 4'h0} + ea : {cs, 4'h0} + ip;

// Подключение объявлений, АЛУ и т.д.
`include "k8088_loc.v"
`include "k8088_alu.v"
`include "k8088_decl.v"

// Исполняемая синхронная логика
always @(posedge clock)
if (reset_n == 1'b0) begin

    cs <= 16'hFFFF;
    ip <= 16'h0000;
    t  <= LOAD;

end else if (chipen) begin

    we <= 1'b0;

    case (t)
    `include "k8088_fetch.v"
    `include "k8088_instr.v"
    endcase

end

endmodule
