// Регистры общего назначения
// -----------------------------------------------------------------------------
reg [31:0]
    eax = 32'h0000_0000,
    ecx = 32'h0000_0000,
    edx = 32'h0000_0000,
    ebx = 32'h0000_0000,
    esp = 32'h0000_0000,
    ebp = 32'h0000_0000,
    esi = 32'h0000_0000,
    edi = 32'h0000_0000;

// Сегментные регистры
// -----------------------------------------------------------------------------
reg [15:0]
    es  = 16'h0000,
    cs  = 16'h0000,
    ss  = 16'h0000,
    ds  = 16'h0000,
    fs  = 16'h0000,
    gs  = 16'h0000;

// Специальные регистры
// -----------------------------------------------------------------------------
//                     ODIT SZ A  P C
reg [11:0] flags = 12'b0000_0000_0010;
reg [31:0] eip;

// Регистры по управлению состоянием процессора
// -----------------------------------------------------------------------------

reg         cp;                 // Выбранный адрес 1=SEGMENT:EFFECTIVE, 0=CS:EIP
reg [ 3:0]  t;                  // Номер этапа
reg [ 3:0]  s0;                 // - Номер стадии выполнения этапа
reg [15:0]  cseg;               // Текущий сегмент
reg [31:0]  ea;                 // Эффективный адрес
reg [ 8:0]  opcode;             // Сохраненный опкод
reg [ 7:0]  modrm, sib;         // Тип операндов
