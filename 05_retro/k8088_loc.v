// Объявление макро
`define MRM53 modrm[5:3]
`define MRM20 modrm[2:0]

// Этапы исполнения инструкции
localparam

    LOAD        = 0,        // Подготовка
    FETCH       = 1,        // Считывание префиксов и опкода
    INSTR       = 2,        // Исполнение инструкции
    MODRM       = 3,        // Чтение байта MODRM
    WB          = 4;        // Запись в память или регистр [MODRM]

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
    AND = 4, SUB = 5, XOR = 6, CMP = 7;
