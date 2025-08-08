always @(posedge clock)
// Сброс процессора
if (reset_n == 1'b0) begin

    cs      <= 16'hF000;
    ip      <= 16'h0000;
    col     <= M_init;
    flags   <= 12'h000;

end
// Процессор работает
else if (locked)
case (col)

// ==================================
// ЗАПУСК ИНСТРУКЦИИ
// ==================================

M_init:
begin

    col         <= M_exec;      // Запуск разбора инструкции
    row         <= 1'b0;        // Сброс счетчика процедуры
    tick        <= 1'b0;        // Номер тика в M_exec
    we          <= 1'b0;        // Сброс записи в память
    rep         <= 2'b00;       // Префикс REP
    opcode      <= din;         // Сохранение опкода
    segment     <= ds;          // Сегмент по умолчанию DS:
    override    <= 1'b0;        // Если =1, то сегмент префиксирован
    cursor      <= 1'b0;        // Эффективный адрес в 0
    bitsize     <= 1'b0;        // Битность (=1 16 bit)
    dirmode     <= 1'b0;        // Направление операндов

end

// ==================================
// Работа инструкции
// ==================================

M_exec:
casex (opcode)

    // Сегментные префиксы
    8'h26: begin opcode <= din; ip <= ip + 1; override <= 1'b1; segment <= es; end
    8'h2E: begin opcode <= din; ip <= ip + 1; override <= 1'b1; segment <= cs; end
    8'h36: begin opcode <= din; ip <= ip + 1; override <= 1'b1; segment <= ss; end
    8'h3E: begin opcode <= din; ip <= ip + 1; override <= 1'b1; segment <= ds; end

    // REPNZ, REPZ
    8'hF2, 8'hF3: begin opcode <= din; ip <= ip + 1; rep <= opcode[1:0]; end

    // Неиспользуемые префиксы
    8'h64, 8'h65, 8'h66, 8'h67, 8'hF0, 8'h9B: begin opcode <= din; ip <= ip + 1; end

    // ALU modrm
    8'b00_xxx_0xx: case (tick)

        0: begin // Считывание операндов из modrm

            tick    <= 1;
            col     <= M_modrm;
            alumode <= opcode[5:3];
            dirmode <= opcode[1];
            bitsize <= opcode[0];

        end
        1: begin // Запись операндов в память или регистр

            tick    <= 2;
            flags   <= flags_o;

            // Если инструкция не CMP, то записать результат
            if (alumode < 7)
                 begin col <= M_wbm;  wb  <= result; end
            else begin col <= M_init; bus <= 0; end

        end
        2: begin // Завершение инструкции

            col <= M_init;
            bus <= 0;

        end

    endcase

endcase

// ==================================
// РАЗБОР БАЙТА MODRM
// ==================================

M_modrm:
case (row)

// Получение регистров и указателей на память
0: begin

    modrm <= din;
    ip    <= ip + 1;

    // Выбор регистра для op1
    case (dirmode ? din[5:3] : din[2:0])

        0: op1 <= bitsize ? ax : ax[ 7:0];
        1: op1 <= bitsize ? cx : cx[ 7:0];
        2: op1 <= bitsize ? dx : dx[ 7:0];
        3: op1 <= bitsize ? bx : bx[ 7:0];
        4: op1 <= bitsize ? sp : ax[15:8];
        5: op1 <= bitsize ? bp : cx[15:8];
        6: op1 <= bitsize ? si : dx[15:8];
        7: op1 <= bitsize ? di : bx[15:8];

    endcase

    // Выбор регистра для op2
    case (dirmode ? din[2:0] : din[5:3])

        0: op2 <= bitsize ? ax : ax[ 7:0];
        1: op2 <= bitsize ? cx : cx[ 7:0];
        2: op2 <= bitsize ? dx : dx[ 7:0];
        3: op2 <= bitsize ? bx : bx[ 7:0];
        4: op2 <= bitsize ? sp : ax[15:8];
        5: op2 <= bitsize ? bp : cx[15:8];
        6: op2 <= bitsize ? si : dx[15:8];
        7: op2 <= bitsize ? di : bx[15:8];

    endcase

    // Раскодирование R/M части
    case (din[2:0])

        3'b000: cursor <= bx + si;
        3'b001: cursor <= bx + di;
        3'b010: cursor <= bp + si;
        3'b011: cursor <= bp + di;
        3'b100: cursor <= si;
        3'b101: cursor <= di;
        3'b110: cursor <= din[7:6] ? bp : 0;
        3'b111: cursor <= bx;

    endcase

    // Выбор режима (mod) работы
    casex (din)

        8'b00_xxx_110: begin row <= 1; end           // 16 битное смещение
        8'b00_xxx_xxx: begin row <= 4; bus <= 1; end // Чтение операнда
        8'b01_xxx_xxx: begin row <= 3; end           // 8 битное смещение
        8'b10_xxx_xxx: begin row <= 1; end           // 16 битное смещение
        8'b11_xxx_xxx: begin col <= M_exec; end      // Выбран регистр из r/m

    endcase

    // Сегмент не перегружен префиксом, а также выполняется условие, где есть [bp]
    if ((override == 1'b0) && ((din[2:0] == 3'b110 && din[7:6]) || (din[2:1] == 2'b01)))
        segment <= ss;

end

// Считывание 16-битного disp
1: begin row <= 2; ip <= ip + 1; cursor       <= cursor       + din; end
2: begin row <= 4; ip <= ip + 1; cursor[15:8] <= cursor[15:8] + din; bus <= 1; end

// Считывание 8-битного disp
3: begin row <= 4; ip <= ip + 1; cursor <= cursor + {{8{din[7]}}, din[7:0]}; bus <= 1; end

// Чтение операнда (8 бит) из памяти
4: begin

    if (dirmode) op2 <= din; else op1 <= din;
    if (bitsize) begin row <= 5; cursor <= cursor + 1; end
    else         begin row <= 0; col    <= M_exec;     end

end

// Чтение операнда (16 бит) из памяти
5: begin

    if (dirmode) op2[15:8] <= din; else op1[15:8] <= din;

    row     <= 0;
    col     <= M_exec;
    cursor  <= cursor - 1;

end

endcase

// ==================================
// Запись обратно в память или регистр [dirmode, bitsize, modrm, wb]
// * dirmode  (1 запись `wb` в регистр modrm[5:3])
//            (0 запись в память ea)
// * bitsize  (0/1)
// * wb       (8/16)
// ==================================

M_wbm:
case (row)

// Запись [7:0] в память или регистр
0: begin

    // Запись результата в регистр
    if (dirmode || (modrm[7:6] == 2'b11)) begin

        case (dirmode ? modrm[5:3] : modrm[2:0])

            0: if (bitsize) ax <= wb; else ax[ 7:0] <= wb[7:0];
            1: if (bitsize) cx <= wb; else cx[ 7:0] <= wb[7:0];
            2: if (bitsize) dx <= wb; else dx[ 7:0] <= wb[7:0];
            3: if (bitsize) bx <= wb; else bx[ 7:0] <= wb[7:0];
            4: if (bitsize) sp <= wb; else ax[15:8] <= wb[7:0];
            5: if (bitsize) bp <= wb; else cx[15:8] <= wb[7:0];
            6: if (bitsize) si <= wb; else dx[15:8] <= wb[7:0];
            7: if (bitsize) di <= wb; else bx[15:8] <= wb[7:0];

        endcase

        col <= M_exec;

    end
    // Запись [7:0] в память
    else begin

        row  <= 1;
        we   <= 1'b1;
        dout <= wb[7:0];

    end

end

// Запись [15:8], либо завершение записи 8 бит
1: begin

    if (bitsize) begin

        row    <= 2;
        dout   <= wb[15:8];
        cursor <= cursor + 1;

    end
    else begin

        col  <= M_exec;
        row  <= 0;
        we   <= 1'b0;

    end

end

// Завершение записи 16 бит
2: begin

    col    <= M_exec;
    row    <= 0;
    we     <= 1'b0;
    cursor <= cursor - 1;

end

endcase

endcase
