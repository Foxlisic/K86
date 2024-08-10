// Объявление макро
`define M53     modrm[5:3]
`define M20     modrm[2:0]
`define OPC53   opcode[5:3]
`define OPC20   opcode[2:0]

// Этапы исполнения инструкции
localparam

    LOAD        = 0,        // Подготовка
    FETCH       = 1,        // Считывание префиксов и опкода
    INSTR       = 2,        // Исполнение инструкции
    MODRM       = 3,        // Чтение байта MODRM
    WB          = 4,        // Запись в память или регистр [MODRM]
    PUSH        = 5,        // Запись WB в стек
    POP         = 6;        // Извлечь WB из стека

// Алиасы к регистрам
localparam

    AX = 0, CX = 1, DX = 2, BX = 3,
    SP = 4, BP = 5, SI = 6, DI = 7,
    ES = 0, CS = 1, SS = 2, DS = 3;

// Номера битов флагов
localparam

    CF = 0, PF = 2, AF = 4,  ZF = 6, SF = 7,
    TF = 8, IF = 9, DF = 10, OF = 11;

// АЛУ-операции
localparam

    ADD = 0, OR  = 1, ADC = 2, SBB = 3,
    AND = 4, SUB = 5, XOR = 6, CMP = 7,
    ROL = 0, ROR = 1, RCL = 2, RCR = 3,
    SHL = 4, SHR = 5, SAL = 6, SAR = 7;
