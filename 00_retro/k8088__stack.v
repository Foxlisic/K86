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
