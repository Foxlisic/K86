// ---------------------------------------------------------------------
// Исполнение микрокода
// ---------------------------------------------------------------------

INSTR: casex (opcode)

    // Базовые арифметико-логические инструкции
    8'b00xx_x0xx: case (m)

        // Запрос операндов
        0: begin

            m   <= 1;
            t   <= MODRM;
            alu <= opcode[5:3];

        end

        // Запись ответа
        1: begin

            t     <= (alu == CMP) ? LOAD : WB;
            flags <= alu_f;
            wb    <= alu_r;

        end

    endcase

    // JMP FAR xxxx:xxxx [6T]
    8'b1110_1010: case (m)

        // LO Offset
        0: begin

            m   <= 1;
            ip  <= ip + 1;
            ea[7:0]  <= in;

        end

        // HI Offset
        1: begin

            m   <= 2;
            ip  <= ip + 1;
            ea[15:8] <= in;

        end

        // LO Segment
        2: begin

            m   <= 3;
            ip  <= ip + 1;
            seg[7:0] <= in;

        end

        // IP Segment
        3: begin

            t  <= LOAD;
            m  <= 0;
            ip <= ea;
            cs <= {in, seg[7:0]};

        end

    endcase

endcase
