/**
 * МИКРОПРОЦЕССОР
 * Специально написан для использования в проекте Марсоход-2
 * Тактовая частота 25 мгц, стандарт
 */

module micro86
(
    input               clock,              // 25Мгц
    input               reset_n,            // =0 Сброс процессора
    input               ce,                 // =1 Активация чипа
    output      [19:0]  a,                  // Адрес в общей памяти
    input       [ 7:0]  i,                  // Данные из памяти
    output reg  [ 7:0]  o,                  // Данные в память
    output reg          w                   // Запись в память
);

assign a = cp ? {sgn,4'h0} + ea : {cs,4'h0} + ip;

`include "micro86_decl.v"
`include "micro86_regs.v"

always @(posedge clock)
// Сброс процессора
if (reset_n == 0) begin

    t    <= RUN;              // Исполнение инструкции начинается сразу
    m    <= 0;
    cp   <= 0;                // Установить на CS:IP
    cs   <= 0;
    ip   <= 0;
    ea   <= 0;
    sgn  <= 0;
    rep  <= 0;
    w    <= 0;
    term <= 1;
    over <= 0;

// Запуск выполнения команд процессора
end else if (ce) begin

    w <= 0;

    case (t)

    // -------------------------------------------------------------
    // ВЫПОЛНЕИЕ ИНСТРУКЦИИ
    // -------------------------------------------------------------
    RUN: begin

        // Защелкивание опкода на первом такте
        if (m == 0) begin

            // Сброс префиксов по достижении конца инструкции (на следующем такте)
            if (term) begin sgn <= ds; rep <= 2'b00; over <= 0; end

            m       <= 1;
            m1      <= 0;
            m2      <= 0;
            m3      <= 0;
            ip      <= ipn;
            next    <= RUN;
            term    <= 0;
            opcache <= i;
            dir     <= i[1];
            size    <= i[0];

        end

        casex (opcode)
        8'b00xxx0xx: case (m) // ### AL-операции с операндами ModRM [3T+]
        0: begin t <= MODRM; alu <= opcode[5:3]; end
        1: begin t <= alu == CMP ? RUN : WB; wb <= ar; flags <= af; `TERM end
        endcase
        8'b00xxx10x: case (m) // ### AL-операции AL/AX + imm [3/4T]
        0: begin alu <= opcode[5:3];        op1 <= i[0] ? ax : ax[7:0]; end
        1: begin ip <= ipn; m <= size?2:3;  op2 <= i; end
        2: begin ip <= ipn; m <= 3;         op2[15:8] <= i; end
        3: begin flags <= af; if (alu != CMP) ax <= size ? ar : {ax[15:8], ar[7:0]}; `TERM end
        endcase
        8'b000xx110: case (m) // ### PUSH es/cs/ss/ds [4T]
        0: begin t <= PUSH; case (i[4:3]) 0:wb<=es; 1:wb<=cs; 2:wb<=ss; 3:wb<=ds; endcase `TERM; end
        endcase
        8'b00001111: case (m) // ### ::Extended::
        0: begin end
        endcase
        8'b000xx111: case (m) // ### POP es/../ss/ds [5T]
        0: begin t <= POP; end
        1: begin case (opcode[4:3]) 0:es<=wb; 2:ss<=wb; 3:ds<=wb; endcase `TERM; end
        endcase
        8'b001xx110: case (m) // ### Префикс es/cs/ss/ds:
        0: begin over <= 1; case (i[4:3]) 0:sgn<=es; 1:sgn<=cs; 2:sgn<=ss; 3:sgn<=ds; endcase m <= 0; end
        endcase
        default: ip <= ip;    // $$$ НЕИЗВЕСТНАЯ ИНСТРУКЦИЯ
        endcase

    end

    // -------------------------------------------------------------
    // СЧИТЫВАНИЕ ОПЕРАНДОВ ИЗ РЕГИСТРОВ ИЛИ ИЗ ПАМЯТИ
    // -------------------------------------------------------------
    MODRM: case (m1)

        0: begin

            modrm   <= i;
            ip      <= ipn;

            // Читать регистры
            op1     <= dir ? i53 : i20;
            op2     <= dir ? i20 : i53;

            // Вычисление эффективного адреса
            case (i[2:0])
            3'b000: ea <= bx + si;
            3'b001: ea <= bx + di;
            3'b010: ea <= bp + si;
            3'b011: ea <= bp + di;
            3'b100: ea <= si;
            3'b101: ea <= di;
            3'b110: ea <= i[7:6] ? bp : 0;
            3'b111: ea <= bx;
            endcase

            // Роутинг
            casex (i)
            8'b00_xxx_110: begin m1 <= 2; end // DISP16
            8'b00_xxx_xxx: begin m1 <= 4; cp <= 1; end // Читать операнд
            8'b01_xxx_xxx: begin m1 <= 1; end // DISP8
            8'b10_xxx_xxx: begin m1 <= 2; end // DISP16
            8'b11_xxx_xxx: begin m1 <= 0; t <= RUN; end // Регистры. Вернуться к RUN
            endcase

            // Проставить сегмент SS: там где есть упоминания BP
            if (!over && ((^i[7:6] && i[2:0] == 3'b110) || i[2:1] == 2'b01)) sgn <= ss;

        end

        // DISP8
        1: begin m1 <= 4; ip <= ipn; ea <= ea + {{8{i[7]}}, i}; cp <= 1; end
        2: begin m1 <= 3; ip <= ipn; ea <= ea + {8'h00, i}; end
        3: begin m1 <= 4; ip <= ipn; ea <= ea + {i, 8'h00}; cp <= 1; end

        // Чтение 8-битный операнд
        4: begin

            if (dir) op2 <= i; else op1 <= i;
            if (size) begin m1 <= 5; ea <= ea + 1; end else begin m1 <= 0; t <= RUN; end

        end

        // Читать 16-битный операнд
        5: begin

            if (dir) op2[15:8] <= i; else op1[15:8] <= i;

            t  <= RUN;
            m1 <= 0;
            ea <= ea - 1;

        end

    endcase

    // -------------------------------------------------------------
    // [1T,2-3T] ЗАПИСЬ РЕЗУЛЬТАТОВ WB,DIR,SIZE,MODRM В ПАМЯТЬ/РЕГИСТРЫ
    // -------------------------------------------------------------
    WB: case (m2)

        // Записать в регистры, если это явно указано
        0: if (dir || modrm[7:6] == 2'b11) begin

            case (dir ? modrm[5:3] : modrm[2:0])
            0: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0];
            1: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0];
            2: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0];
            3: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0];
            4: if (size) sp <= wb; else ax[15:8] <= wb[7:0];
            5: if (size) bp <= wb; else cx[15:8] <= wb[7:0];
            6: if (size) si <= wb; else dx[15:8] <= wb[7:0];
            7: if (size) di <= wb; else bx[15:8] <= wb[7:0];
            endcase

            t  <= next;
            cp <= 0;

        // Либо в память (1 или 2 байта)
        end else begin

            w  <= 1;
            cp <= 1;
            m2 <= 1;
            o  <= wb[7:0];

        end

        // Запись в память, 2 байта
        1: begin

            w  <= size;
            cp <= size;
            t  <= size ? WB : next;
            ea <= ea + 1;
            m2 <= size ? 1 : 0;
            o  <= wb[15:8];
            size <= 0;

        end

    endcase

    // -------------------------------------------------------------
    // [3T] ВЫГРУЗКА WB -> В СТЕК
    // -------------------------------------------------------------
    PUSH: case (m3)
    0: begin m3 <= 1; ea <= sp - 2; w <= 1; o <= wb[7:0]; cp <= 1; sgn <= ss; sp <= sp - 2; end
    1: begin m3 <= 2; ea <= ea + 1; w <= 1; o <= wb[15:8]; end
    2: begin m3 <= 0; cp <= 0; t <= next; end
    endcase

    // -------------------------------------------------------------
    // [3T] ЗАГРУЗКА ИЗ СТЕКА -> WB
    // -------------------------------------------------------------
    POP: case (m3)
    0: begin m3 <= 1; cp <= 1; ea <= sp; sp <= sp + 2; sgn <= ss; cp <= 1; end
    1: begin m3 <= 2; wb <= i; ea <= ea + 1; end
    2: begin m3 <= 0; wb[15:8] <= i;  cp <= 0; t <= next; end
    endcase

    endcase

end

endmodule
