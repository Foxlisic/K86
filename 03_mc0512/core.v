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
    pr <= 0;

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

        ip <= ipn;

        casex (in)
        // Разбор префиксов
        8'b001x_x110: begin preip <= preip + 1; _overs <= {in[4:3], 1'b1}; end
        8'b1111_001x: begin preip <= preip + 1; _rep   <= in[1:0]; end
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

            // Проверить прерывание
            // ip <= ipx;


            // Назначить сегмент по умолчанию
            case (_overs[2:1])
            ES: seg <= es; CS: seg <= cs;
            SS: seg <= ss; DS: seg <= ds;
            endcase

            // Наличие байта modrm у инструкции
            casex (in)
            8'b1000_xxxx, 8'b1100_000x, 8'b1100_01xx, 8'b0110_001x,
            8'b1101_00xx, 8'b1111_x11x, 8'b1101_1xxx, 8'b0110_10x1,
            8'b00xx_x0xx: ta <= MODRM;
            endcase

            // Обработка и подготовка инструкции
            casex (in)
            // HLT, CMC, CLC, STC, CLI, STI, CLD, STD
            8'b1111_0100: begin ta <= LOAD; ip <= ipx; end
            8'b1111_0101: begin ta <= LOAD; flag[CF] <= ~flag[CF]; end
            8'b1111_100x: begin ta <= LOAD; flag[CF] <= in[0]; end
            8'b1111_101x: begin ta <= LOAD; flag[IF] <= in[0]; end
            8'b1111_110x: begin ta <= LOAD; flag[DF] <= in[0]; end
            // CBW, CWD
            8'b1001_1000: begin ta <= LOAD; ax[15:8] <= {8{ax[7]}}; end
            8'b1001_1001: begin ta <= LOAD; dx <= {16{ax[15]}}; end
            // [06,0E,16,1E] PUSH [es,cs,ss,ds]
            8'b000x_x110: begin

                ta <= PUSH;

                case (in[4:3])
                ES: wb <= es; CS: wb <= cs;
                SS: wb <= ss; DS: wb <= ds;
                endcase

            end
            // [27,2F,37,3F] DAA, DAS, AAA, AAS
            8'b0010_x111: begin ta <= LOAD; ax[7:0] <= daa_r; flag <= daa_f; end
            8'b0011_x111: begin ta <= LOAD; ax      <= aaa_r; flag <= aaa_f; end
            // [40..4F] INC, DEC
            8'b0100_xxxx: begin

                op1  <= r20;
                op2  <= 1;
                alu  <= in[3] ? SUB : ADD;
                dir  <= 1;
                size <= 1;
                modrm[5:3] <= in[2:0];

            end
            // [60..67] PUSH r
            8'b0101_0xxx: begin

                ta <= PUSH;
                wb <= r20;

            end
            // [07,17,1F,58-5F,9D] POP
            // 6T [58..5F] POP r
            8'b000x_0111, // POP es,ss
            8'b0001_1111, // POP ds
            8'b1001_1101, // POPF
            8'b1100_101x, // RETF
            8'b1100_1111, // IRET
            8'b0101_1xxx: begin // POP r

                ta <= POP;
                tb <= RUN;
                {dir, size} <= 2'b11;
                modrm[5:3] <= in[2:0];

            end
            // [70..7F] IF [xxx] THEN
            8'b0111_xxxx: begin

                // Условие не совпадает, пропуск инструкции
                if (branches[in[3:1]] == in[0]) begin

                    ta <= LOAD;
                    ip <= ip + 2;

                end

            end
            // [80..83] GRP#1
            8'b1000_00xx: begin dir <= 0; end
            // [84..85] TEST rmr
            8'b1000_010x: begin alu <= AND; end
            // [88..89] MOV rm,r
            8'b1000_100x: begin cpen <= 0; end
            // [8D] LEA r, rm
            8'b1000_1101: begin cpen <= 0; dir <= 1; end
            // [8C, 8E] MOV s,rm|rm,s
            8'b1000_11x0: begin size <= 1; end
            // [8F] POP rm
            8'b1000_1111: begin dir <= 0; ta <= POP; tb <= RUN; end
            // [90..97] XCHG ax, r
            8'b1001_0xxx: begin

                ta <= WB;               // К записи в регистры
                wb <= ax;               // Записать предыдущее значение AX
                ax <= r20;              // В r20 всегда 16-битное значение
                {dir, size} <= 2'b11;   // DIR=1, SIZE=1
                modrm[5:3] <= in[2:0];  // Номер регистра для записи

            end
            // [9B] FWAIT
            8'b1001_1011: begin ta <= LOAD; end
            // [9C] PUSHF
            8'b1001_1100: begin ta <= PUSH; wb <= flag; end
            // [9E..9F] SAHF, LAHF
            8'b1001_1110: begin ta <= LOAD; flag     <= ax[15:8]; end
            8'b1001_1111: begin ta <= LOAD; ax[15:8] <= flag[7:0] | 2; end
            // [C2..C3] RET, RET i
            8'b1100_001x: begin ta <= POP; tb <= RUN; end
            // [C4..C5] LES|LDS r,m
            8'b1100_010x: begin ta <= MODRM; {size, dir} <= 2'b11; end
            // [C6..C7] MOV rm, i
            8'b1100_011x: begin dir <= 0; cpen <= 0; end
            // INT 1,3; INTO
            8'b1111_0001: begin ta <= INTR; intr <= 1; end
            8'b1100_1100: begin ta <= INTR; intr <= 3; end
            8'b1100_1110: begin ta <= flag[OF] ? INTR : LOAD; intr <= 4; end
            // [D0..D3] Rotate
            8'b1101_00xx: begin dir <= 0; end
            // [D6] SALC
            8'b1101_0110: begin ta <= LOAD; ax[ 7:0] <= {8{flag[CF]}}; end
            // [D7] XLATB
            8'b1101_0111: begin ea <= bx + ax[7:0]; cp <= 1; end
            // [E3] JCXZ b8
            8'b1110_0011: begin if (cx) begin ta <= LOAD; ip <= ip + 2; end end
            // [E0..E3] LOOP[NZ|Z] b8
            8'b1110_00xx: begin

                // Если CX=1 то в любом случае не переходить по метке
                // Если это LOOPZ, LOOPNZ, то ZF != bit[0] тоже не переходит
                if ((cx == 1) || (!in[1] && (in[0] ^ flag[ZF])))
                begin ta <= LOAD; ip <= ip + 2; end

                cx <= cx - 1;

            end
            endcase

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

        // 2T [70..7F] Jxxx b8
        // 2T [E0..E3] LOOPxx
        // 2T [EB xx] JMP b8
        8'b0111_xxxx, // J[ccc]
        8'b1110_00xx, // LOOP, JCXZ
        8'b1110_1011: begin // JMP b8

            ip <= ipsign;
            ta <= LOAD;

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

        // 3T+ [88..8B] MOV rmr
        8'b1000_10xx: begin

            ta <= WB;
            tb <= LOAD;
            wb <= op2;

        end

        // 3T+ [84..85] TEST rm, r
        8'b1000_010x: begin

            ta   <= LOAD;
            flag <= alu_flag;

        end

        // 6T+ [86..87] XCHG r, rm
        8'b1000_011x: case (m)

            // Начала пишется r -> rm
            0: begin

                m   <= 1;
                ta  <= WB;
                tb  <= RUN;
                dir <= 0;
                op1 <= op2;
                wb  <= op1;

            end

            // Потом пишется rm -> r
            1: begin

                ta  <= WB;
                tb  <= LOAD;
                dir <= 1;
                wb  <= op1;

            end


        endcase

        // 4T+ [8C] MOV rm16, sreg
        8'b1000_1100: begin

            ta <= WB;

            case (modrm[4:3])
            ES: wb <= es; CS: wb <= cs;
            SS: wb <= ss; DS: wb <= ds;
            endcase

        end

        // 4T+ [8D] LEA r16, rm
        8'b1000_1101: begin

            ta <= WB;
            wb <= ea;

        end

        // 3T+ [8E] MOV sreg, rm
        8'b1000_1110: begin

            ta <= LOAD;
            cp <= 0;

            case (modrm[4:3])
            ES: es <= op2;
            SS: ss <= op2;
            DS: ds <= op2;
            endcase

        end

        // [8F] POP rm
        8'b1000_1111: case (m)

            // Читать адрес ModRM
            0: begin

                m    <= 1;
                ta   <= MODRM;
                tb   <= RUN;
                cpen <= 0;

            end

            // Писать результат в память или регистр
            1: begin

                ta  <= WB;
                tb  <= LOAD;
                cp  <= 1;

            end

        endcase

        // 7T [9A] CALL far
        8'b1001_1010: case (m)

            0: begin m  <= 1;   ip <= ipn; op1[ 7:0] <= in; end
            1: begin m  <= 2;   ip <= ipn; op1[15:8] <= in; end
            2: begin m  <= 3;   ip <= ipn; op2[ 7:0] <= in; end
            3: begin m  <= 4;   ip <= ipn; op2[15:8] <= in; ta <= PUSH; tb <= RUN; wb <= cs; end
            4: begin m  <= 5;   ta <= PUSH; wb <= ip; end
            5: begin ip <= op1; ta <= LOAD; cs <= op2; end

        endcase

        // 5T [9D] POPF
        8'b10011101: begin

            ta   <= LOAD;
            flag <= wb | 2;

        end

        // 4*T [A0..A3] MOV a, [m]
        // 4*T [A2..A3] MOV [m], a
        8'b1010_00xx: case (m)

            // Читать младший байт адреса
            0: begin

                m  <= 1;
                ip <= ipn;
                ea <= in;

            end

            // Читать старший байт адреса
            // WRITE: пишется AL
            1: begin

                m   <= 2;
                cp  <= 1;
                we  <= dir;
                out <= ax[7:0];
                ip  <= ipn;
                ea[15:8] <= in;

            end

            // READ:  Читать в AL (READ)
            // WRITE: Пишется AH в память
            2: begin

                m   <= 3;
                cp  <= size;
                we  <= size & dir;
                ea  <= ean;
                ta  <= size ? RUN : LOAD;
                out <= ax[15:8];

                if (!dir) ax[7:0] <= in;

            end

            // READ: Читать AH
            3: begin

                ta <= LOAD;
                cp <= 0;

                if (!dir) ax[15:8] <= in;

            end

        endcase

        // 7T+ [A4] MOVSx
        8'b1010_010x: case (m)

            // Загрузка 8 или 16 бит DS:SI
            0: begin cp       <= 1;  m <= 1;            ea <= si; end
            1: begin wb[ 7:0] <= in; m <= size ? 2 : 3; ea <= ean; end
            2: begin wb[15:8] <= in; m <= 3; end

            // Запись 8 или 16 бит ES:DI
            3: begin

                m   <= size ? 4 : 5;
                we  <= 1;
                seg <= es;
                ea  <= di;
                out <= wb[7:0];

            end

            4: begin m <= 5; we <= 1; ea <= ean; out <= wb[15:8]; end

            // Инкремент или декремент SI
            5: begin

                ta   <= LOAD;
                m    <= 0;
                we   <= 0;
                cp   <= 0;
                si   <= flag[DF] ? si - (size + 1) : si + (size + 1);
                di   <= flag[DF] ? di - (size + 1) : di + (size + 1);
                size <= 1;

                // Если есть префикс REP: то повторяет пока CX не будет =0
                if (rep[1]) begin cx <= cx - 1; if (cx != 1) ip <= ips; end

            end

        endcase

        // 3*T [A8..A9] TEST a, i
        8'b1010_100x: case (m)

            // Прочесть операнды op1, op2 (byte)
            0: begin

                m   <= 1;
                alu <= AND;
                op1 <= size ? ax : ax[7:0];
                op2 <= in;
                ip  <= ipn;

            end
            // Либо запись результата 8 бит, либо читать старший байт
            1: begin

                m    <= 2;
                ta   <= size ? RUN : LOAD;
                ip   <= size ? ipn : ip;
                flag <= alu_flag;

                op2[15:8] <= in;

            end
            // Запись результата 16 бит
            2: begin

                ta   <= LOAD;
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

        // 8T+ [C4..C5] LES|LDS r,m
        8'b1100_010x: case (m)

            0: begin

                m  <= 1;
                ea <= ea + 2;

            end
            1: begin m <= 2; wb[7:0] <= in; ea <= ean; end
            2: begin

                ta <= WB;
                wb <= op2;

                if (opcode[0])
                     ds <= {in, wb[7:0]};
                else es <= {in, wb[7:0]};

            end

        endcase

        // 5T+ [C6..C7] MOV rm, i
        8'b1100_011x: case (m)

            0: begin m <= 1; cp <= 0; end
            1: begin m <= 2; ip <= ipn; wb <= in; ta <= size ? RUN : WB; end
            2: begin ip <= ipn; wb[15:8] <= in; ta <= WB; end

        endcase

        // 9T [CA..CB] RETF; RETF i16
        8'b1100_101x: case (m)

            0: begin ta <= POP;  m <= 1;   op1 <= wb; op2 <= in; ip <= ipn; end
            1: begin ta <= LOAD; cs <= wb; ip <= op1; if (!opcode[0]) sp <= sp + {in, op2[7:0]}; end

        endcase

        // 13T [CD] INT i8
        8'b1100_1101: begin

            ta   <= INTR;
            intr <= in;
            ip   <= ipn;

        end

        // 13T [CF] IRET
        8'b1100_1111: case (m)

            0: begin m  <= 1; ta <= POP; ip <= wb; end
            1: begin m  <= 2; ta <= POP; cs <= wb; end
            2: begin ta <= LOAD; flag <= wb[11:0] | 2; end

        endcase

        // [C0..C1; D0..D3] Сдвиги
        8'b1100_000x,
        8'b1101_00xx: case (m)

            // Если тут был указатель на память, то сбросить его
            0: if (cp && !opcode[4]) cp <= 0;
            // Выбор второго операнда
            else begin

                m   <= 1;
                alu <= modrm[5:3];

                if (opcode[4])
                     begin op2 <= (opcode[1] ? cx[3:0] : 1); end
                else begin op2 <= in[3:0]; ip <= ipn; end

            end

            // Процедура сдвига на 0..15 шагов
            1: begin

                if (op2) begin op1 <= rot_r; flag <= rot_f; end
                else     begin wb  <= op1;   ta <= WB; end

                op2 <= op2 - 1;

            end

        endcase

        // [D4] AAM
        8'b1101_0100: case (m)

            0: begin ta <= DIV;  op1 <= ax[7:0]; op2 <= in; tb <= RUN; m <= mn; end
            1: begin ta <= LOAD; ax  <= {op1[7:0], divr[7:0]}; end

        endcase

        // 2T [D5] AAD
        8'b1101_0101: begin

            ta <= LOAD;
            ax[7:0] <= ax[7:0] + in*ax[15:8];

        end

        // 2T [D7] XLATB
        8'b1101_0111: begin ta <= LOAD; ax[7:0] <= in; cp <= 0; end

        // 6T [E8] CALL b16
        8'b1110_1000: case (m)

            0: begin m  <= 1; ea <= in; ip <= ipn; end
            1: begin ta <= PUSH; wb <= ipn; ip <= ipn + {in, ea[7:0]}; end

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

    endcase

    // Запись результата
    // -------------------------------------------------------------------------
    WB: case (tm)

        0: begin

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

                tm  <= 1;
                we  <= 1;
                cp  <= 1;
                out <= wb[7:0];

            end

        end

        // Запись старшего байта или выход
        1:  begin

            ta  <= size ? ta : tb;
            tm  <= size ? 2 : 0;
            we  <= size;
            cp  <= size;
            out <= wb[15:8];
            ea  <= ean;

        end

        // Возврат из процедуры записи результат
        2: begin

            ea <= ea - 1;
            ta <= tb;
            tm <= 0;
            cp <= 0;

        end

    endcase

    // Запись в стек
    // -------------------------------------------------------------------------
    PUSH: case (tm)

        0: begin

            tm  <= 1;
            we  <= 1;
            segold <= seg;
            seg <= ss;
            ea  <= sp - 2;
            sp  <= sp - 2;
            out <= wb[7:0];
            cp  <= 1;

        end

        1: begin

            tm  <= 2;
            we  <= 1;
            ea  <= ean;
            out <= wb[15:8];

        end

        2: begin

            ta  <= tb;
            tm  <= 0;
            cp  <= 0;
            seg <= segold;

        end

    endcase

    // Чтение из стека
    // -------------------------------------------------------------------------
    POP: case (tm)

        0: begin

            tm  <= 1;
            cp  <= 1;
            seg <= ss;
            ea  <= sp;
            sp  <= sp + 2;
            segold <= seg;

        end

        1: begin

            tm <= 2;
            wb <= in;
            ea <= ean;

        end

        2: begin

            ta  <= tb;
            tm  <= 0;
            cp  <= 0;
            seg <= segold;
            wb[15:8] <= in;

        end

    endcase

    // Прерывание INT
    // -------------------------------------------------------------
    INTR: case (m)

        // Запись IP:CS:FLAGS
        0:  begin m <= mn; ea <= sp-6; we <= 1; out <= ip[ 7:0]; seg <= ss; cp <= 1; end
        1:  begin m <= mn; ea <= ean;  we <= 1; out <= ip[15:8]; sp  <= ea; end
        2:  begin m <= mn; ea <= ean;  we <= 1; out <= cs[ 7:0]; end
        3:  begin m <= mn; ea <= ean;  we <= 1; out <= cs[15:8]; end
        4:  begin m <= mn; ea <= ean;  we <= 1; out <= flag[ 7:0]; end
        5:  begin m <= mn; ea <= ean;  we <= 1; out <= flag[11:8]; end
        // Чтение нового адреса из IVT
        6:  begin m <= mn; ea <= {intr, 2'b00}; seg <= 0; cp <= 1; end
        7:  begin m <= mn; ea <= ean; ip[ 7:0] <= in; end
        8:  begin m <= mn; ea <= ean; ip[15:8] <= in; end
        9:  begin m <= mn; ea <= ean; cs[ 7:0] <= in; end
        10: begin m <= 0;  ea <= ean; cs[15:8] <= in; cp <= 0; ta <= LOAD; flag[IF] <= 1'b0; end

    endcase

    // Деление op1 / op2; size => divr (остаток), op1 (результат)
    DIV: case (tm)

        0: begin tm <= 1; divc <= size ? 16 : 8; divr <= 0; end
        1: begin

            op1  <= {op1[14:0], divr_bit};
            divc <= divc - 1;
            divr <= divr_next - (divr_bit ? op2 : 0);

            if (divc == 1) begin ta <= tb; tm <= 0; end

        end

    endcase

    endcase

end

endmodule
