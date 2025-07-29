/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */
module core
(
    input               clock,      // Тактовая частота
    input               reset_n,    // =0 Сброс процессора
    input               ce,         // =1 Процессор активирован
    output      [19:0]  a,          // Адресная шина (20 бит)
    input       [ 7:0]  i,          // Входящие данные
    output reg  [ 7:0]  o,          // Исходящие данные
    output reg          w,          // Разрешение записи в память
    input               intr,       // Внешнее прерывание
    input       [ 7:0]  intn,       // Номер прерывания
    // -----------------------------------
    output  reg  [15:0] port_a,
    output  reg         port_w,
    output  reg         port_r,
    input        [ 7:0] port_i,
    output  reg  [ 7:0] port_o,
    // -----------------------------------
    output reg  [11:0]  flags,      // Флаги процессора
    output reg          halt,       // Признак остановки выполнения
    output              m0,         // =1 Выполняется 1-й такт инструкции
    output reg          ud          // =1 Неизвестный опкод
);

// Выбор источника памяти
assign a  = cp ? {sgn,4'h0} + ea : {cs,4'h0} + ip;
assign m0 = (t == 0 && r == INSTR);

// Для сокращение размера кода
`define M53  modrm[5:3]
`define TERM t <= 0; term <= 1;

// Макрос для записи 16-битного значения в регистр
`define W8  {dir, size} <= 2'b10; modrm[5:3]
`define W16 {dir, size} <= 2'b11; modrm[5:3]

localparam
    INSTR = 0, MODRM = 1, WB  = 2, PUSH = 3, POP = 4, INTERRUPT = 5, UNDEF = 6, DIV = 7,
    ADD   = 0, OR    = 1, ADC = 2, SBB  = 3, AND = 4, SUB       = 5, XOR   = 6, CMP = 7,
    ROL   = 0, ROR   = 1, RCL = 2, RCR  = 3, SHL = 4, SHR       = 5, SAL   = 6, SAR = 7,
    CF    = 0, PF    = 2, AF  = 4, ZF   = 6, SF  = 7, TF        = 8, IF    = 9, DF  = 10, OF = 11;

// Регистры; флаги [ODITSZ5A3P1C]
// -----------------------------------------------------------------------------
reg [15:0]  ax = 16'h032A, cx = 16'h0004, dx = 16'hBEEF, bx = 16'hBABA,
            sp = 16'h0000, bp = 16'h0000, si = 16'hDEAD, di = 16'h0000,
            es = 16'h0B80, cs = 16'h0000, ss = 16'h0000, ds = 16'h0000,
            fs = 16'h0000, gs = 16'h0000;
reg [15:0]  ip;

// Управляющие регистры
// -----------------------------------------------------------------------------

reg  [ 5:0] t, m;
reg  [ 2:0] r, next, mi;
reg  [ 7:0] opc, modrm, interrupt;
reg         cp, size, dir, cpen, cpm, intrack;
reg         term;
reg  [ 1:0] rep;
reg         over;
reg  [15:0] sgn, t16, ea, wb;
reg  [15:0] op1, op2;
reg  [ 3:0] alu;

// Исполнение кода процессора
// -----------------------------------------------------------------------------
always @(posedge clock)
if (reset_n == 0) begin

    r       <= INSTR;   // Процедура
    t       <= 0;       // Фаза исполнения опкода
    m       <= 0;       // Вторичная фаза
    mi      <= 0;       // Фаза Interrupt
    cp      <= 0;       // Текущий указатель на память
    ud      <= 0;
    halt    <= 0;
    intrack <= 0;
    sgn     <= ds;
    term    <= 0;
    over    <= 0;       // Стандартный сегмент
    rep     <= 0;       // Нет префикса REP:
    cpen    <= 0;
    flags   <= 12'b0000_0000_0011;
    cs      <= 0;
    ip      <= 16'h0100;

end
else if (ce) begin

    w <= 0;
    port_r <= 0;
    port_w <= 0;

    case (r)
    // -------------------------------------------------------------------------
    // Исполнение инструкции
    // -------------------------------------------------------------------------
    INSTR:
    // Вызов аппаратного внешнего прерывания
    if (flags[IF] && (intr ^ intrack) && (t == 0)) begin

        r           <= INTERRUPT;
        intrack     <= intr;
        interrupt   <= intn;

    end
    else begin

        // Завершение инструкции, но отстает на 1Т после выполнения
        if (term) begin {term, over, rep} <= 1'b0; sgn <= ds; end

        // Защелкнуть опкод
        if (t == 0) begin

            t    <= 1;
            opc  <= i;
            ip   <= ip + 1;
            cpen <= 1;
            cpm  <= 1;
            next <= INSTR;

            {alu, dir, size} <= {i[5:3], i[1:0]};

        end

        casex (opcode)

        // Сегментные префиксы
        8'b0010_0110: begin t <= 0; sgn <= es; end
        8'b0010_1110: begin t <= 0; sgn <= cs; end
        8'b0011_0110: begin t <= 0; sgn <= ss; end
        8'b0011_1110: begin t <= 0; sgn <= ds; end

        // 3*T CMP R/R -- Базовые инструкции АЛУ
        8'b00xx_x0xx: case (t)

            0: begin r <= MODRM; end
            1: begin r <= (alu == CMP ? INSTR : WB); wb <= alu_r; flags <= alu_f; `TERM; end

        endcase

        // 3*T ALU a,i
        8'b00xx_x10x: case (t)

            0: begin op1       <= i[0] ? ax : ax[7:0]; end
            1: begin op2       <= i; ip <= ip + 1; t <= size ? 2 : 3; end
            2: begin op2[15:8] <= i; ip <= ip + 1; t <= 3; end
            3: begin flags     <= alu_f; if (alu != CMP) ax <= size ? alu_r : {ax[15:8], alu_r[7:0]}; `TERM; end

        endcase

        // 4T PUSH es, cs, ss, ds
        8'b0000_0110: begin r <= PUSH; wb <= es; `TERM; end
        8'b0000_1110: begin r <= PUSH; wb <= cs; `TERM; end
        8'b0001_0110: begin r <= PUSH; wb <= ss; `TERM; end
        8'b0001_1110: begin r <= PUSH; wb <= ds; `TERM; end
        8'b0110_0100: begin r <= PUSH; wb <= fs; `TERM; end
        8'b0110_0101: begin r <= PUSH; wb <= gs; `TERM; end

        // 5T POP es, ss, ds
        8'b000x_x111: case (t)

            0: begin r <= POP; end
            1: begin case (opcode[4:3]) 0: es <= wb; 2: ss <= wb; 3: ds <= wb; endcase `TERM; end

        endcase

        // 1T DAA, DAS, AAA, AAS
        8'b001x_x111: begin 
        
            ax    <= opcode[4] ? aaa_r : daa_r; 
            flags <= opcode[4] ? aaa_f : daa_f; 
            `TERM; 

        end

        // 3T INC, DEC r16
        8'b0100_xxxx: case (t)

            // +1/-1, ALU=ADD|SUB, но IP здесь не менять
            0: begin

                op1 <= r16;
                op2 <= 1;
                alu <= opcode[3] ? SUB : ADD;
                {dir, size} <= 2'b11;

            end

            // Обновить флаги и запись регистра
            1: begin

                r       <= WB;
                wb      <= alu_r;
                `M53    <= opcode[2:0];
                flags   <= {alu_f[11:1], flags[CF]};
                `TERM;

            end

        endcase

        // 4T PUSH, POP r
        8'b0101_0xxx: begin r <= PUSH; wb <= r16; `TERM; end
        8'b0101_1xxx: begin r <= POP;  next <= WB; `W16 <= opcode[2:0]; `TERM; end

        // 17T PUSHA
        8'b0110_0000: case (t)

            0:  begin t <= tn; w <= 1; o <= di[ 7:0]; ea <= sp - 16; cp <= 1; sgn <= ss; end
            1:  begin t <= tn; w <= 1; o <= di[15:8]; ea <= ean; end
            2:  begin t <= tn; w <= 1; o <= si[ 7:0]; ea <= ean; end
            3:  begin t <= tn; w <= 1; o <= si[15:8]; ea <= ean; end
            4:  begin t <= tn; w <= 1; o <= bp[ 7:0]; ea <= ean; end
            5:  begin t <= tn; w <= 1; o <= bp[15:8]; ea <= ean; end
            6:  begin t <= tn; w <= 1; o <= sp[ 7:0]; ea <= ean; end
            7:  begin t <= tn; w <= 1; o <= sp[15:8]; ea <= ean; end
            8:  begin t <= tn; w <= 1; o <= bx[ 7:0]; ea <= ean; end
            9:  begin t <= tn; w <= 1; o <= bx[15:8]; ea <= ean; end
            10: begin t <= tn; w <= 1; o <= dx[ 7:0]; ea <= ean; end
            11: begin t <= tn; w <= 1; o <= dx[15:8]; ea <= ean; end
            12: begin t <= tn; w <= 1; o <= cx[ 7:0]; ea <= ean; end
            13: begin t <= tn; w <= 1; o <= cx[15:8]; ea <= ean; end
            14: begin t <= tn; w <= 1; o <= ax[ 7:0]; ea <= ean; end
            15: begin t <= tn; w <= 1; o <= ax[15:8]; ea <= ean; end
            16: begin cp <= 0; sp <= sp - 16; `TERM; end

        endcase

        // 17T POPA
        8'b0110_0001: case (t)

            0:  begin t <= tn; cp <= 1; ea <= sp; sgn <= ss; end
            1:  begin t <= tn; di[ 7:0] <= i; ea <= ean; end
            2:  begin t <= tn; di[15:8] <= i; ea <= ean; end
            3:  begin t <= tn; si[ 7:0] <= i; ea <= ean; end
            4:  begin t <= tn; si[15:8] <= i; ea <= ean; end
            5:  begin t <= tn; bp[ 7:0] <= i; ea <= ean; end
            6:  begin t <= tn; bp[15:8] <= i; ea <= ean; end
            7:  begin t <= tn; bx[ 7:0] <= i; ea <= ean; end
            8:  begin t <= tn; bx[15:8] <= i; ea <= ean; end
            9:  begin t <= tn; dx[ 7:0] <= i; ea <= ean; end
            10: begin t <= tn; dx[15:8] <= i; ea <= ean; end
            11: begin t <= tn; cx[ 7:0] <= i; ea <= ean; end
            12: begin t <= tn; cx[15:8] <= i; ea <= ean; end
            13: begin t <= tn; ax[ 7:0] <= i; ea <= ean; end
            14: begin cp <= 0; ax[15:8] <= i; sp <= sp + 16; `TERM; end

        endcase

        // 5*T PUSH iw :: ib
        8'b0110_10x0: case (t)

            1: begin ip <= ip + 1; wb <= signex; t <= 2; if (opcode[1]) begin r <= PUSH; `TERM; end end
            2: begin ip <= ip + 1; wb[15:8] <= i; r <= PUSH; `TERM; end

        endcase

        // IMUL r16,rm,s8/u16
        8'b0110_10x1: case (t)

            0: begin r <= MODRM; dir <= 1; cpm <= 0; end
            1: begin

                t       <= opcode[1] ? 3 : 2;
                ip      <= ip + 1;
                imulw   <= 1;
                op1     <= op2;
                op2     <= opcode[1] ? signex : i;

            end
            2: begin t <= tn; op2[15:8] <= i; ip <= ip + 1; end
            3: begin

                wb <= mult[15:0];
                r  <= WB;

                flags[ZF] <= multzf;
                flags[CF] <= multcf;
                flags[OF] <= multcf;

                `TERM;

            end

        endcase

        // 1*T Условные переходы
        8'b0111_xxxx: case (t)

            0: if (branch[i[3:1]] == i[0]) begin ip <= ip + 2; `TERM; end
            1: begin ip <= ip + 1 + signex; `TERM; end

        endcase

        // 5*T ALU GROUP
        8'b1000_00xx: case (t)

            0: begin r <= MODRM; dir <= 0; cpm <= 0; end
            1: begin

                ip  <= ip + 1;
                alu <= modrm[5:3];
                op2 <= opcode[1:0] == 3 ? signex : i;
                t   <= opcode[1:0] == 1 ? 2 : 3;

            end
            2: begin t <= 3; op2[15:8] <= i; ip <= ip + 1; end
            3: begin r <= (alu == CMP ? INSTR : WB); wb <= alu_r; flags <= alu_f; `TERM; end

        endcase

        // 3T+ TEST rm, r
        8'b1000_010x: case (t)

            0: begin r <= MODRM; alu <= AND; end
            1: begin flags <= alu_f; `TERM; end

        endcase

        // 6*T XCHG r,rm
        8'b1000_011x: case (t)

            0: begin r <= MODRM; end
            1: begin r <= WB; wb <= op2; t <= 2; end
            2: begin r <= WB; wb <= op1; dir <= 0; `TERM; end

        endcase

        // 4*T MOV rm,r|r,rm
        8'b1000_10xx: case (t)

            0: begin r <= MODRM; cpen <= i[1]; end
            1: begin r <= WB; wb <= op2; cp <= 1; `TERM; end

        endcase

        // MOV rm, sreg
        8'b1000_1100: case (t)

            0: begin r <= MODRM; cpen <= 0; {dir, size} <= 2'b01; end
            1: begin r <= WB; `TERM; case (modrm[5:3]) 0: wb <= es; 1: wb <= cs; 2: wb <= ss; 3: wb <= ds; endcase end

        endcase

        // 4T+ LEA r, rm
        8'b1000_1101: case (t)

            0: begin r <= MODRM; cpen <= 0; {dir, size} <= 2'b11; end
            1: begin r <= WB; wb <= ea; `TERM; end

        endcase

        // MOV sreg, rm
        8'b1000_1110: case (t)

            0: begin r <= MODRM; {dir, size} <= 2'b11; end
            1: begin case (modrm[5:3]) 0: es <= op2; 2: ss <= op2; 3: ds <= op2; endcase `TERM; end

        endcase

         // POP rm
        8'b1000_1111: case (t)

            0: begin r <= POP;   end
            1: begin r <= MODRM; t <= 2; cpen <= 0; dir <= 0; end
            2: begin r <= WB; cp <= 1; `TERM; end

        endcase

        // 2T XCHG ax, r; 1T NOP
        9'b1001_0000: begin `TERM; end
        9'b1001_0xxx: begin ax <= r16; wb <= ax; r <= WB; `W16 <= opcode[2:0]; `TERM; end

        // 1T CBW, CWD
        9'b1001_1000: begin ax <= {{8{ax[7]}}, ax[7:0]}; `TERM; end
        9'b1001_1001: begin dx <= {16{ax[15]}}; `TERM; end

        // 13T CALL FAR
        8'b1001_1010: case (t)

            0: begin next <= INSTR; end
            1: begin t <= 2; ip <= ip + 1; op1[ 7:0] <= i; end
            2: begin t <= 3; ip <= ip + 1; op1[15:8] <= i; end
            3: begin t <= 4; ip <= ip + 1; op2[ 7:0] <= i; end
            4: begin t <= 5; ip <= ip + 1; op2[15:8] <= i; r <= PUSH; wb <= cs; end
            5: begin t <= 6; wb <= ip;  r  <= PUSH; end
            6: begin `TERM;  ip <= op1; cs <= op2; end

        endcase

        // 1T FWAIT, LOCK
        8'b1001_1011,
        8'b1111_0000: begin `TERM; end

        // 4T PUSHF
        8'b1001_1100: begin r <= PUSH; wb <= flags; `TERM; end

        // 5T POPF
        8'b1001_1101: case (t)

            0: begin r <= POP; end
            1: begin flags <= wb | 2; `TERM; end

        endcase

        // 1T SAHF, LAHF
        8'b1001_1110: begin flags     <= ax[15:8]; `TERM; end
        8'b1001_1111: begin ax[15:8]  <= flags[7:0] | 2; `TERM; end

        // MOV a,[m] | [m],a
        8'b1010_00xx: case (t)

            // Прочесть адрес
            1: begin ea[ 7:0] <= i; ip <= ip + 1; t <= 2; end
            2: begin ea[15:8] <= i; ip <= ip + 1; t <= dir ? 3 : 6; cp <= 1; end

            // Запись A в память
            3: begin w <= 1; o <= ax[ 7:0]; t <= size ? 4 : 5; end
            4: begin w <= 1; o <= ax[15:8]; t <= 5; ea <= ean; end
            5: begin `TERM; cp <= 0; end

            // Чтение A из памяти
            6: begin t <= 7; ax[ 7:0] <= i; ea <= ean; if (!size) begin `TERM; cp <= 0; end end
            7: begin `TERM;  ax[15:8] <= i; cp <= 0; end

        endcase

        // 4*T TEST a, i
        8'b1010_100x: case (t)

            0: begin alu <= AND; op1 <= opcode[0] ? ax : ax[7:0]; end
            1: begin t <= size ? 2 : 3; op2 <= i; ip <= ip + 1; end
            2: begin t <= 3; op2[15:8] <= i; ip <= ip + 1; end
            3: begin flags <= alu_f; `TERM; end

        endcase

        // MOVSx :: 2*+4/2*CX
        8'b1010_010x: case (t)

            1: begin

                t   <= tn;
                cp  <= repa;
                op1 <= sgn;
                ea  <= si;

                if (!repa) begin `TERM; end

            end

            // Запись младшего байта [size=0]
            2: begin

                t   <= size ? 3 : 5;
                wb  <= i;
                o   <= i;

                if (size)  ea <= ea + 1;
                else begin ea <= di; sgn <= es; w <= 1; end

            end

            // Чтение старшего байта, запись младшего байта [size=1]
            3: begin

                t   <= tn;
                wb  <= i;
                w   <= 1;
                ea  <= di;
                o   <= wb[7:0];
                sgn <= es;

            end

            // Запись старшего байта
            4: begin t <= tn; ea <= ea + 1; w <= 1; o <= wb[7:0]; end

            // Инкремент или декремент SI/DI, выключение записи
            5: begin

                t   <= 2;
                sgn <= op1;
                ea  <= sinc;
                si  <= sinc;
                di  <= dinc;
                cx  <= cx - rep[1];

                if (!repb) begin `TERM; cp <= 0; end

            end

        endcase

        // CMPSx :: (3|5)*CX+2*
        8'b1010_011x: case (t)

            1: begin

                t   <= tn;
                cp  <= repa;
                ea  <= si;
                alu <= SUB;

                if (!repa) begin `TERM; end

            end

            // Чтение DS:SI
            2: begin

                t16 <= sgn;
                t   <= size ? 3 : 5;
                ea  <= size ? ea + 1 : di;
                sgn <= size ? sgn : es;
                op1 <= i;

            end

            // Старший байт из SI+1
            3: begin t <= 4; op1[15:8] <= i; sgn <= es; ea <= di; end

            // Чтение из ES:DI
            4: begin t <= size ? 5 : 6; op2 <= i; ea <= ea + 1; end
            5: begin t <= 6; op2[15:8] <= i; end

            // Сравнение и повтор цикла (если необходимо)
            6: begin

                t       <= 2;
                ea      <= sinc;
                si      <= sinc;
                di      <= dinc;
                flags   <= alu_f;
                sgn     <= t16;
                cx      <= cx - rep[1];

                if (!(repb && (rep[0] == alu_f[ZF]))) begin `TERM; cp <= 0; end

            end

        endcase

        // STOSx :: 3+(2/1)*CX
        8'b1010_101x: case (t)

            1: begin t <= tn; cp <= repa; if (!repa) begin `TERM; end end
            2: begin // STOSB

                t   <= size ? 3 : 2;
                o   <= ax[7:0];
                sgn <= es;
                ea  <= di;
                w   <= 1;
                di  <= flags[DF] ? di - 1 : di + 1;

                if (!size) begin cx <= cx - rep[1]; if (!repb) t <= 4; end

            end
            3: begin // STOSW

                t   <= repb ? 2 : 4;
                w   <= 1;
                ea  <= ea + 1;
                o   <= ax[15:8];
                di  <= flags[DF] ? di - 1 : di + 1;
                cx  <= cx - rep[1];

            end

            4: begin cp <= 0; `TERM; end

        endcase

        // LODSx :: 3*
        8'b1010_110x: case (t)

            1: begin

                t  <= tn;
                cp <= repa;
                ea <= flags[DF] ? si - repc : si + repc;

                if (!repa) begin `TERM; end

            end

            2: begin

                t       <= tn;
                ea      <= ea + 1;
                si      <= flags[DF] ? ea-1-size : ea+1+size;
                ax[7:0] <= i;

                if (!size) begin `TERM; end

            end

            3: begin ax[15:8] <= i; `TERM; cp <= 0; end

        endcase

        // SCASx :: 2*+(2|3)*CX
        8'b1010_111x: case (t)

            1: begin

                t   <= tn;
                cp  <= repa;
                ea  <= di;
                alu <= SUB;
                sgn <= es;

                if (!repa) begin `TERM; end

            end

            // Прочитать младший байт
            2: begin

                t   <= size ? 3 : 4;
                op1 <= size ? ax : ax[7:0];
                op2 <= i;
                ea  <= ea + 1;

            end

            // Прочитать старший байт
            3: begin t <= tn; op2[15:8] <= i; di <= dinc; end

            // Сравнить A со значением из памяти
            4: begin

                t       <= 2;
                flags   <= alu_f;
                di      <= dinc;
                ea      <= dinc;
                cx      <= cx - rep[1];

                if (!(repb && (rep[0] == alu_f[ZF]))) begin `TERM; cp <= 0; end

            end

        endcase

        // 3-4T MOV r,i
        8'b1011_xxxx: case (t)

            1: begin ip <= ip + 1; wb <= i; t <= 2; if (!opc[3]) begin r <= WB; `W8 <= opc[2:0]; `TERM; end end
            2: begin ip <= ip + 1; wb[15:8] <= i; r <= WB; `W16 <= opcode[2:0]; `TERM; end

        endcase

        // [ROT] rm, i
        8'b1100_000x: case (t)

            0: begin r <= MODRM; dir <= 0; cpm <= 0; end
            1: begin t <= tn; op2 <= i; ip <= ip + 1; alu <= modrm[5:3]; end
            2: begin r <= WB; wb <= barr; flags <= barf; `TERM; end

        endcase

        // 5T RET; 7T RET imm
        8'b1100_001x: case (t)

            0: begin r <= POP; t <= opcode[0] ? 3 : 1; t16 <= 0; end
            1: begin t <= tn; t16[ 7:0] <= i; ip <= ip + 1; end
            2: begin t <= tn; t16[15:8] <= i; end
            3: begin ip <= wb; sp <= sp + t16; `TERM; end

        endcase

        // LES|LDS r,m
        8'b1100_010x: case (t)

            0: begin r <= MODRM; {dir, size} <= 2'b11; end
            1: begin t <= 2; ea <= ea + 2; end
            2: begin t <= 3; ea <= ean; wb[7:0] <= i; end
            3: begin r <= WB; wb <= op2; if (opcode[0]) ds <= {i, wb[7:0]}; else es <= {i, wb[7:0]}; `TERM; end

        endcase

        // MOV rm, i
        8'b1100_011x: case (t)

            0: begin r <= MODRM; {cpm, cpen, dir} <= 0; end
            1: begin wb <= i; ip <= ip + 1; if (size) t <= 2; else begin r <= WB; `TERM; end end
            2: begin wb[15:8] <= i; ip <= ip + 1; r <= WB; `TERM; end

        endcase

        // RETF; RETF i16
        8'b1100_101x: case (t)

            0: begin r <= POP; end
            1: begin r <= POP; t  <= tn; op1 <= wb;  op2 <= i; ip <= ip + 1; end
            2: begin `TERM;    cs <= wb; ip  <= op1; if (!opcode[0]) sp <= sp + {i, op2[7:0]}; end

        endcase

        // INT 3; INTO
        8'b1100_11x0: case (t)

            0: begin r <= (i[1] && flags[OF]) || !i[1] ? INTERRUPT : INSTR; interrupt <= i[1] ? 4 : 3; `TERM; end

        endcase

        // INT i
        8'b1100_1101: case (t)

            1: begin r <= INTERRUPT; interrupt <= i; ip <= ip + 1; `TERM; end

        endcase

        // IRET
        8'b1100_1111: case (t)

            0: begin r <= POP; end
            1: begin r <= POP; t <= tn; ip <= wb; end
            2: begin r <= POP; t <= tn; cs <= wb; end
            3: begin `TERM; flags <= wb[11:0] | 2; end

        endcase

        // [ROT] rm, (1|cl)
        8'b1101_00xx: case (t)

            0: begin r <= MODRM; dir <= 0; end
            1: begin t <= tn; alu <= modrm[5:3]; op2 <= opcode[1] ? cx[7:0] : 1; end
            2: begin r <= WB; wb <= barr; flags <= barf; `TERM; end

        endcase

        // 1T SALC
        8'b1101_0110: begin ax[7:0] <= {8{flags[CF]}}; `TERM; end

        // XLATB
        8'b1101_0111: case (t)

            0: begin ea <= bx; cp <= 1; end
            1: begin ax[7:0] <= i; cp <= 0; `TERM; end

        endcase

        // FPU: Делает абсолютно ничего
        8'b1101_1xxx: case (t)

            0: begin r <= MODRM; {cpen, dir, size, cpm} <= 4'b0; `TERM; end

        endcase

        // LOOPN?Z
        8'b1110_000x,
        8'b1110_0010: case (t)

            0: begin cx <= cx - 1; if (cx == 1 || (!i[1] && flags[ZF] ^ i[0])) begin ip <= ip + 2; `TERM; end end
            1: begin ip <= ip + 1 + signex; `TERM; end

        endcase

        // JCXZ x
        8'b1110_0011: case (t)

            0: begin if (cx) begin ip <= ip + 2; `TERM; end end
            1: begin ip <= ip + 1 + signex; `TERM; end

        endcase

        // 3/4T* IN a,p
        8'b1110_x10x: case (t)

            0: begin t <= tn + i[3]; port_a <= dx; port_r <= i[3]; end
            1: begin t <= tn; port_a <= i; ip <= ip + 1; port_r <= 1; end
            2: begin t <= tn; if (size) begin port_a <= port_a + 1; port_r <= 1; end end
            3: begin t <= tn; ax[7:0] <= port_i; if (size == 0) begin `TERM; end end
            4: begin ax[15:8] <= port_i; `TERM; end

        endcase

        // 2/3T OUT p,a
        8'b1110_x11x: case (t)

            1: begin

                t <= tn;

                port_a  <= opcode[3] ? dx : i;
                port_o  <= ax[7:0];
                port_w  <= 1;

                if (!opcode[3]) ip <= ip + 1;
                if (!size) begin `TERM; end

            end
            2: begin

                port_a  <= port_a + 1;
                port_o  <= ax[15:8];
                port_w  <= 1;
                `TERM;

            end

        endcase

        // 6T CALL b16
        8'b1110_1000: case (t)

            1: begin t <= 2;    ip <= ip + 1; ea <= i; end
            2: begin r <= PUSH; wb <= ip + 1; ip <= ip + 1 + {i, ea[7:0]}; `TERM; end

        endcase

        // 3T JMP o16
        8'b1110_1001: case (t)

            1: begin ea <= i; ip <= ip + 1; t <= 2; end
            2: begin ip <= ip + 1 + {i, ea[7:0]}; `TERM; end

        endcase

        // 5T JMP far
        8'b1110_1010: case (t)

            // Прочитаьть 4 байта для нового CS:IP
            1: begin ip <= ip + 1; t <= 2; ea       <= i; end
            2: begin ip <= ip + 1; t <= 3; ea[15:8] <= i; end
            3: begin ip <= ip + 1; t <= 4; op1      <= i; end
            4: begin ip <= ea;     cs <= {i, op1[7:0]}; `TERM; end

        endcase

        // 2T JMP b
        8'b1110_1011: case (t) 1: begin ip <= ip + signex + 1; `TERM; end endcase

        // INT 1
        8'b1111_0001: case (t)

            0: begin r <= INTERRUPT; interrupt <= 1; `TERM; end

        endcase

        // 1T REPNZ, REPZ
        8'b1111_001x: begin t <= 0; rep <= i[1:0]; end

        // 1T HLT -- Остановка процессора
        8'b1111_0100: begin `TERM; ip <= ip; halt <= 1; end

        // 1T CMC
        8'b1111_0101: begin `TERM; flags[CF] <= ~flags[CF]; end

        // 1T CLC, STC; CLI, STI; CLD, STD
        8'b1111_100x: begin `TERM; flags[CF] <= i[0]; end
        8'b1111_101x: begin `TERM; flags[IF] <= i[0]; end
        8'b1111_110x: begin `TERM; flags[DF] <= i[0]; end

        // F6-F7 GROUP #3 rm, op
        8'b1111_011x: case (t)

            // Запрос операндов
            0: begin r <= MODRM; cpm <= 0; dir <= 1'b0; end

            // Исполнение инструкции
            default: case (modrm[5:3])

                // 5T+ TEST imm8/16
                0, 1: case (t)

                    1: begin t  <= tn; alu <= AND; end
                    2: begin ip <= ip + 1; op2       <= i; t <= size ? 3 : 4; end
                    3: begin ip <= ip + 1; op2[15:8] <= i; t <= tn; end
                    4: begin flags <= alu_f; `TERM; end

                endcase

                // 4T+ NOT rm
                2: begin wb <= ~op1; r <= WB; `TERM; end

                // 5T+ NEG rm
                3: case (t)

                    1: begin t <= tn; alu <= SUB; op2 <= op1; op1 <= 0; end
                    2: begin r <= WB; wb <= alu_r; flags <= alu_f; `TERM; end

                endcase

                // 4T+ MUL, IMUL rm [IMUL знакорасширяется op1/op2]
                4, 5: case (t)

                    1: begin

                        t       <= tn;
                        op1     <= size ? op1 : {modrm[3] ? {8{op1[7]}} : 8'h00, op1[7:0]};
                        op2     <= size ? ax  : {modrm[3] ? {8{ ax[7]}} : 8'h00,  ax[7:0]};
                        imulw   <= modrm[3];

                    end
                    2: begin

                        if (size) {dx, ax} <= mult[31:0]; else ax <= mult[15:0];

                        flags[ZF] <= multzf;
                        flags[CF] <= multcf;
                        flags[OF] <= multcf;

                        `TERM;

                    end

                endcase

                // DIV [op1, op2] Беззнаковое деление
                // IDIV Деление со знаком
                6, 7: case (t)

                    // Запрос
                    1: begin

                        t    <= tn;
                        r    <= DIV;
                        divr <= 0;
                        op1  <= size ? 8 : 4;

                        if (modrm[3]) begin

                            sign <= divi[31] ^ op1[size ? 15 : 7];
                            diva <= divi[31] ? -divi : divi;
                            divb <= size ? (op1[15] ? -op1 : op1) : (op1[7] ? -op1[7:0] : op1[7:0]);

                        end else begin

                            sign <= 0;
                            diva <= divi;
                            divb <= op1;

                        end

                    end

                    // Результат
                    2: begin

                        // #0 Overflow если в старшем слове или байте есть ненулевое значение
                        r <= (size ? diva[31:16] : diva[15:8]) ? INTERRUPT : INSTR;
                        interrupt <= 0;

                        // Результат DIV или IDIV
                        if (size) {dx, ax} <= {sign ? -divr[15:0] : divr[15:0], sign ? -diva[15:0] : diva[15:0]};
                        else      ax       <= {sign ? -divr[ 7:0] : divr[ 7:0], sign ? -diva[ 7:0] : diva[ 7:0]};

                        `TERM;

                    end

                endcase

            endcase

        endcase

        // FE-FF GROUP #4 rm, op
        8'b1111_111x: case (t)

            // Запрос операндов
            0: begin r <= MODRM; cpm <= 0; dir <= 1'b0; end

            // Исполнение инструкции
            default: case (modrm[5:3])

                // 5T+ INC|DEC rm
                0,
                1: case (t)

                    1: begin t <= tn; op2 <= 1; alu <= modrm[3] ? SUB : ADD; end
                    2: begin r <= WB; wb <= alu_r; flags <= alu_f; `TERM; end

                endcase

                // CALL rm
                2: begin

                    ip <= op1;
                    wb <= ip;
                    r  <= size ? PUSH : UNDEF;
                    `TERM;

                end

                // CALL far rm
                3: case (t)

                    1: begin t <= tn; ea <= ea + 2; ip <= op1; op1 <= ip; op2 <= cs; if (size == 0) r <= UNDEF; end
                    2: begin t <= tn; ea <= ea + 1; wb <= i; end
                    3: begin t <= tn; r <= PUSH; cs <= {i, wb[7:0]}; wb <= op2;  end
                    4: begin t <= tn; r <= PUSH; wb <= op1; `TERM; end

                endcase

                // 3T+ JMP rm
                4: begin ip <= op1; `TERM; if (size == 0) r <= UNDEF; end

                // 7T+ JMP far rm
                5: case (t)

                    1: begin t <= tn; ea <= ea + 2; ip <= op1; if (size == 0) r <= UNDEF; end
                    2: begin t <= tn; ea <= ea + 1; wb <= i; end
                    3: begin cs <= {i, wb[7:0]}; `TERM; end

                endcase

                // PUSH rm
                6: begin r <= PUSH; wb <= op1; `TERM; end
                7: begin r <= UNDEF; end

            endcase

        endcase

        // Неизвестная инструкция. Оповестить об этом
        default: begin r <= UNDEF;ud <= 1; ip <= ip; end

        endcase

    end

    // -------------------------------------------------------------------------
    // Считывание ModRM
    // 1T REG-REG
    // -------------------------------------------------------------------------
    MODRM: case (m)

        0: begin

            // Общие методы работы с операндами
            modrm   <= i;
            ip      <= ip + 1;
            op1     <= dir ? r53 : r20;
            op2     <= dir ? r20 : r53;

            // Подготовка эффективного адреса
            case (i[2:0])
            3'b000: ea <= bx + si;          3'b001: ea <= bx + di;
            3'b010: ea <= bp + si;          3'b011: ea <= bp + di;
            3'b100: ea <= si;               3'b101: ea <= di;
            3'b110: ea <= i[7:6] ? bp : 0;  3'b111: ea <= bx;
            endcase

            // Выбор сегмента SS: для BP, [bp+si|di], [bp+d8|d16]
            if (!over) casex (i) 8'bxx_xxx_01x, 8'b01_xxx_110, 8'b10_xxx_110: sgn <= ss; endcase

            // Роутер
            casex (i)
             // +disp16
            8'b00_xxx_110: begin m <= 2; end
            // Читать операнд из памяти
            8'b00_xxx_xxx: begin m <= cpen ? 4 : 0; cp <= cpen; if (!cpen) r <= INSTR; end
            8'b01_xxx_xxx: begin m <= 1; end // +disp8
            8'b10_xxx_xxx: begin m <= 2; end // +disp16
            8'b11_xxx_xxx: begin m <= 0; r <= INSTR; end // Перейти к исполнению
            default:       begin m <= 1; end
            endcase

        end

        // Чтение 8 битного signed disp
        1: begin

            m  <= 4;
            ip <= ip + 1;
            ea <= ea + signex;
            cp <= cpen;

            if (!cpen) begin m <= 0; r <= INSTR; end

        end

        // Чтение 16 битного unsigned disp16
        2: begin m <= 3; ip <= ip + 1; ea <= ea + i; end
        3: begin

            m  <= 4;
            ip <= ip + 1;
            cp <= cpen;
            ea <= ea + {i, 8'h00};

            if (!cpen) begin m <= 0; r <= INSTR; end

        end

        // Чтение операнда из памяти 8 bit
        4: begin

            if (dir) op2 <= i; else op1 <= i;
            if (size)
                 begin m <= 5; ea <= ean; end
            else begin m <= 0; r <= INSTR; cp <= cpm; end

        end

        // Операнд 16 bit
        5: begin

            if (dir) op2[15:8] <= i; else op1[15:8] <= i;

            m  <= 0;
            r  <= INSTR;
            cp <= cpm;
            ea <= ea - 1;

        end

    endcase

    // -------------------------------------------------------------
    // Сохранение данных [wb, size, dir, modrm]
    // -------------------------------------------------------------
    WB: case (m)

        // Выбор: регистр или память
        0: begin

            // reg-часть или rm:reg
            if (dir || modrm[7:6] == 2'b11) begin

                cp <= 0;
                m  <= 0;
                r  <= (next == WB ? INSTR : next);

                case (dir ? modrm[5:3] : modrm[2:0])
                3'b000: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0];
                3'b001: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0];
                3'b010: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0];
                3'b011: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0];
                3'b100: if (size) sp <= wb; else ax[15:8] <= wb[7:0];
                3'b101: if (size) bp <= wb; else cx[15:8] <= wb[7:0];
                3'b110: if (size) si <= wb; else dx[15:8] <= wb[7:0];
                3'b111: if (size) di <= wb; else bx[15:8] <= wb[7:0];
                endcase

            end
            // Если modrm указывает на память, записать первые 8 бит
            else begin o <= wb[7:0]; cp <= 1; w <= 1; m <= 1; end

        end

        // Запись 16 бит | Либо завершение 8/16 бит записи
        1: if (size) begin size <= 0; w <= 1; ea <= ean; o <= wb[15:8]; end
           else      begin m    <= 0; w <= 0; cp <= 0; r <= (next == WB ? INSTR : next); end

    endcase

    // -------------------------------------------------------------
    // Работа со стеком
    // -------------------------------------------------------------

    // Сохранить wb
    PUSH: case (m)

        0: begin m <= 1; o <= wb[ 7:0]; ea <= sp - 2; cp <= 1; t16 <= sgn; sgn <= ss; w <= 1; end
        1: begin m <= 2; o <= wb[15:8]; ea <= ean; w <= 1; end
        2: begin m <= 0; r <= next; sp <= sp - 2; cp <= 0; sgn <= t16; end

    endcase

    // Извлечь wb
    POP: case (m)

        0: begin m <= 1; t16 <= sgn; sgn <= ss; ea <= sp; cp <= 1; end
        1: begin m <= 2; wb[ 7:0] <= i; ea <= ean; end
        2: begin m <= 0; wb[15:8] <= i; cp <= 0; sp <= sp + 2; sgn <= t16; r <= next; end

    endcase

    // Прерывание interrupt; считается за выполнение инструкции
    // -------------------------------------------------------------
    INTERRUPT: case (mi)

        0: begin mi <= 1; r <= PUSH; wb <= flags; next <= INTERRUPT; end
        1: begin mi <= 2; r <= PUSH; wb <= cs; end
        2: begin mi <= 3; r <= PUSH; wb <= ip; end
        3: begin mi <= 4; ea <= {interrupt, 2'b00}; sgn <= 0; cp <= 1; end
        4: begin mi <= 5; ip[ 7:0] <= i; ea <= ean; end
        5: begin mi <= 6; ip[15:8] <= i; ea <= ean; end
        6: begin mi <= 7; cs[ 7:0] <= i; ea <= ean; end
        7: begin mi <= 0; cs[15:8] <= i; cp <= 0; r <= INSTR; flags[IF] <= 1'b0; end

    endcase

    // Деление diva на divb; повторять op1 раз (количество сдвигов)
    // divr = 0 на старте и является остатком; diva это результат
    DIV: begin

        {divr, diva} <= {div4r, div4a};

        r   <= op1 != 1 ? DIV : INSTR;
        op1 <= op1 - 1;

    end

    endcase

end

// Провода
// -----------------------------------------------------------------------------

wire [ 7:0] opcode = t ? opc : i;
wire [15:0] signex = {{8{i[7]}}, i};
wire [ 5:0] tn  = t + 1;
wire [15:0] ean = ea + 1;

// Для строковых инструкции
wire [15:0] sinc = flags[DF] ? si - (size ? 2 : 1) : si + (size ? 2 : 1);
wire [15:0] dinc = flags[DF] ? di - (size ? 2 : 1) : di + (size ? 2 : 1);

// Разрешение выполнения инструкции с REP: или без
wire        repa = (rep[1] && cx || rep[1] == 0);           // Начало исполнения
wire        repb = (rep[1] && cx != 1);                     // Продолжение исполения
wire [15:0] repc = (i[0] ? 2:1)*(rep[1] ? cx-1 : 0);        // Количество отступов для LODSx

// Вычисление условий
wire [7:0] branch =
{
    (flags[SF] ^ flags[OF]) | flags[ZF], // 7: (ZF=1) OR (SF!=OF)
    (flags[SF] ^ flags[OF]),             // 6: SF != OF
     flags[PF],
     flags[SF],
     flags[CF] | flags[ZF],              // 3: CF != OF
     flags[ZF],
     flags[CF],
     flags[OF]
};

// Значение регистров из i[2:0]
wire [15:0] r20 =
    i[2:0] == 3'h0 ? (size ? ax : ax[ 7:0]) : i[2:0] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[2:0] == 3'h2 ? (size ? dx : dx[ 7:0]) : i[2:0] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[2:0] == 3'h4 ? (size ? sp : ax[15:8]) : i[2:0] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[2:0] == 3'h6 ? (size ? si : dx[15:8]) :                  (size ? di : bx[15:8]);

// Значение регистров из i[5:3]
wire [15:0] r53 =
    i[5:3] == 3'h0 ? (size ? ax : ax[ 7:0]) : i[5:3] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[5:3] == 3'h2 ? (size ? dx : dx[ 7:0]) : i[5:3] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[5:3] == 3'h4 ? (size ? sp : ax[15:8]) : i[5:3] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[5:3] == 3'h6 ? (size ? si : dx[15:8]) :                  (size ? di : bx[15:8]);

// 16-битный регистр
wire [15:0] r16 =
    i[2:0] == 3'h0 ? ax : i[2:0] == 3'h1 ? cx :
    i[2:0] == 3'h2 ? dx : i[2:0] == 3'h3 ? bx :
    i[2:0] == 3'h4 ? sp : i[2:0] == 3'h5 ? bp :
    i[2:0] == 3'h6 ? si : di;

// Умножение и деление
// -----------------------------------------------------------------------------
reg         imulw;
wire [31:0] mult   = {imulw ? {16{op1[15]}} : 16'h0000, op1} * {imulw ? {16{op2[15]}} : 16'h0000, op2};
wire        multzf = (size ? mult[31:0]  : mult[15:0]) == 0;
wire        multcf = (size ? mult[31:16] : mult[15:8]) != 0;

// Арифметико-логическое устройство
// -----------------------------------------------------------------------------

wire [16:0] alu_r =

    alu == ADD ? op1 + op2 :
    alu == OR  ? op1 | op2 :
    alu == ADC ? op1 + op2 + flags[CF] :
    alu == SBB ? op1 - op2 - flags[CF] :
    alu == AND ? op1 & op2:
    alu == XOR ? op1 ^ op2: op1 - op2;

wire [ 3:0] alu_top = size ? 15 : 7;
wire [ 4:0] alu_up  = alu_top + 1'b1;

wire is_add = alu == ADD || alu == ADC;
wire is_lgc = alu == XOR || alu == AND || alu == OR;

wire _of  = !is_lgc & (op1[alu_top] ^ op2[alu_top] ^ is_add) & (op1[alu_top] ^ alu_r[alu_top]);
wire _sf  = alu_r[alu_top];
wire _zf  = (size ? alu_r[15:0] : alu_r[7:0]) == 0;
wire _af  = !is_lgc & (op1[4] ^ op2[4] ^ alu_r[4]);
wire _pf  = ~^alu_r[7:0];
wire _cf  = !is_lgc & alu_r[alu_up];

wire [11:0] alu_f = {_of, flags[10:8], _sf, _zf, 1'b0, _af, 1'b0, _pf, 1'b1, _cf};

// Коррекция
// -----------------------------------------------------------------------------

// Десятичная коррекция
wire        daa_a =    ax[3:0] > 9     || flags[AF];
wire        daa_x = daa_i[7:0] > 8'h9F || daa_c ;
wire        daa_c = daa_a ? daa_i[8] : flags[CF];
wire [8:0]  daa_i = daa_a ? (opcode[3] ?    ax[7:0] - 8'h06 :    ax[7:0] + 8'h06) :    ax[7:0];
wire [15:0] daa_r = daa_x ? (opcode[3] ? daa_i[7:0] - 8'h60 : daa_i[7:0] + 8'h60) : daa_i[7:0];
wire [11:0] daa_f = {flags[11:8], daa_r[7], daa_r[7:0] == 0, 1'b0, daa_a, 1'b0, ~^daa_r[7:0], 1'b1, daa_x};

// ASCII-коррекция
wire [ 3:0] aaa_i = daa_a ? (opcode[3] ? ax[ 3:0] - 6 : ax[ 3:0] + 6) : ax[ 7:0];
wire [ 7:0] aaa_h = daa_a ? (opcode[3] ? ax[15:8] - 1 : ax[15:8] + 1) : ax[15:8];
wire [15:0] aaa_r = daa_a ? {aaa_h, 4'h0, aaa_i} : ax;
wire [11:0] aaa_f = {flags[11:5], daa_a, flags[3:1], daa_a};

// Вычисление сдвигов
// -----------------------------------------------------------------------------
wire [15:0] ri = size ? op1 : {op1[7:0], op1[7:0]};
wire [ 3:0] rs = size ? op2[3:0] : op2[2:0];

// Параллельный сдвиги
wire [32:0] _rol = {1'b0, ri, ri} << rs;
wire [32:0] _ror = {ri, ri, 1'b0} >> rs;
wire [32:0] _rcl = {1'b0, ri, flags[CF], ri[15:1]} << rs;
wire [32:0] _rcr = {ri[14:0], flags[CF], ri, 1'b0} >> rs;
wire [16:0] _shl = ri << op2[7:0];
wire [16:0] _shr = {ri, flags[CF]} >> op2[7:0];
wire [32:0] _sar = {{16{ri[15]}}, ri, 1'b0} >> op2[7:0];

// Результат сдвигов
wire [15:0] barr =
    alu == ROL ? (size ? _rol[31:16] : _rol[23:16]) :
    alu == RCL ? (size ? _rcl[31:16] : _rcl[23:16]) :
    alu == ROR ? (size ? _ror[16:1]  : _ror[16:9])  :
    alu == RCR ? (size ? _rcr[16:1]  : _rcr[16:9])  :
    alu == SHR ? (size ? _shr[16:1]  : _shr[16:9])  :
    alu == SAR ? (size ? _sar[16:1]  : _sar[16:9])  :
                 (size ? _shl[15:0]  : _shl[ 7:0]);  // SHL, SAL

wire rtfl = alu == SHL || alu == SHR || alu == SAL || alu == SHR;

// Флаг переполнения OF
wire rtof =
    alu == SHR ? barr[alu_top] :
    alu == SAR ? 1'b0 : barr[alu_top-1] ^ barr[alu_top];

// Флаг переноса CF после выполнения сдвига
wire rtcf =
    alu == ROL ? _rol[32] : alu == RCL ? _rcl[32] :
    alu == ROR ? _ror[0]  : alu == RCR ? _rcr[0] :
    alu == SHL ? _shl[16] : alu == SHR ? _shr[0] :
    alu == SAR ? _sar[0]  : 1'b0;

// SZP флаги
wire rtsf = rtfl ? barr[alu_top] : flags[SF];
wire rtzf = rtfl ? (size ? barr[15:0] : barr[7:0]) == 0 : flags[ZF];
wire rtpf = rtfl ?  ~^barr[7:0] : flags[PF];

wire [11:0] barf = {rtof, flags[10:8], rtsf, rtzf, 1'b0, flags[AF], 1'b0, rtpf, 1'b1, rtcf};

// Модуль деления
// ---------------------------------------------------------------------
reg         sign;
reg  [31:0] diva, divb, divr;

// Запрошенный 32 или 16 битный
wire [31:0] divi  = size ? {dx, ax} : {ax, 16'h0000};

// ШАГ 1,2,3,4
wire [31:0] div1  = {divr [30:0], diva [31]};       // Сдвиг
wire [31:0] div2  = {div1r[30:0], div1a[31]};
wire [31:0] div3  = {div2r[30:0], div2a[31]};
wire [31:0] div4  = {div3r[30:0], div3a[31]};
wire [32:0] div1c = div1 - divb;                    // Сравнение после сдвига
wire [32:0] div2c = div2 - divb;
wire [32:0] div3c = div3 - divb;
wire [32:0] div4c = div4 - divb;
wire [31:0] div1r = div1c[32] ? div1 : div1c[31:0]; // Вычисление нового остатка
wire [31:0] div2r = div2c[32] ? div2 : div2c[31:0];
wire [31:0] div3r = div3c[32] ? div3 : div3c[31:0];
wire [31:0] div4r = div4c[32] ? div4 : div4c[31:0];
wire [31:0] div1a = {diva [30:0], ~div1c[32]};      // Заполнение результата
wire [31:0] div2a = {div1a[30:0], ~div2c[32]};
wire [31:0] div3a = {div2a[30:0], ~div3c[32]};
wire [31:0] div4a = {div3a[30:0], ~div4c[32]};

endmodule
