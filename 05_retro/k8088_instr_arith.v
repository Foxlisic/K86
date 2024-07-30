// Базовые арифметико-логические инструкции
8'b00xx_x0xx: case (m)

    // Запрос операндов
    0: begin

        m   <= 1;
        t   <= MODRM;
        alu <= `OPC53;

    end

    // Запись ответа
    1: begin

        t     <= (alu == CMP) ? LOAD : WB;
        flags <= alu_f;
        wb    <= alu_r;

    end

endcase

// АЛУ + непосредственный операнд
8'b00xx_x10x: case (m)

    // LO байт
    0: begin

        ip  <= ip + 1;
        m   <= size ? 1 : 2;
        op1 <= size ? ax : ax[7:0];
        op2 <= in;
        alu <= `OPC53;

    end

    // HI байт
    1: begin

        ip  <= ip + 1;
        m   <= 2;
        op2[15:8] <= in;

    end

    // Запись
    2: begin

        t     <= LOAD;
        flags <= alu_f;

        if (alu != CMP) begin

            if (size) ax[15:0] <= alu_r[15:0];
            else      ax[ 7:0] <= alu_r[7:0];

        end

    end

endcase
