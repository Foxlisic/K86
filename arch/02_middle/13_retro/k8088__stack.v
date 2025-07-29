// POP sreg
8'b000x_x111: case (m)

    // Запрос чтения из стека
    0: begin

        m <= 1;
        t <= POP;

    end

    // Запись в регистр
    1: begin

        t <= LOAD;

        case (opcode[4:3])
        ES: es <= wb;
        SS: ss <= wb;
        DS: ds <= wb;
        endcase

    end

endcase

// POP r16
8'b0101_1xxx: case (m)

    // Запрос чтения из стека
    0: begin

        m <= 1;
        t <= POP;

    end

    // Запись в регистр
    1: begin

        t       <= WB;
        size    <= 1;
        dir     <= 1;
        cp      <= 0;
        `M53    <= `OPC20;

    end

endcase

// POP rm
8'b1000_1111: case (m)

    // Сначала извлечь из стека значение
    0: begin

        m   <= 1;
        t   <= POP;
        op1 <= seg;

    end

    // Потом прочитать ModRM
    1: begin

        m    <= 2;
        seg  <= op1;
        t    <= MODRM;
        skip <= 1;
        dir  <= 0;

    end

    // И записать результат
    2: begin

        t  <= WB;

    end

endcase

// CALL 16:16
8'b1001_1010: case (m)

    // Прочесть новый CS:IP
    0, 1, 2, 3: begin

        m   <= m + 1;
        ip  <= ip + 1;
        {op1, op2} <= {in, op1, op2[15:8]};

    end

    // Сохранить старый CS:IP в стек
    4, 5: begin

        m    <= m + 1;
        t    <= PUSH;
        next <= INSTR;
        wb   <= m[0] ? ip : cs;

    end

    // И перейти на новый адрес
    6: begin

        t  <= LOAD;
        cs <= op1;
        ip <= op2;

    end

endcase

// POPF
8'b1001_1101: case (m)

    // Запрос чтения
    0: begin

        m <= 1;
        t <= POP;

    end

    // Запись в flags
    1: begin

        t <= LOAD;
        flags <= (wb & 12'hFD5) | 2'b10;

    end

endcase

// RET i, RET
8'b1100_001x: case (m)

    // Значение из стека
    0: begin

        t   <= POP;
        m   <= opcode[0] ? 3 : 1;
        op1 <= 0;

    end

    // Imm16
    1, 2: begin

        m   <= m + 1;
        op1 <= {in, op1[15:8]};
        ip  <= ip + 1;

    end

    // RET [+u16]
    3: begin

        t  <= LOAD;
        ip <= wb;
        sp <= sp + op1;

    end

endcase
