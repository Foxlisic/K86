/**
 * Процессорный кустарный модуль для разных экспериментов
 * @url http://ref.x86asm.net/
 */

module cpu
(
    input  wire         pin_ce,         // Chip Enabled
    input  wire         pin_clock,      // Clock

    // Ввод-вывод в память
    output wire [19:0]  pin_a,          // Address (Memory)
    input  wire [7:0]   pin_i,          // Input from RAM
    output reg  [7:0]   pin_o,          // Output to RAM
    output reg          pin_w           // Write Enable To RAM
);

endmodule
