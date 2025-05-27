/**
 * 16 битное ядро 8086 упрощённое
 */

module cpu86
(
    input   wire        clock,
    input   wire        reset_n,    // =0 Сброс процессора
    input   wire        locked,     // =1 Процессор работает
    output  wire [19:0] address,    // Установленный адрес
    input   wire [ 7:0] din,        // Получаемые даннеы
    output  reg  [ 7:0] dout,       // Исходящие данные
    output  reg         we          // =1 Сигнал на запись
);

`include "cpu86.defines.v"
`include "cpu86.declare.v"
`include "cpu86.exec.v"
`include "cpu86.alu.v"

endmodule
