/**
 * @desc Легкий процессор с набором 86
 */

module K86
(
    // Основной контур для процессора
    input               clock,
    input               ce,
    input               reset_n,
    output       [19:0] address,
    input        [ 7:0] in,             // in = ram[address]
    output  reg  [ 7:0] out,
    output  reg         we,
    output              m0,             // M0-считывание инструкции

    // Порты ввода-вывода
    output  reg  [15:0] pa,
    output  reg         pw,
    output  reg         pr,
    input        [ 7:0] pi,
    output  reg  [ 7:0] po,

    // PIC: Программируемый контроллер прерываний
    input               irq,            // Срабатывает на posedge
    input        [ 7:0] irq_in          // Номер IRQ (0..255)
);

// Выбор текущего адреса, segment_id[2] = 1 означает прерывание
assign address = cp ? {segment, 4'h0} + ea : {cs, 4'h0} + ip;
assign m0 = (fn == START);

localparam
    ALU_ROL = 0, ALU_ROR = 1, ALU_RCL = 2, ALU_RCR = 3,
    ALU_SHL = 4, ALU_SHR = 5, ALU_SAL = 6, ALU_SAR = 7;

localparam
    ALU_ADD = 0, ALU_OR  = 1, ALU_ADC = 2, ALU_SBB = 3,
    ALU_AND = 4, ALU_SUB = 5, ALU_XOR = 6, ALU_CMP = 7;

localparam
    CF = 0, PF = 2, AF =  4, ZF =  6, SF = 7,
    TF = 8, IF = 9, DF = 10, OF = 11;

localparam
    AX = 0, CX = 1, DX = 2, BX = 3,
    SP = 4, BP = 5, SI = 6, DI = 7;

localparam
    START = 0, LOAD = 1, MODRM = 2, INSTR = 3,  INTR  = 4,
    WB    = 5, PUSH = 6, POP   = 7, REPF  = 8,  DIV   = 9,
    UNDEF = 9;

// -----------------------------------------------------------------------------
wire [15:0] signex = {{8{in[7]}}, in};
wire [15:0] rin =
    in[2:0] == AX ? ax : in[2:0] == CX ? cx :
    in[2:0] == DX ? dx : in[2:0] == BX ? bx :
    in[2:0] == SP ? sp : in[2:0] == BP ? bp :
    in[2:0] == SI ? si : di;

// Вычисление условий
wire [7:0] branches =
{
    (flags[SF] ^ flags[OF]) | flags[ZF], // 7: (ZF=1) OR (SF!=OF)
    (flags[SF] ^ flags[OF]),             // 6: SF!=OF
     flags[PF],
     flags[SF],
     flags[CF] | flags[OF],              // 3: CF != OF
     flags[ZF],
     flags[CF],
     flags[OF]
};

// Управляющие регистры и регистры общего назначения
// -----------------------------------------------------------------------------
reg         cp, size, dir, cpen, over, rep_ft, iack, trace_ff;
reg [15:0]  ax, bx, cx, dx, sp, bp, si, di;
reg [15:0]  es, cs, ss, ds;
reg [ 1:0]  rep;
reg [ 3:0]  fn, fnext, s1, s2;
reg [ 7:0]  opcode, modrm;
reg [15:0]  segment, ea, wb, ip, ip_start;
reg [ 7:0]  intr;
reg [ 2:0]  alu;
reg [15:0]  op1, op2;
reg [11:0]  flags;

// Исполнительный блок
// -----------------------------------------------------------------------------
always @(posedge clock)
if (reset_n == 1'b0) begin

    // Разное
    //             ODIT SZ A  P C
    flags   <= 12'b0010_0000_0010;
    fn      <= START;
    ip      <= 16'hFFF0;
    iack    <= 1'b0;
    // Сегменты
    cs      <= 16'hF000;
    es      <= 16'h0000;
    ds      <= 16'h0000;
    ss      <= 16'h0000;
    // Регистры
    ax      <= 16'h0000;
    bx      <= 16'h0000;
    cx      <= 16'h0000;
    dx      <= 16'h0000;
    sp      <= 16'h7C00;
    bp      <= 16'h0000;
    si      <= 16'h0000;
    di      <= 16'h0000;

end
else if (ce) begin

    pr <= 0; // Строб чтения из порта
    pw <= 0; // Строб записи в порт

    case (fn)

        // Сброс перед запуском инструкции
        // -------------------------------------------------------------
        START: begin

            fn          <= LOAD;
            fnext       <= START;       // Возврат по умолчанию
            s1          <= 0;
            s2          <= 0;
            cp          <= 0;           // address = CS:IP
            cpen        <= 1;           // Считывать из памяти modrm rm-часть
            modrm       <= 0;
            segment     <= ds;          // Значение сегмента по умолчанию DS:
            over        <= 1'b0;        // Наличие сегментного префикса
            rep         <= 2'b0;        // Нет префикса REP:
            ea          <= 0;           // Эффективный адрес
            we          <= 0;           // Разрешение записи
            rep_ft      <= 0;           // =0 REP, =1 REPZ|NZ
            wb          <= 0;           // Данные на запись (modrm | reg)
            ip_start    <= ip;          // Для REP:

            // IRQ прерывание вызывается, если счетчик изменился (iack != irq_signal) и IF=1
            if ((iack ^ irq) && flags[IF]) begin

                fn    <= irq ? INTR : LOAD;
                intr  <= irq_in;
                iack  <= irq;

            end
            // TF=1 (Trace Flag включен) и IF=1
            else if (flags[IF] && flags[TF] && trace_ff) begin

                fn   <= INTR;
                intr <= 1;

            end

            // FlipFlop: сначала выполнится инструкция, потом вызывается INT 1
            if (flags[IF] && flags[TF]) trace_ff <= ~trace_ff;

        end

        // Дешифратор опкода
        // -------------------------------------------------------------
        LOAD: begin

            // Параметры по умолчанию
            fn      <= LOAD;
            ip      <= ip + 1;
            size    <= in[0];
            dir     <= in[1];
            alu     <= in[5:3];
            opcode  <= in;

            // Поиск опкода по маске
            casex (in)

                // Сегментные префиксы
                8'b00100110: begin segment <= es; over <= 1; end
                8'b00101110: begin segment <= cs; over <= 1; end
                8'b00110110: begin segment <= ss; over <= 1; end
                8'b00111110: begin segment <= ds; over <= 1; end
                // REPNZ, REPZ
                8'b1111001x: begin rep <= in[1:0]; end
                // FS, GS, OpSize, AdSize, Ext
                8'b00001111,
                8'b0110010x,
                8'b0110011x,
                // NOP, LOCK: FWAIT
                8'b10010000,
                8'b10011011,
                8'b11110000: begin /* LOAD */ end
                // ALU rm | ALU a,imm
                8'b00xxx0xx: begin fn <= MODRM; end
                8'b00xxx10x: begin fn <= INSTR; end
                // DAA, DAS, AAA, AAS
                8'b001xx111: begin fn <= START; ax <= daa_r; flags <= flags_d; end
                // MOV rm, i | LEA r, m
                8'b1100011x,
                8'b10001101: begin fn <= MODRM; cpen <= 0; end
                // INC | DEC r
                8'b0100xxxx: begin

                    fn      <= INSTR;
                    alu     <= in[3] ? ALU_SUB : ALU_ADD;
                    op1     <= rin;
                    op2     <= 1;
                    size    <= 1;

                end
                // XCHG r, a
                8'b10010xxx: begin

                    fn          <= WB;
                    ax          <= rin;
                    wb          <= ax;
                    dir         <= 1;
                    size        <= 1;
                    modrm[5:3]  <= in[2:0];

                end
                // PUSH r
                8'b01010xxx: begin fn <= PUSH; wb <= rin; end
                // POP r,s,etc.
                8'b01011xxx, // POP r
                8'b000xx111, // POP s
                8'b10011101, // POPF
                8'b1100101x, // RETF [i]
                8'b1x001111, // POP rm; IRET; RET [i]
                8'b1100001x: begin fn <= POP; fnext <= INSTR; end
                // PUSH s
                8'b00000110: begin fn <= PUSH; wb <= es; end
                8'b00001110: begin fn <= PUSH; wb <= cs; end
                8'b00010110: begin fn <= PUSH; wb <= ss; end
                8'b00011110: begin fn <= PUSH; wb <= ds; end
                // PUSHF
                8'b10011100: begin fn <= PUSH; wb <= flags; end
                // CLx/STx, CMC
                8'b1111100x: begin fn <= START; flags[CF] <= in[0]; end
                8'b1111101x: begin fn <= START; flags[IF] <= in[0]; end
                8'b1111110x: begin fn <= START; flags[DF] <= in[0]; end
                8'b11110101: begin fn <= START; flags[CF] <= ~flags[CF]; end
                // SAHF, LAHF
                8'b10011110: begin fn <= START; flags     <= ax[15:8]; end
                8'b10011111: begin fn <= START; ax[15:8]  <= flags[7:0] | 2; end
                // SALC
                8'b11010110: begin fn <= START; ax[ 7:0]  <= {8{flags[CF]}}; end
                // HALT
                8'b11110100: begin fn <= START; ip <= ip; end
                // Grp#1 ALU; XCHG rm, r
                8'b100000xx,
                8'b1000011x: begin fn <= MODRM; dir <= 0; end
                // TEST rm | TEST a,i
                8'b1000010x: begin fn <= MODRM; alu <= ALU_AND; end
                // CBW, CWD
                8'b10011000: begin fn <= START; ax[15:8] <= {8{ax[7]}}; end
                8'b10011001: begin fn <= START; dx       <= {16{ax[15]}}; end
                // MOV s,rm
                8'b10001110: begin fn <= MODRM; size <= 1; end
                // XLATB
                8'b11010111: begin fn <= INSTR; ea <= bx + ax[7:0]; cp <= 1; end
                // LES|LDS r,m
                8'b1100010x: begin fn <= MODRM; size <= 1; dir <= 1; end
                // INT 1,3; INTO
                8'b11110001: begin intr <= 1; fn <= INTR; end
                8'b11001100: begin intr <= 3; fn <= INTR; end
                8'b11001110: begin intr <= 4; fn <= flags[OF] ? INTR : START; end
                // Grp#4|5; Сдвиги
                8'b1111x11x,
                8'b1100000x,
                8'b110100xx: begin fn <= MODRM; dir <= 0; end
                // Jccc; JCXZ
                8'b0111xxxx,
                8'b11100011: begin

                    if ((branches[ in[3:1] ] == in[0] && !in[7]) || (in[7] && cx))
                         begin fn <= START; ip <= ip + 2; end
                    else begin fn <= INSTR; end

                end
                // LOOP[NZ|Z]
                8'b111000xx: begin

                    // Если бит 1 равен 1, то ZF=bit[0] не имеет значения
                    if ((cx != 1) && (in[1] || flags[ZF] == in[0]))
                         begin fn <= INSTR; end
                    else begin fn <= START; ip <= ip + 2; end

                    cx <= cx - 1;

                end
                // Определить наличие байта ModRM для опкода
                default: casex (in)

                    8'b1000xxxx, 8'b1100000x, 8'b110001xx, 8'b011010x1,
                    8'b110100xx, 8'b11011xxx, 8'b1111x11x, 8'b0110001x:
                             fn <= MODRM;
                    default: fn <= INSTR;

                endcase

            endcase

        end

        // Считывание MODRM
        // -------------------------------------------------------------
        MODRM: case (s1)

            // Считывание адреса или регистров
            0: begin

                modrm <= in;
                ip    <= ip + 1;

                // Первый операнд (dir=1 будет выбрана reg-часть)
                case (dir ? in[5:3] : in[2:0])
                AX: op1 <= size ? ax : ax[ 7:0];
                CX: op1 <= size ? cx : cx[ 7:0];
                DX: op1 <= size ? dx : dx[ 7:0];
                BX: op1 <= size ? bx : bx[ 7:0];
                SP: op1 <= size ? sp : ax[15:8];
                BP: op1 <= size ? bp : cx[15:8];
                SI: op1 <= size ? si : dx[15:8];
                DI: op1 <= size ? di : bx[15:8];
                endcase

                // Второй операнд (dir=1 будет выбрана rm-часть)
                case (dir ? in[2:0] : in[5:3])
                AX: op2 <= size ? ax : ax[ 7:0];
                CX: op2 <= size ? cx : cx[ 7:0];
                DX: op2 <= size ? dx : dx[ 7:0];
                BX: op2 <= size ? bx : bx[ 7:0];
                SP: op2 <= size ? sp : ax[15:8];
                BP: op2 <= size ? bp : cx[15:8];
                SI: op2 <= size ? si : dx[15:8];
                DI: op2 <= size ? di : bx[15:8];
                endcase

                // Подготовка эффективного адреса
                case (in[2:0])
                3'b000: ea <= bx + si;
                3'b001: ea <= bx + di;
                3'b010: ea <= bp + si;
                3'b011: ea <= bp + di;
                3'b100: ea <= si;
                3'b101: ea <= di;
                3'b110: ea <= in[7:6] ? bp : 0; // bp; disp16
                3'b111: ea <= bx;
                endcase

                // Выбор сегмента SS: для BP
                if (!over)
                casex (in)
                8'bxx_xxx_01x, // [bp+si|di]
                8'b01_xxx_110, // [bp+d8|d16]
                8'b10_xxx_110: segment <= ss;
                endcase

                // Переход сразу к исполнению инструкции: операнды уже получены
                casex (in)
                8'b00_xxx_110: begin s1 <= 2; end // +disp16
                // Читать операнд из памяти
                8'b00_xxx_xxx: begin s1 <= cpen ? 4 : 0; cp <= cpen; if (!cpen) fn <= INSTR; end
                8'b01_xxx_xxx: begin s1 <= 1; end // +disp8
                8'b10_xxx_xxx: begin s1 <= 2; end // +disp16
                8'b11_xxx_xxx: begin s1 <= 0; fn <= INSTR; end // Перейти к исполнению
                default:       begin s1 <= 1; end
                endcase

            end

            // Чтение 8 битного signed disp
            1: begin

                s1 <= 4;
                ip <= ip + 1;
                ea <= ea + signex;
                cp <= cpen;

                if (!cpen) begin s1 <= 0; fn <= INSTR; end

            end

            // Чтение 16 битного unsigned disp16
            2: begin

                s1 <= 3;
                ip <= ip + 1;
                ea <= ea + in;

            end
            3: begin

                s1 <= 4;
                ip <= ip + 1;
                cp <= cpen;
                ea <= ea + {in, 8'h00};

                if (!cpen) begin s1 <= 0; fn <= INSTR; end

            end

            // Чтение операнда из памяти 8 bit
            4: begin

                if (dir) op2 <= in; else op1 <= in;
                if (size)
                     begin s1 <= 5; ea <= ea + 1; end
                else begin s1 <= 0; fn <= INSTR;  end

            end

            // Операнд 16 bit
            5: begin

                if (dir) op2[15:8] <= in; else op1[15:8] <= in;

                s1 <= 0;
                fn <= INSTR;
                ea <= ea - 1;

            end

        endcase

        // Исполнение инструкции
        // -------------------------------------------------------------
        INSTR: casex (opcode)

            // <alu> rm
            8'b00xxx0xx: begin

                wb    <= alu_r;
                flags <= alu_f;

                fn <= (alu != ALU_CMP) ? WB : START;

            end
            // <alu> a, imm
            8'b00xxx10x: case (s2)

                // Инициализация
                0: begin

                    op1 <= size ? ax : ax[7:0];
                    op2 <= in;
                    s2  <= size ? 1 : 2;
                    ip  <= ip + 1;

                end

                // Считывание старшего байта
                1: begin s2 <= 2; op2[15:8] <= in; ip <= ip + 1; end

                // Запись в регистр и выход из процедуры
                2: begin

                    fn      <= START;
                    flags   <= alu_f;

                    if (alu != ALU_CMP) begin

                        if (size) ax      <= alu_r;
                        else      ax[7:0] <= alu_r[7:0];

                    end

                end

            endcase
            // MOV r, i
            8'b1011xxxx: case (s2)

                // 8 bit
                0: begin

                    s2          <= 1;
                    dir         <= 1;
                    size        <= opcode[3];
                    modrm[5:3]  <= opcode[2:0];
                    wb          <= in;
                    ip          <= ip + 1;

                    if (opcode[3] == 0) fn <= WB;

                end

                // 16 bit
                1: begin

                    wb[15:8] <= in;

                    fn <= WB;
                    ip <= ip + 1;

                end

            endcase
            // MOV rm
            8'b100010xx: begin

                wb <= op2;
                fn <= WB;

            end
            // MOV rm, i
            8'b1100011x: case (s2)

                // 8 bit
                0: begin

                    s2  <= 1; wb <= in; dir <= 0; ip  <= ip + 1;
                    if (size == 0) begin fn <= WB; cp <= 1; end

                end

                // 16 bit
                1: begin fn <= WB; cp <= 1; ip <= ip + 1; wb[15:8] <= in; end

            endcase
            // LEA r16, m
            8'b10001101: begin

                wb   <= ea;
                size <= 1;
                dir  <= 1;
                fn   <= WB;

            end
            // INC | DEC r16
            8'b0100xxxx: begin

                fn          <= WB;
                modrm[5:3]  <= opcode[2:0];
                dir         <= 1;
                wb          <= alu_r;
                flags       <= {alu_f[11:1], flags[CF]};

            end
            // POP r
            8'b01011xxx: begin

                fn    <= WB;
                size  <= 1;
                dir   <= 1;
                fnext <= START;
                modrm[5:3] <= opcode[2:0];

            end
            // POP s
            8'b000xx111: begin

                fn <= START;

                case (opcode[4:3])
                2'b00: es <= wb;
                2'b01: cs <= wb;
                2'b10: ss <= wb;
                2'b11: ds <= wb;
                endcase

            end
            // <alu> imm
            8'b100000xx: case (s2)

                // Считывание imm и номера кода операции
                0: begin s2 <= 1; alu <= modrm[5:3]; cpen <= cp; cp <= 0; end
                1: begin s2 <= 2; op2 <= in; ip <= ip + 1; end
                2: begin s2 <= 3;

                    case (opcode[1:0])
                    2'b01: begin op2[15:8] <= in; ip <= ip + 1; end // imm16
                    2'b11: begin op2[15:8] <= {8{op2[7]}}; end      // sign8
                    endcase

                end
                // Запись
                3: begin

                    cp      <= cpen;
                    wb      <= alu_r;
                    flags   <= alu_f;
                    fn      <= (alu != ALU_CMP) ? WB : START;

                end

            endcase
            // MOV a,[m] | [m],a
            8'b101000xx: case (s2)

                // Прочесть адрес
                0: begin ea[ 7:0] <= in; ip <= ip + 1; s2 <= 1; end
                1: begin ea[15:8] <= in; ip <= ip + 1; cp <= 1; s2 <= dir ? 2 : 5; end

                // Запись A в память
                2: begin we <= 1; out <= ax[ 7:0]; s2 <= size ? 3 : 4; end
                3: begin we <= 1; out <= ax[15:8]; s2 <= 4; ea <= ea + 1; end
                4: begin fn <= START; we <= 0; end

                // Чтение A из памяти
                5: begin s2 <= 6;     ax[ 7:0] <= in; ea <= ea + 1; if (!size) fn <= START; end
                6: begin fn <= START; ax[15:8] <= in; end

            endcase
            // TEST rm,r
            8'b1000010x: begin

                flags <= alu_f;
                fn    <= START;

            end
            // XCHG rm,r
            8'b100001xx: case (s2)

                0: begin

                    fn      <= WB;
                    fnext   <= INSTR;
                    s2      <= 1;
                    dir     <= 1;
                    wb      <= op1;

                end
                1: begin

                    fn      <= WB;
                    fnext   <= START;
                    dir     <= 0;
                    wb      <= op2;

                end

            endcase
            // POPF
            8'b10011101: begin

                fn      <= START;
                flags   <= wb | 2;

            end
            // TEST a,i
            8'b1010100x: case (s2)

                // Считывание младшего байта
                0: begin s2 <= size ? 1 : 2; alu <= ALU_AND; op1 <= ax; op2 <= in; ip <= ip + 1; end

                // Если size, считывание старшего байта
                1: begin s2 <= 2; op2[15:8] <= in; ip <= ip + 1; end

                // Запись результата в АЛУ
                2: begin flags <= alu_f; fn <= START; end

            endcase
            // Jccc
            8'b0111xxxx,
            // LOOPNZ, JCXZ
            8'b111000xx,
            // JMP b8
            8'b11101011: begin

                fn <= START;
                ip <= ip + 1 + signex;

            end
            // JMP b16
            8'b11101001: case (s2)

                0: begin s2 <= 1;     ip <= ip + 1; ea[7:0] <= in; end
                1: begin fn <= START; ip <= ip + 1 + {in, ea[7:0]}; end

            endcase
            // JMP seg:off
            8'b11101010: case (s2)

                0: begin ip <= ip + 1; s2 <= 1; ea[ 7:0] <= in; end
                1: begin ip <= ip + 1; s2 <= 2; ea[15:8] <= in; end
                2: begin ip <= ip + 1; s2 <= 3; op1[7:0] <= in; end
                3: begin ip <= ea;     cs <= {in, op1[7:0]}; fn <= START; end

            endcase
            // CALL b16
            8'b11101000: case (s2)

                0: begin s2 <= 1; ea <= in; ip <= ip + 1; end
                1: begin fn <= PUSH; wb <= ip + 1; ip <= ip + 1 + {in, ea[7:0]}; end

            endcase
            // RET
            8'b11000011: begin

                fn <= START;
                ip <= wb;

            end
            // RET i16
            8'b11000010: case (s2)

                0: begin s2 <= 1; ea <= in; ip <= ip + 1; end
                1: begin fn <= START; ip <= wb; sp <= sp + {in, ea[7:0]}; end

            endcase
            // RETF; RETF i16
            8'b1100101x: case (s2)

                0: begin fn <= POP;   s2 <= 1;  op1 <= wb;  op2 <= in; ip <= ip + 1; end
                1: begin fn <= START; cs <= wb; ip  <= op1; if (!opcode[0]) sp <= sp + {in, op2[7:0]}; end

            endcase
            // IRET
            8'b11001111: case (s2)

                0: begin s2 <= 1; fn <= POP; ip <= wb; end
                1: begin s2 <= 2; fn <= POP; cs <= wb; end
                2: begin fn <= START; flags <= wb[11:0] | 2; end

            endcase
            // MOV rm,s
            8'b10001100: begin

                fn   <= WB;
                size <= 1;

                case (modrm[4:3])
                2'b00: wb <= es;
                2'b01: wb <= cs;
                2'b10: wb <= ss;
                2'b11: wb <= ds;
                endcase

            end
            // MOV s,rm
            8'b10001110: begin

                fn <= START;
                case (modrm[4:3])
                0: es <= op2;
                1: cs <= op2;
                2: ss <= op2;
                3: ds <= op2;
                endcase

            end
            // CALLF b16
            8'b10011010: case (s2)

                0: begin s2 <= 1;   ip <= ip + 1; op1[ 7:0] <= in; end
                1: begin s2 <= 2;   ip <= ip + 1; op1[15:8] <= in; end
                2: begin s2 <= 3;   ip <= ip + 1; op2[ 7:0] <= in; end
                3: begin s2 <= 4;   ip <= ip + 1; op2[15:8] <= in; fn <= PUSH; wb <= cs; fnext <= INSTR; end
                4: begin s2 <= 5;   fn <= PUSH;  wb <= ip; fnext <= INSTR; end
                5: begin ip <= op1; fn <= START; cs <= op2;  end

            endcase
            // LES|LDS r,m
            8'b1100010x: case (s2)

                0: begin

                    s2 <= 1;
                    ea <= ea + 2;

                end
                1: begin s2 <= 2; wb[7:0] <= in;  ea <= ea + 1; end
                2: begin

                    fn <= WB;
                    wb <= op2;

                    if (opcode[0])
                         ds <= {in, wb[7:0]};
                    else es <= {in, wb[7:0]};

                end

            endcase
            // POP rm
            8'b10001111: case (s2)

                0: begin s2 <= 1; cpen <= 0; fn <= MODRM; dir <= 0; end
                1: begin cp <= 1; fn <= WB; fnext <= START; end

            endcase
            // PUSH i
            8'b011010x0: case (s2)

                0: begin s2 <= opcode[1] ? 2 : 1; wb <= signex; ip <= ip + 1; end
                1: begin s2 <= 2; wb[15:8] <= in; ip <= ip + 1; end
                2: begin fn <= PUSH; fnext <= START; end

            endcase
            // XLATB
            8'b11010111: begin

                fn      <= START;
                ax[7:0] <= in;

            end
            // INT i
            8'b11001101: begin

                fn      <= INTR;
                intr    <= in;
                ip      <= ip + 1;

            end
            // Grp#2 Сдвиги
            8'b1100000x,
            8'b110100xx: case (s2)

                // Выбор второго операнда
                // Если тут был указатель на памятьЮ, то сбросить его
                0: if (cp) cp <= 0; else
                begin

                    s2  <= 1;
                    alu <= modrm[5:3];

                    if (opcode[4])
                         begin op2 <= (opcode[1] ? cx[3:0] : 1); end
                    else begin op2 <= in[3:0]; ip <= ip + 1; end

                end

                // Процедура сдвига на 0..15 шагов
                1: begin

                    // Вычисление
                    if (op2) begin op1 <= rot_r; flags <= rot_f; end
                    // Запись результата
                    else begin wb <= op1; cp <= 1; fn <= WB; end

                    op2 <= op2 - 1;

                end

            endcase
            // IN a,p
            8'b1110x10x: case (s2)

                // Чтение номера порта
                0: begin

                    s2      <= 1;
                    cpen    <= 0;
                    pa      <= opcode[3] ? dx : in;
                    if (!opcode[3]) ip <= ip + 1;

                end

                // Чтение, ожидание результата 1 такт
                1: begin s2 <= 2; pr <= 1; end
                2: begin s2 <= 3; end

                // Запись ответа в AL|AH
                3: begin

                    if (size) begin s2 <= 1; cpen <= 1; end
                    else fn <= START;

                    if (cpen)
                         ax[15:8] <= pi;
                    else ax[ 7:0] <= pi;

                    pa     <= pa + 1;
                    size   <= 0;

                end

            endcase
            // OUT p,a
            8'b1110x11x: case (s2)

                0: begin

                    s2 <= 1;

                    pa  <= opcode[3] ? dx : in;
                    po  <= ax[7:0];
                    pw  <= 1;

                    if (!opcode[3]) ip <= ip + 1;
                    if (!size) fn <= START;

                end
                1: begin

                    pa  <= pa + 1;
                    po  <= ax[15:8];
                    pw  <= 1;
                    fn      <= START;

                end

            endcase
            // Grp#3: TEST, NOT, NEG, MUL, IMUL, DIV, IDIV
            8'b1111011x: case (modrm[5:3])

                // TEST imm8/16
                0, 1: case (s2)

                    0: begin s2 <= 1; cp <= 0; alu <= ALU_AND; end
                    1: begin s2 <= size ? 2 : 3; op2 <= in; ip <= ip + 1; end
                    2: begin s2 <= 3; op2[15:8] <= in; ip <= ip + 1; end
                    3: begin fn <= START; flags <= alu_f; end

                endcase

                // NOT rm
                2: begin wb <= ~op1; fn <= WB; end

                // NEG rm
                3: case (s2)

                    0: begin s2 <= 1; alu <= ALU_SUB; op2 <= op1; op1 <= 0; end
                    1: begin fn <= WB; wb <= alu_r; flags <= alu_f; end

                endcase

                // MUL | IMUL
                4, 5: case(s2)

                    // Запрос
                    0: begin

                        s2 <= 1;
                        if (modrm[3]) begin
                            op1 <= size ? op1 : {{8{op1[7]}}, op1[7:0]};
                            op2 <= size ? ax  : {{8{ ax[7]}},  ax[7:0]};
                        end else begin
                            op2 <= size ? ax : ax[7:0];
                        end

                    end
                    // Запись результата
                    1: begin

                        cp <= 1'b0;
                        fn <= START;

                        // CF,OF устанавливаются при переполнении
                        // ZF при нулевом результате
                        if (size) begin

                            ax <= mult[15:0];
                            dx <= mult[31:16];
                            flags[ZF]  <= ~|mult[31:0];
                            flags[CF]  <=  |dx;
                            flags[OF]  <=  |dx;

                        end else begin

                            ax[15:0]   <= mult[15:0];
                            flags[ZF]  <= ~|mult[15:0];
                            flags[CF]  <=  |ax;
                            flags[OF]  <=  |ax;

                        end
                    end

                endcase

            endcase
            // Grp#4|5
            8'b1111111x: case (modrm[5:3])

                // INC|DEC rm
                0,
                1: case (s2)

                    0: begin s2 <= 1; op2 <= 1; alu <= modrm[3] ? ALU_SUB : ALU_ADD; end
                    1: begin fn <= WB; wb <= alu_r; flags <= alu_f; end

                endcase

                // CALL rm
                2: begin

                    ip <= op1;
                    wb <= ip;
                    fn <= size ? PUSH : UNDEF;

                end

                // CALL far rm
                3: case (s2)

                    0: begin s2 <= 1; ea <= ea + 2; ip <= op1; op1 <= ip; op2 <= cs; if (size == 0) fn <= UNDEF; end
                    1: begin s2 <= 2; ea <= ea + 1; wb <= in; fnext <= INSTR; end
                    2: begin s2 <= 3; fn <= PUSH; cs <= {in, wb[7:0]}; wb <= op2;  end
                    3: begin s2 <= 4; fn <= PUSH; wb <= op1; end
                    4: begin fn <= START; end

                endcase

                // JMP rm
                4: begin ip <= op1; fn <= size ? START : UNDEF; end

                // JMP far rm
                5: case (s2)

                    0: begin s2 <= 1; ea <= ea + 2; ip <= op1; if (size == 0) fn <= UNDEF; end
                    1: begin s2 <= 2; ea <= ea + 1; wb <= in; end
                    2: begin fn <= START;           cs <= {in, wb[7:0]}; end

                endcase

                // PUSH rm
                6: begin fn <= PUSH; wb <= op1; end
                7: begin fn <= UNDEF; end

            endcase
            // STOSx
            8'b1010101x: case (s2)

                0: begin // STOSB

                    s2      <= size ? 1 : 2;
                    cp      <= 1;
                    we      <= 1;
                    ea      <= di;
                    out     <= ax[7:0];
                    segment <= es;

                end
                1: begin // STOSW

                    s2  <= 2;
                    we  <= 1;
                    ea  <= ea + 1;
                    out <= ax[15:8];

                end
                2: begin

                    we  <= 0;
                    fn  <= rep[1] ? REPF : START;
                    cp  <= 0;
                    di  <= flags[DF] ? di - (size + 1) : di + (size + 1);
                    size <= 1;

                end

            endcase
            // LODSx
            8'b1010110x: case (s2)

                0: begin s2 <= 1; cp <= 1;   ea <= si; end
                1: begin s2 <= size ? 2 : 3; ea <= ea + 1; ax[7:0] <= in; end
                2: begin s2 <= 3; ax[15:8] <= in; end
                3: begin

                    fn      <= rep[1] ? REPF : START;
                    cp      <= 0;
                    si      <= flags[DF] ? si - (opcode[0] + 1) : si + (opcode[0] + 1);
                    size    <= 1;

                end

            endcase
            // MOVSx
            8'b1010010x: case (s2)

                // Загрузка 8 или 16 бит DS:SI
                0: begin s2 <= 1; ea <= si; cp <= 1; end
                1: begin s2 <= size ? 2 : 3; wb <= in; ea <= ea + 1; end
                2: begin s2 <= 3; wb[15:8] <= in; end

                // Запись 8 или 16 бит ES:DI
                3: begin

                    s2      <= size ? 4 : 5;
                    we      <= 1;
                    ea      <= di;
                    segment <= es;
                    out     <= wb[7:0];

                end
                4: begin s2 <= 5; we <= 1; ea <= ea + 1; out <= wb[15:8]; end

                // Инкремент или декремент SI
                5: begin

                    s2  <= 6;
                    we  <= 0;
                    cp  <= 0;
                    si  <= flags[DF] ? si - (opcode[0] + 1) : si + (opcode[0] + 1);
                    size <= 1;

                end

                // Инкремент или декремент DI
                6: begin s2 <= 6;

                    di <= flags[DF] ? di - (opcode[0] + 1) : di + (opcode[0] + 1);

                    // Использование REP:
                    fn  <= rep[1] ? REPF : START;

                end

            endcase
            // CMPSx
            8'b1010011x: case (s2)

                0: begin s2 <= 1;            cp        <= 1;  ea <= si; alu <= ALU_SUB; end
                1: begin s2 <= size ? 2 : 3; op1       <= in; ea <= ea + 1; end
                2: begin s2 <= 3;            op1[15:8] <= in; end
                3: begin s2 <= 4;            segment   <= es; ea <= di; end
                4: begin s2 <= size ? 5 : 6; op2       <= in; ea <= ea + 1; end
                5: begin s2 <= 6;            op2[15:8] <= in; end

                // Инкремент или декремент SI
                6: begin

                    s2      <= 7;
                    flags   <= alu_f;
                    cp      <= 0;
                    si      <= flags[DF] ? si - (opcode[0] + 1) : si + (opcode[0] + 1);
                    size    <= 1;

                end

                // Инкремент или декремент DI
                7: begin

                    rep_ft  <= 1;

                    // Проверять на REPNZ или REPZ
                    di  <= flags[DF] ? di - (opcode[0] + 1) : di + (opcode[0] + 1);

                    // Использование REP:
                    fn  <= rep[1] ? REPF : START;

                end

            endcase
            // SCASx
            8'b1010111x: case (s2)

                0: begin

                    s2      <= 1;
                    cp      <= 1;
                    alu     <= ALU_SUB;
                    op1     <= ax;
                    ea      <= di;
                    segment <= es;

                end
                1: begin s2 <= size ? 2 : 3; op2       <= in; ea <= ea + 1; end
                2: begin s2 <= 3;            op2[15:8] <= in; end

                // Инкремент или декремент DI
                3: begin

                    flags   <= alu_f;
                    cp      <= 0;
                    rep_ft  <= 1; // Проверять на REPNZ или REPZ
                    di      <= flags[DF] ? di - (opcode[0] + 1) : di + (opcode[0] + 1);
                    fn      <= rep[1] ? REPF : START;   // Использование REP:

                end

            endcase

        endcase

        // Прерывание intr; считается за выполнение инструкции
        // -------------------------------------------------------------
        INTR: case (s2)

            0: begin s2 <= 1; fn <= PUSH; wb <= flags; fnext <= INTR; end
            1: begin s2 <= 2; fn <= PUSH; wb <= cs; end
            2: begin s2 <= 3; fn <= PUSH; wb <= ip; end
            3: begin s2 <= 4; ea <= {intr, 2'b00}; segment <= 0; cp <= 1; end
            4: begin s2 <= 5; ea <= ea + 1; ip[ 7:0] <= in; end
            5: begin s2 <= 6; ea <= ea + 1; ip[15:8] <= in; end
            6: begin s2 <= 7; ea <= ea + 1; cs[ 7:0] <= in; end
            7: begin cp <= 0; ea <= ea + 1; cs[15:8] <= in; fn <= START; flags[IF] <= 1'b0; end

        endcase

        // Сохранение данных [wb, size, dir, modrm]
        // -------------------------------------------------------------
        WB: case (s1)

            // Выбор - регистр или память
            0: begin

                // reg-часть или rm:reg
                if (dir || &modrm[7:6]) begin

                    cp <= 0;
                    s1 <= 0;
                    fn <= fnext;

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
                // Если modrm указывает на память, записать первые 8 бит
                else begin out <= wb[7:0]; we <= 1; s1 <= 1; end

            end

            // Запись 16 бит | Либо завершение 8/16 бит записи
            1: if (size) begin size <= 0; ea <= ea + 1; out <= wb[15:8]; end
               else      begin s1   <= 0; cp <= 0; we <= 0; fn <= fnext; end

        endcase

        // Запись в стек <= wb [cp,ea,segment]
        // -------------------------------------------------------------
        PUSH: case (s1)

            0: begin s1 <= 1; out <= wb[ 7:0]; ea <= sp - 2; we <= 1; cp <= 1; segment <= ss; end
            1: begin s1 <= 2; out <= wb[15:8]; ea <= ea + 1; end
            2: begin s1 <= 0; we  <= 0; cp <= 0; sp <= sp - 2; fn <= fnext; end

        endcase

        // Чтение из стека => wb [cp,ea,segment]
        // -------------------------------------------------------------
        POP: case (s1)

            0: begin s1 <= 1; segment  <= ss; ea <= sp; cp <= 1; end
            1: begin s1 <= 2; wb[ 7:0] <= in; ea <= ea + 1; end
            2: begin s1 <= 0; wb[15:8] <= in; cp <= 0; sp <= sp + 2; fn <= fnext; end

        endcase

        // Выполнение инструкции REP
        REPF: case (s1)

            // Уменьшить CX - 1
            0: begin s1 <= 1; cx <= cx - 1; end
            1: begin

                s1 <= 0;
                fn <= START;

                // CX=0, повтор закончен
                if (cx) begin

                    // REPNZ|REPZ
                    if (rep_ft) begin if (rep[0] == flags[ZF]) ip <= ip_start; end
                    // REP:
                    else ip <= ip_start;

                end

            end

        endcase

        // Деление op1 на op2, size -> wb
        DIV: begin
/*
            if (divcnt) begin

                // Следующий остаток
                divrem <= _divr >= divb ? _divr - divb : _divr;

                // Вдвиг нового бита результата
                divres <= {divres[30:0], _divr >= divb};

                // Сдвиг влево делимого
                diva   <= {diva[30:0], 1'b0};

                // Уменьшение счетчика
                divcnt <= divcnt - 1'b1;

            end
            else fn <= fnext;
*/
        end

    endcase

end

// Арифметикое и логическое устройство
// ---------------------------------------------------------------------

wire [31:0] mult = op1 * op2;

wire [ 3:0] alu_top = size ? 15 : 7;
wire [ 4:0] alu_up  = alu_top + 1'b1;
wire [16:0] alu_r =

    alu == ALU_ADD ? op1 + op2 :
    alu == ALU_OR  ? op1 | op2 :
    alu == ALU_ADC ? op1 + op2 + flags[CF] :
    alu == ALU_SBB ? op1 - op2 - flags[CF] :
    alu == ALU_AND ? op1 & op2:
    alu == ALU_XOR ? op1 ^ op2:
                     op1 - op2; // SUB, CMP

wire _add = alu == ALU_ADD || alu == ALU_ADC;
wire _lgc = alu != ALU_XOR && alu != ALU_AND && alu != ALU_OR;
wire _cf  = alu_r[alu_up];
wire _sf  = alu_r[alu_top];
wire _af  = (op1[4] ^ op2[4] ^ alu_r[4]);
wire _zf  = (size ? alu_r[15:0] : alu_r[7:0]) == 0;
wire _pf  = ~^alu_r[7:0];
wire _of  = ((op1[alu_top] ^ op2[alu_top] ^ _add) & (op1[alu_top] ^ alu_r[alu_top]));

// Итоговые флаги
wire [11:0] alu_f = {_of & _lgc, flags[10:8], _sf, _zf, 1'b0, _af & _lgc, 1'b0, _pf, 1'b1, _cf & _lgc};

// Сдвиги
// ---------------------------------------------------------------------

reg  [11:0] rot_f;

// Вычислить сдвиг на 1
wire [15:0] rot_r =
    alu == ALU_ROL ? (size ? {op1[14:0], op1[15]}   : {op1[6:0], op1[7]}) :
    alu == ALU_ROR ? (size ? {op1[0], op1[15:1]}    : {op1[0], op1[7:1]}) :
    alu == ALU_RCL ? (size ? {op1[14:0], flags[CF]} : {op1[6:0], flags[CF]}) :
    alu == ALU_RCR ? (size ? {flags[CF], op1[15:1]} : {flags[CF], op1[7:1]}) :
    alu == ALU_SHL ? (size ? {1'b0, op1[15:1]}      : {1'b0, op1[7:1]} ) :
    alu == ALU_SHR ? (size ? {op1[15], op1[15:1]}   : {op1[7], op1[7:1]}) :
                     (size ? {op1[14:0], 1'b0}      : {op1[6:0], 1'b0}); // SHL, SAL

// Вычислить флаги после сдвига
always @* begin

    rot_f = flags;

    // Флаг CF
    rot_f[CF] = alu[0] ? op1[0] : op1[alu_top];

    // Флаг OF
    case (alu)
    ALU_ROR,
    ALU_RCR: rot_f[OF] = rot_r[alu_top] ^ rot_r[alu_top - 1];
    ALU_SHR: rot_f[OF] = op1[alu_top];
    ALU_SAR: rot_f[OF] = 1'b0;
    default: rot_f[OF] = op1[alu_top] ^ op1[alu_top - 1]; // ROL, RCL, SAL, SHL
    endcase

    // SF, ZF, PF для 4х инструкции
    if (alu == ALU_SHL || alu == ALU_SHR || alu == ALU_SAL || alu == ALU_SHR) begin

        rot_f[SF] = rot_r[alu_top];
        rot_f[ZF] = (size ? rot_r[15:0] : rot_r[7:0]) == 0;
        rot_f[PF] = ~^rot_r[7:0];

    end

end

// -----------------------------------------------------------------------------
// Десятичная коррекция DAA, DAS, AAA, AAS
// -----------------------------------------------------------------------------

reg [15:0]  daa_r;
reg [8:0]   daa_i;
reg [7:0]   daa_h;
reg [11:0]  flags_d;
reg         daa_a, daa_c, daa_x;

always @* begin
    daa_r   = ax[15:0];
    flags_d = flags;
    case (in[4:3])
        // DAA, DAS
        0, 1: begin
            daa_c = flags[CF];
            daa_a = flags[AF];
            daa_i = ax[7:0];
            // Младший ниббл
            if (ax[3:0] > 4'h9 || flags[AF]) begin
                daa_i = in[3] ? ax[7:0] - 3'h6 : ax[7:0] + 3'h6;
                daa_c = daa_i[8];
                daa_a = 1'b1;
            end
            daa_r = daa_i[7:0];
            daa_x = daa_c;
            // Старший ниббл
            if (daa_c || daa_i[7:0] > 8'h9F) begin
                daa_r = in[3] ? daa_i[7:0] - 8'h60 : daa_i[7:0] + 8'h60;
                daa_x = 1'b1;
            end
            flags_d[SF] =   daa_r[7];   // SF
            flags_d[ZF] = ~|daa_r[7:0]; // ZF
            flags_d[AF] =   daa_a;      // AF
            flags_d[PF] = ~^daa_r[7:0]; // PF
            flags_d[OF] =   daa_x;      // CF
        end
        // AAA, AAS
        2, 3: begin
            daa_i = ax[ 7:0];
            daa_r = ax[15:0];
            if (flags[4] || ax[3:0] > 4'h9) begin
                daa_i = alu[0] ? ax[ 7:0] - 3'h6 : ax[ 7:0] + 3'h6;
                daa_h = alu[0] ? ax[15:8] - 1'b1 : ax[15:8] + 1'b1;
                daa_r = {daa_h, 4'h0, daa_i[3:0]};
                flags_d[AF] = 1'b1;
                flags_d[CF] = 1'b1;
            end
            else begin
                flags_d[AF] = 1'b0;
                flags_d[CF] = 1'b0;
            end
        end
    endcase
end

endmodule
