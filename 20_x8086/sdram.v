// Модуль одновременно обрабатывает запрос по определенному адресу [addr]
// и адресу текущей инструкции IP, предоставляя постоянный кешированный
// адрес за наименьшее количество времени. Память также постоянно выполняет
// "перезаряд" и перезапись старых значений.

module sdram(

    // Адресация 2^23 = 8 Мб памяти SDRAM
    input   wire [22:0] addr,       // Address Pointer
    input   wire [22:0] ip,         // Instruction Pointer
    input   wire [15:0] i_data,
    output  wire [15:0] o_data,
    input   wire        we_req,     // Сигнал на запись (передний фронт)
    output  wire        ready,      // Готовность данных на выходе
    output  wire [47:0] o_cache,    // Кеш-линия для инструкции
    
    // Физический интерфейс памяти
    output  wire        cas,
    output  wire        ras,
    output  wire        we,
    output  wire [11:0] sdram_addr,
    output  wire [ 1:0] sdram_bank,
    output  wire [ 1:0] dqm,        // Data Query Mask (LDQM + HDQM)
    inout   wire [15:0] dq          // Data

);
