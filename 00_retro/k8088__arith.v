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
            else      ax[ 7:0] <= alu_r[ 7:0];

        end

    end

endcase

// INC, DEC r16 [5T]
8'b0100_xxxx: case (m)

    // Запрос
    0: begin

        m       <= 1;
        size    <= 1;
        dir     <= 1;
        op1     <= op20;
        op2     <= 1;
        alu     <= opcode[3] ? SUB : ADD;

    end

    // Вычисление & Запись
    1: begin

        t       <= WB;
        wb      <= alu_r;
        flags   <= {alu_f[11:1], flags[CF]};
        `M53    <= `OPC20;

    end

endcase

// [GROUP:ALU] rm, i8
8'b1000_00xx: case (m)

    // Запрос операндов
    0: begin

        m   <= 1;
        dir <= 0;
        t   <= MODRM;

    end

    // Установка АЛУ
    1: begin

        m   <= 2;
        cp  <= 0;
        alu <= `M53;

    end

    // Чтение Immediate-8
    2: begin

        ip  <= ip + 1;
        m   <= opcode[1:0] == 2'b01 ? 3 : 4;
        op2 <= opcode[1:0] == 2'b11 ? signex : in;

    end

    // Чтение Immediate-16
    3: begin

        m  <= 4;
        ip <= ip + 1;
        op2[15:8] <= in;

    end

    // Запись результата
    4: begin

        wb      <= alu_r;
        flags   <= alu_f;
        cp      <= alu != CMP;
        t       <= alu == CMP ? LOAD : WB;

    end

endcase

// TEST rm, r
8'b1000_010x: case (m)

    0: begin

        t   <= MODRM;
        m   <= 1;
        alu <= AND;

    end

    1: begin

        t     <= LOAD;
        flags <= alu_f;

    end

endcase

// 4-5T TEST a, u
8'b1010_100x: case (m)

    // LO
    0: begin

        m   <= size ? 1 : 2;
        alu <= AND;
        op1 <= size ? ax : ax[7:0];
        op2 <= in;
        ip  <= ip + 1;

    end

    // HI
    1: begin

        m  <= 2;
        ip <= ip + 1;
        op1[15:8] <= in;

    end

    // Запись флагов
    2: begin

        t <= LOAD;
        flags <= alu_f;


    end

endcase

// [GROUP:SHIFT]
8'b1100_000x,
8'b1101_00xx: case (m)

    // Читать MODRM
    0: begin

        t   <= MODRM;
        m   <= 1;
        dir <= 0;

    end

    // Либо операнд CL или 1
    1: begin

        m   <= opcode[4] ? 3 : 2;
        cp  <= 0;
        op2 <= opcode[1] ? cx[7:0] : 1;
        alu <= `M53;

    end

    // Либо читать u8
    2: begin

        op2 <= in;
        m   <= 3;
        ip  <= ip + 1;

    end

    // Запись результата
    3: begin

        t  <= WB;
        wb <= wbr;

        flags[OF] <= 1'b0;
        flags[SF] <= wbr[size ? 15 : 7];
        flags[ZF] <= (size ? wbr : wbr[7:0]) == 0;
        flags[AF] <= 1'b0;
        flags[PF] <= ~^wbr[7:0];
        flags[CF] <= alu[0] ? (size ? shrw[0] : shrb[0]) : (size ? shlw[32] : shlb[16]);

    end

endcase
