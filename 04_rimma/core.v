/**
 * Ядро процессора 8086:DG
 */

module core
(
    input               clock,          // Тактовый генератор, внешний
    input               reset_n,        // Сброс процессора
    output      [19:0]  address,        // 1Mb
    input       [ 7:0]  in,             // Данные на чтение
    output  reg [ 7:0]  out,            // Данные на запись
    output  reg         we              // Разрешение записи
);

`include "core_decl.v"

endmodule
