// 8088
module core
(
    input               clock,
    input               ce,
    input               reset_n,
    // Память
    output      [19:0]  address,
    input       [ 7:0]  in,         // Чтение и из памяти или порта
    output reg  [ 7:0]  out,        // Запись в память или порт
    output reg          we,
    // Порты
    output reg          pr,         // Сигнал чтения из порта
    output reg          pw          // Сигнал записи в порт
);

`include "core_decl.v"

// ЛОГИКА РАБОТЫ ПРОЦЕССОРА
// -----------------------------------------------------------------------------

always @(posedge clock)
// Процесс сброса
if (reset_n == 1'b0) begin

    cp <= 0;
    ta <= 0;

    // F000:FFF0
    ip <= 16'h0000;
    cs <= 16'h0000;

    _overs <= {DS, 1'b0};
    _rep   <= 2'b00;
    preip  <= 0;

// Процессор должен быть активирован
end else if (ce) begin

    we <= 0;
    pr <= 0;
    pw <= 0;

    case (ta)

    // Загрузка опкода и выполнение простых инструкции
    // -------------------------------------------------------------------------
    LOAD: begin

        ip <= ip + 1;

        casex (in)
        // Разбор префиксов
        8'b001x_x110: begin preip <= preip + 1; _overs <= {in[4:3], 1'b1}; end
        8'b1111_101x: begin preip <= preip + 1; _rep   <= in[1:0]; end
        8'b0110_01xx,
        8'b1111_0000: begin preip <= preip + 1; end
        // Выполнить опкод
        default: begin

            // Метки по умолчанию
            ta      <= RUN;
            tb      <= LOAD;
            tm      <= 0;
            m       <= 0;
            cpen    <= 1;

            // Место реального старта инструкции с учетом префиксов
            ips     <= ipx;

            // Защелкнуть регистры для дальнейшего использования
            opcode  <= in;
            overs   <= _overs;
            rep     <= _rep;
            ea      <= 0;
            preip   <= 0;
            modrm   <= 0;
            _overs  <= {DS, 1'b0};
            _rep    <= 2'b00;
            dir     <= in[1];
            size    <= in[0];
            alu     <= in[5:3];

            // Назначить сегмент по умолчанию
            case (_overs[2:1])
            ES: seg <= es; CS: seg <= cs;
            SS: seg <= ss; DS: seg <= ds;
            endcase

            // Обработка и подготовка инструкции
            casex (in)
            // HLT, CMC, CLC, STC, CLI, STI, CLD, STD
            8'b1111_0100: begin ta <= LOAD; ip <= ipx; end
            8'b1111_0101: begin ta <= LOAD; flag[CF] <= ~flag[CF]; end
            8'b1111_100x: begin ta <= LOAD; flag[CF] <= in[0]; end
            8'b1111_101x: begin ta <= LOAD; flag[IF] <= in[0]; end
            8'b1111_110x: begin ta <= LOAD; flag[DF] <= in[0]; end
            // 4T [06,0E,16,1E] PUSH [es,cs,ss,ds]
            8'b000x_x110: begin

                ta <= PUSH;

                case (in[4:3])
                ES: wb <= es; CS: wb <= cs;
                SS: wb <= ss; DS: wb <= ds;
                endcase

            end
            // 1T [27,2F,37,3F] DAA, DAS, AAA, AAS
            8'b0010_x111: begin ta <= LOAD; ax[7:0] <= daa_r; flag <= daa_f; end
            8'b0011_x111: begin ta <= LOAD; ax      <= aaa_r; flag <= aaa_f; end
            // 3T [40..4F] INC, DEC
            8'b0100_xxxx: begin

                op1  <= r20;
                op2  <= 1;
                alu  <= in[3] ? SUB : ADD;
                dir  <= 1;
                size <= 1;
                modrm[5:3] <= in[2:0];

            end
            // 4T [60..67] PUSH r
            8'b0101_0xxx: begin

                ta <= PUSH;
                wb <= r20;

            end
            // 5T [07,17,1F] POP [es,ss,ds]
            // 6T [58..5F] POP r
            8'b000x_0111,
            8'b0001_1111,
            8'b0101_1xxx: begin

                ta <= POP;
                tb <= RUN;
                {dir, size} <= 2'b11;
                modrm[5:3] <= in[2:0];

            end
            // 1T [70..7F] IF [xxx] THEN
            8'b0111_xxxx: begin

                // Условие не совпадает, пропуск инструкции
                if (branches[in[3:1]] == in[0]) begin

                    ta <= LOAD;
                    ip <= ip + 2;

                end

            end
            // #T [80..83] GRP#1
            8'b1000_00xx: begin dir <= 0; end
            // 2T [90..97] XCHG ax, r
            8'b1001_0xxx: begin

                ta <= WB;               // К записи в регистры
                wb <= ax;               // Записать предыдущее значение AX
                ax <= r20;              // В r20 всегда 16-битное значение
                {dir, size} <= 2'b11;   // DIR=1, SIZE=1
                modrm[5:3] <= in[2:0];  // Номер регистра для записи

            end
            // C3 RET, C2 RET i
            8'b1100_001x: begin ta <= POP; tb <= RUN; end
            endcase

            // Наличие байта modrm у инструкции
            casex (in)
            8'b1000_xxxx, 8'b1100_000x, 8'b1100_01xx, 8'b0110_001x,
            8'b1101_00xx, 8'b1111_x11x, 8'b1101_1xxx, 8'b0110_10x1,
            8'b00xx_x0xx: ta <= MODRM;
            endcase

            // @TODO Прерывание

        end
        endcase

    end

    // Разбор ModRM
    // -------------------------------------------------------------------------
    MODRM: case (tm)

        // Базовый разбор
        0: begin

            modrm <= in;
            op1   <= dir ? r53 : r20;
            op2   <= dir ? r20 : r53;
            ip    <= ipn;

            // Подготовка эффективного адреса
            case (in[2:0])
            3'b000: ea <= bx + si;
            3'b001: ea <= bx + di;
            3'b010: ea <= bp + si;
            3'b011: ea <= bp + di;
            3'b100: ea <= si;
            3'b101: ea <= di;
            3'b110: ea <= in[7:6] == 2'b00 ? 0 : bp; // disp16 | bp
            3'b111: ea <= bx;
            endcase

            // Выбор сегмента SS: для BP
            if (!overs[0])
            casex (in)
            8'bxx_xxx_01x, // [bp+si|di]
            8'b01_xxx_110, // [bp+d8|d16]
            8'b10_xxx_110: seg <= ss;
            endcase

            // Дочитать смещения, если требуется, либо операнды
            casex (in)
            // +disp16
            8'b00_xxx_110,
            8'b10_xxx_xxx: begin tm <= 2; end
            // Читать операнд из памяти
            8'b00_xxx_xxx: begin tm <= cpen ? 4 : 0; cp <= cpen; if (!cpen) ta <= RUN; end
            8'b11_xxx_xxx: begin tm <= 0; ta <= RUN; end // Регистры
            default:       begin tm <= 1; end // +disp8
            endcase

        end

        // 8 битный signed char
        1: begin

            tm <= 4;
            ip <= ipn;
            ea <= ea + signex;
            cp <= cpen;

            if (!cpen) begin tm <= 0; ta <= RUN; end

        end

        // 16 битный unsigned int16
        2: begin tm <= 3; ip <= ipn; ea <= ea + in; end
        3: begin

            tm <= cpen ? 4 : 0;
            ta <= cpen ? MODRM : RUN;
            ip <= ipn;
            cp <= cpen;
            ea <= ea + {in, 8'h00};

        end

        // Операнд 8 bit
        4: begin

            if (dir) op2 <= in; else op1 <= in;

            tm <= size ? 5 : 0;
            ea <= ea + size;
            ta <= size ? MODRM : RUN;

        end

        // Операнд 16 bit
        5: begin

            if (dir) op2[15:8] <= in; else op1[15:8] <= in;

            tm <= 0;
            ta <= RUN;
            ea <= ea - 1;

        end

    endcase

    // Исполнение инструкции
    // -------------------------------------------------------------------------
    RUN: casex (opcode)

        // ALU modrm
        8'b00xx_x0xx: begin

            ta   <= (alu == CMP) ? LOAD : WB;
            wb   <= alu_res;
            flag <= alu_flag;

        end

        // 3..4T АЛУ a, i
        8'b00xx_x10x: case (m)

            // 8 bit
            0: begin

                op1 <= ax;
                op2 <= in;
                ip  <= ipn;
                m   <= size ? 1 : 2;

            end

            // 16 bit
            1: begin

                m  <= 2;
                ip <= ipn;
                op2[15:8] <= in;

            end

            // Запись резульата
            2: begin

                ta   <= LOAD;
                flag <= alu_flag;

                if (alu != CMP) ax <= (size ? alu_res[15:0] : {ax[15:8], alu_res[7:0]});

            end

        endcase

        // 5T [07,17,1F] POP [es,ss,ds]
        8'b000x_0111,
        8'b0001_1111: begin

            ta <= LOAD;

            case (opcode[4:3])
            ES: es <= wb;
            SS: ss <= wb;
            DS: ds <= wb;
            endcase

        end

        // 3T [40..4F] INC, DEC r
        8'b0100_xxxx: begin

            ta   <= WB;
            wb   <= alu_res;
            flag <= {alu_flag[11:1], flag[0]};

        end

        // 6T [58..5F] POP r
        8'b0101_1xxx: begin

            ta <= WB;
            tb <= LOAD;

        end

        // 5T+ [80..83] GRP#1
        8'b1000_00xx: case (m)

            0: begin

                m   <= 1;
                cp  <= 0;
                alu <= modrm[5:3];

            end
            1: begin

                op2 <= opcode[1:0] == 2'b11 ? signex : in;
                m   <= opcode[1:0] == 2'b01 ? 2 : 3;
                ip  <= ipn;

            end
            2: begin

                m   <= 3;
                ip  <= ipn;
                op2[15:8] <= in;

            end
            3: begin

                ta   <= alu == CMP ? LOAD : WB;
                tb   <= LOAD;
                wb   <= alu_res;
                flag <= alu_flag;

            end

        endcase

        // 3T [B0..B7] MOV r, i
        8'b1011_0xxx: begin

            ta   <= WB;
            ip   <= ipn;
            wb   <= in;
            size <= 0;
            dir  <= 1;
            modrm[5:3] <= opcode[2:0];

        end

        // 4T [B8..BF] MOV r, i
        8'b1011_1xxx: case (m)

            0: begin m <= 1; wb <= in; ip <= ipn; end
            1: begin

                ta   <= WB;
                ip   <= ipn;
                wb   <= {in, wb[7:0]};
                size <= 1;
                dir  <= 1;
                modrm[5:3] <= opcode[2:0];

            end

        endcase

        // 5T [C3] RET
        // 6T [C2] RET imm
        8'b1100_001x: case (m)

            // RET
            0: begin

                m  <= 1;
                ip <= opcode[0] ? wb : ipn;
                ta <= opcode[0] ? LOAD : RUN;
                op1[7:0] <= in;

            end

            // RET imm
            1: begin ip <= ipn; ip <= wb; sp <= sp + {in, op1[7:0]}; ta <= LOAD; end

        endcase

        // 3T [E9 xx xx] JMP b16
        8'b1110_1001: case (m)

            0: begin m <= 1; op1[7:0] <= in; ip <= ip + 1; end
            1: begin m <= 0; ip <= ipn + {in, op1[7:0]}; ta <= LOAD; end

        endcase

        // 5T [EA xx xx xx xx] JMP far
        8'b1110_1010: case (m)

            0: begin m <= 1; ip <= ipn; op1[ 7:0] <= in; ip <= ipn; end
            1: begin m <= 2; ip <= ipn; op1[15:8] <= in; ip <= ipn; end
            2: begin m <= 3; ip <= ipn; op2[ 7:0] <= in; ip <= ipn; end
            3: begin m <= 0; ip <= ipn; cs <= {in, op2[7:0]}; ip <= op1; ta <= LOAD; end

        endcase

        // 2T [70..7F] Jxxx b8
        // 2T [EB xx] JMP b8
        8'b0111_xxxx,
        8'b1110_1011: begin

            ip <= ipsign;
            ta <= LOAD;

        end

    endcase

    // Запись результата
    // -------------------------------------------------------------------------
    WB: begin

        // DIR=1, берем из M[5:3], иначе из M[2:0]
        if (dir || modrm[7:6] == 2'b11) begin

            ta <= tb;
            cp <= 0;

            case (dir ? modrm[5:3] : modrm[2:0])
            AX: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0];
            CX: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0];
            DX: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0];
            BX: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0];
            SP: if (size) sp <= wb; else ax[15:8] <= wb[7:0];
            BP: if (size) bp <= wb; else cx[15:8] <= wb[7:0];
            SI: if (size) si <= wb; else dx[15:8] <= wb[7:0];
            DI: if (size) di <= wb; else bx[15:8] <= wb[7:0];
            endcase

        end
        // Записать байт в память
        else begin

            ta  <= WB2;
            we  <= 1;
            cp  <= 1;
            out <= wb[7:0];

        end

    end

    // Запись старшего байта или выход
    WB2: begin

        ta  <= size ? WB3 : tb;
        we  <= size;
        cp  <= size;
        out <= wb[15:8];
        ea  <= ea + 1;

    end

    // Возврат из процедуры записи результат
    WB3: begin

        ea <= ea - 1;
        ta <= tb;
        cp <= 0;

    end

    // Запись в стек
    // -------------------------------------------------------------------------
    PUSH: begin

        ta  <= PUSH2;
        we  <= 1;
        seg <= ss;
        ea  <= sp - 2;
        sp  <= sp - 2;
        out <= wb[7:0];
        cp  <= 1;

    end
    PUSH2: begin

        ta  <= PUSH3;
        we  <= 1;
        ea  <= ea + 1;
        out <= wb[15:8];

    end
    PUSH3: begin

        ta <= tb;
        cp <= 0;

    end

    // Чтение из стека
    // -------------------------------------------------------------------------
    POP: begin

        ta  <= POP2;
        cp  <= 1;
        seg <= ss;
        ea  <= sp;
        sp  <= sp + 2;

    end
    POP2: begin

        ta <= POP3;
        wb <= in;
        ea <= ea + 1;

    end
    POP3: begin

        ta <= tb;
        cp <= 0;
        wb[15:8] <= in;

    end

    endcase

end

endmodule
