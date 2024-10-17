/**
 * Небольшой процессор с ограниченным набором инструкции
 */

/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module core
(
    // Основной контур для процессора
    input               clock,
    input               ce,
    input               reset_n,
    input               cfg_ip0,        // =1 Запускает процессор в CS:IP=0:100h
    output       [19:0] address,
    input        [ 7:0] in,             // in = ram[address]
    output  reg  [ 7:0] out,
    output  reg         we,
    output              m0,             // M0-считывание инструкции

    // Порты ввода-вывода
    output  reg  [15:0] port_a,
    output  reg         port_w,
    output  reg         port_r,
    input        [ 7:0] port_i,
    output  reg  [ 7:0] port_o,

    // Вывести регистры наверх в отладочных целях
    output  reg  [15:0] ax,
    output  reg  [15:0] bx,
    output  reg  [15:0] cx,
    output  reg  [15:0] dx,
    output  reg  [15:0] sp,
    output  reg  [15:0] bp,
    output  reg  [15:0] si,
    output  reg  [15:0] di,
    output  reg  [15:0] es,
    output  reg  [15:0] cs,
    output  reg  [15:0] ss,
    output  reg  [15:0] ds,
    output  reg  [15:0] fs,
    output  reg  [15:0] gs,
    output  reg  [15:0] ip,
    output  reg  [11:0] flags,

    // PIC: Программируемый контроллер прерываний
    input               irq,            // Срабатывает на изменении
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
    CF = 0, PF = 2,  AF = 4, ZF = 6, SF = 7, TF = 8,
    IF = 9, DF = 10, OF = 11;

localparam
    REG_AX = 0, REG_CX = 1, REG_DX = 2, REG_BX = 3,
    REG_SP = 4, REG_BP = 5, REG_SI = 6, REG_DI = 7;

localparam
    START = 0, LOAD = 1, MODRM = 2, INSTR = 3,  INTR  = 4,
    WBACK = 5, PUSH = 6, POP   = 7, DIV   = 8,  UNDEF = 9;

// -----------------------------------------------------------------------------
wire [15:0] signex = {{8{in[7]}}, in};
wire [15:0] rin =
    in[2:0] == REG_AX ? ax : in[2:0] == REG_CX ? cx :
    in[2:0] == REG_DX ? dx : in[2:0] == REG_BX ? bx :
    in[2:0] == REG_SP ? sp : in[2:0] == REG_BP ? bp :
    in[2:0] == REG_SI ? si : di;

// Умножение. Если выбран imulw, то знакорасширяются 16-битные значения
wire [31:0] mult   = {imulw ? {16{op1[15]}} : 16'h0000, op1} * {imulw ? {16{op2[15]}} : 16'h0000, op2};
wire        multzf = (size ? mult[31:0]  : mult[15:0]) == 0;
wire        multcf = (size ? mult[31:16] : mult[15:8]) != 0;

// Для строковых инструкции
wire [15:0] sinc = flags[DF] ? si - (size ? 2 : 1) : si + (size ? 2 : 1);
wire [15:0] dinc = flags[DF] ? di - (size ? 2 : 1) : di + (size ? 2 : 1);

// Разрешение выполнения инструкции с REP: или без
wire        repa = (rep[1] && cx || rep[1] == 0);           // Начало исполнения
wire        repb = (rep[1] && cx != 1);                     // Продолжение исполения
wire [15:0] repc = (in[0] ? 2:1)*(rep[1] ? cx-1 : 0);       // Количество отступов для LODSx

// Вычисление условий
wire [7:0] branches =
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

// Управляющие регистры
// -----------------------------------------------------------------------------
reg         cp, size, dir, cpen, over, iack, trace_ff;
reg [ 1:0]  rep;
reg [ 3:0]  fn, fnext, s1, s2;
reg [ 7:0]  opcode, modrm;
reg [15:0]  segment, ea, wb;
reg [ 7:0]  intr;
reg [ 2:0]  alu;
reg [15:0]  op1, op2, tmp16;
reg         imulw;

// Исполнительный блок
// -----------------------------------------------------------------------------
always @(posedge clock)
if (reset_n == 1'b0) begin

    fn      <= START;
    ax      <= 16'hFFFF;
    bx      <= 16'h0002;
    cx      <= 16'h0908;
    dx      <= 16'h0000;
    sp      <= 16'h0000;
    bp      <= 16'h0000;
    si      <= 16'h0000;
    di      <= 16'h0000;
    ip      <= cfg_ip0 ? 16'h0100 : 16'hFFF0;
    cs      <= cfg_ip0 ? 16'h0000 : 16'hF000;
    es      <= 16'hA000;
    ss      <= 16'h0000;
    ds      <= 16'h0000;
    fs      <= 16'h0000;
    gs      <= 16'h0000;
    iack    <= 1'b0;
    //             ODIT SZ A  P C
    flags   <= 12'b0000_0000_0010;

end
else if (ce) begin

    port_r <= 0; // Строб чтения из порта
    port_w <= 0; // Строб записи в порт

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
            wb          <= 0;           // Данные на запись (modrm | reg)

            // IRQ прерывание вызывается, если счетчик изменился (iack != irq_signal) и IF=1
            if ((iack ^ irq) && flags[IF]) begin

                fn    <= INTR;
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
                8'b0010_0110: begin segment <= es; over <= 1; end
                8'b0010_1110: begin segment <= cs; over <= 1; end
                8'b0011_0110: begin segment <= ss; over <= 1; end
                8'b0011_1110: begin segment <= ds; over <= 1; end
                8'b0110_0100: begin segment <= fs; over <= 1; end
                8'b0110_0101: begin segment <= gs; over <= 1; end
                // REPNZ, REPZ
                8'b1111_001x: begin rep <= in[1:0]; end
                // EXTEND
                8'b0000_1111: begin fn <= INSTR; end
                // OpSize, AdSize
                8'b0110_011x,
                // NOP, LOCK: FWAIT
                8'b1001_0000,
                8'b1001_1011,
                8'b1111_0000: begin /* LOAD */ end
                // ALU rm | ALU a,imm
                8'b00xx_x0xx: begin fn <= MODRM; end
                8'b00xx_x10x: begin fn <= INSTR; end
                // MOV rm, i | LEA r, m
                8'b1100_011x,
                8'b1000_1101: begin fn <= MODRM; cpen <= 0; end
                // INC | DEC r
                8'b0100_xxxx: begin

                    fn      <= INSTR;
                    alu     <= in[3] ? ALU_SUB : ALU_ADD;
                    op1     <= rin;
                    op2     <= 1;
                    size    <= 1;

                end
                // XCHG r, a
                8'b1001_0xxx: begin

                    fn          <= WBACK;
                    ax          <= rin;
                    wb          <= ax;
                    dir         <= 1;
                    size        <= 1;
                    modrm[5:3]  <= in[2:0];

                end
                // PUSH r
                8'b0101_0xxx: begin fn <= PUSH; wb <= rin; end
                // POP r,s,etc.
                8'b0101_1xxx, // POP r
                8'b000x_x111, // POP s
                8'b1001_1101, // POPF
                8'b1100_101x, // RETF [i]
                8'b1x00_1111, // POP rm; IRET; RET [i]
                8'b1100_001x: begin fn <= POP; fnext <= INSTR; end
                // PUSH s
                8'b0000_0110: begin fn <= PUSH; wb <= es; end
                8'b0000_1110: begin fn <= PUSH; wb <= cs; end
                8'b0001_0110: begin fn <= PUSH; wb <= ss; end
                8'b0001_1110: begin fn <= PUSH; wb <= ds; end
                // PUSHF
                8'b1001_1100: begin fn <= PUSH; wb <= flags; end
                // CLx/STx, CMC
                8'b1111_100x: begin fn <= START; flags[CF] <= in[0]; end
                8'b1111_101x: begin fn <= START; flags[IF] <= in[0]; end
                8'b1111_110x: begin fn <= START; flags[DF] <= in[0]; end
                8'b1111_0101: begin fn <= START; flags[CF] <= ~flags[CF]; end
                // IMUL r16,rm,imm
                8'b0110_10x1: begin fn <= MODRM; {dir, size} <= 2'b11; end
                // SAHF, LAHF
                8'b1001_1110: begin fn <= START; flags     <= ax[15:8]; end
                8'b1001_1111: begin fn <= START; ax[15:8]  <= flags[7:0] | 2; end
                // SALC
                8'b1101_0110: begin fn <= START; ax[ 7:0]  <= {8{flags[CF]}}; end
                // HALT
                8'b1111_0100: begin fn <= START; ip <= ip; end
                // Grp#1 ALU; XCHG rm, r
                8'b1000_00xx,
                8'b1000_011x: begin fn <= MODRM; dir <= 0; end
                // TEST rm | TEST a,i
                8'b1000_010x: begin fn <= MODRM; alu <= ALU_AND; end
                // CBW, CWD
                8'b1001_1000: begin fn <= START; ax[15:8] <= {8{ax[7]}}; end
                8'b1001_1001: begin fn <= START; dx       <= {16{ax[15]}}; end
                // MOV s,rm
                8'b1000_1110: begin fn <= MODRM; size <= 1; end
                // XLATB
                8'b1101_0111: begin fn <= INSTR; ea <= bx + ax[7:0]; cp <= 1; end
                // LES|LDS r,m
                8'b1100_010x: begin fn <= MODRM; size <= 1; dir <= 1; end
                // INT 1,3; INTO
                8'b1111_0001: begin intr <= 1; fn <= INTR; end
                8'b1100_1100: begin intr <= 3; fn <= INTR; end
                8'b1100_1110: begin intr <= 4; fn <= flags[OF] ? INTR : START; end
                // Grp#4|5; Сдвиги
                8'b1111_x11x,
                8'b1100_000x,
                8'b1101_00xx: begin fn <= MODRM; dir <= 0; end
                // Jccc; JCXZ
                8'b0111_xxxx,
                8'b1110_0011: begin

                    if ((branches[ in[3:1] ] == in[0] && !in[7]) || (in[7] && cx))
                         begin fn <= START; ip <= ip + 2; end
                    else begin fn <= INSTR; end

                end
                // LOOP[NZ|Z]
                8'b1110_00xx: begin

                    // Если бит 1 равен 1, то ZF=bit[0] не имеет значения
                    if ((cx != 1) && (in[1] || flags[ZF] == in[0]))
                         begin fn <= INSTR; end
                    else begin fn <= START; ip <= ip + 2; end

                    cx <= cx - 1;

                end
                // MOVSx
                8'b1010_010x: begin

                    cp  <= repa;
                    fn  <= repa ? INSTR : START;
                    op1 <= segment;
                    ea  <= si;

                end
                // STOSx
                8'b1010_101x: begin fn <= repa ? INSTR : START; cp <= repa; end
                // LODSx
                8'b1010_110x: begin

                    cp <= repa;
                    ea <= flags[DF] ? si - repc : si + repc;
                    fn <= repa ? INSTR : START;

                end
                // CMPSx
                8'b1010_011x: begin

                    fn  <= repa ? INSTR : START;
                    cp  <= repa;
                    ea  <= si;
                    alu <= ALU_SUB;

                end
                // SCASx
                8'b1010_111x: begin

                    fn  <= repa ? INSTR : START;
                    cp  <= repa;
                    ea  <= di;
                    alu <= ALU_SUB;
                    segment <= es;

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
                REG_AX: op1 <= size ? ax : ax[ 7:0];
                REG_CX: op1 <= size ? cx : cx[ 7:0];
                REG_DX: op1 <= size ? dx : dx[ 7:0];
                REG_BX: op1 <= size ? bx : bx[ 7:0];
                REG_SP: op1 <= size ? sp : ax[15:8];
                REG_BP: op1 <= size ? bp : cx[15:8];
                REG_SI: op1 <= size ? si : dx[15:8];
                REG_DI: op1 <= size ? di : bx[15:8];
                endcase

                // Второй операнд (dir=1 будет выбрана rm-часть)
                case (dir ? in[2:0] : in[5:3])
                REG_AX: op2 <= size ? ax : ax[ 7:0];
                REG_CX: op2 <= size ? cx : cx[ 7:0];
                REG_DX: op2 <= size ? dx : dx[ 7:0];
                REG_BX: op2 <= size ? bx : bx[ 7:0];
                REG_SP: op2 <= size ? sp : ax[15:8];
                REG_BP: op2 <= size ? bp : cx[15:8];
                REG_SI: op2 <= size ? si : dx[15:8];
                REG_DI: op2 <= size ? di : bx[15:8];
                endcase

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
            2: begin s1 <= 3; ip <= ip + 1; ea <= ea + in; end
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

            8'b00xx_x0xx: begin             // <alu> rm

                wb      <= alu_r;
                flags   <= alu_f;
                fn      <= (alu != ALU_CMP) ? WBACK : START;

            end
            8'b00xx_x10x: case (s2)         // <alu> a, imm

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
            8'b1011_xxxx: case (s2)         // MOV r, i

                // 8 bit
                0: begin

                    s2          <= 1;
                    dir         <= 1;
                    size        <= opcode[3];
                    modrm[5:3]  <= opcode[2:0];
                    wb          <= in;
                    ip          <= ip + 1;

                    if (opcode[3] == 0) fn <= WBACK;

                end

                // 16 bit
                1: begin

                    wb[15:8] <= in;

                    fn <= WBACK;
                    ip <= ip + 1;

                end

            endcase
            8'b1000_10xx: begin             // MOV rm

                wb <= op2;
                fn <= WBACK;

            end
            8'b1100_011x: case (s2)         // MOV rm, i

                // 8 bit
                0: begin

                    s2  <= 1; wb <= in; dir <= 0; ip  <= ip + 1;
                    if (size == 0) begin fn <= WBACK; cp <= 1; end

                end

                // 16 bit
                1: begin fn <= WBACK; cp <= 1; ip <= ip + 1; wb[15:8] <= in; end

            endcase
            8'b1000_1101: begin             // LEA r16, m

                wb   <= ea;
                size <= 1;
                dir  <= 1;
                fn   <= WBACK;

            end
            8'b0100_xxxx: begin             // INC | DEC r16

                fn          <= WBACK;
                modrm[5:3]  <= opcode[2:0];
                dir         <= 1;
                wb          <= alu_r;
                flags       <= {alu_f[11:1], flags[CF]};

            end
            8'b0101_1xxx: begin             // POP r

                fn      <= WBACK;
                fnext   <= START;
                size    <= 1;
                dir     <= 1;

                modrm[5:3] <= opcode[2:0];

            end
            8'b000x_x111: begin             // POP s

                fn <= START;

                case (opcode[5:3])
                3'b000: es <= wb; 3'b001: cs <= wb;
                3'b010: ss <= wb; 3'b011: ds <= wb;
                3'b100: fs <= wb; 3'b101: gs <= wb;
                endcase

            end
            8'b0110_10x1: case (s2)         // IMUL r16,rm,s8/u16

                // При указании на память установить на Immediate
                0: if (cp) cp <= 0; else begin

                    s2      <= opcode[1] ? 2 : 1;
                    ip      <= ip + 1;
                    imulw   <= 1;
                    op1     <= op2;
                    op2     <= opcode[1] ? signex : in;

                end
                1: begin s2 <= 2; op2[15:8] <= in; ip <= ip + 1; end
                2: begin

                    wb <= mult[15:0];
                    fn <= WBACK;

                    flags[ZF] <= multzf;
                    flags[CF] <= multcf;
                    flags[OF] <= multcf;

                end

            endcase
            8'b1000_00xx: case (s2)         // <alu> imm

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
                    fn      <= (alu != ALU_CMP) ? WBACK : START;

                end

            endcase
            8'b1010_00xx: case (s2)         // MOV a,[m] | [m],a

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
            8'b1000_010x: begin             // TEST rm,r

                flags <= alu_f;
                fn    <= START;

            end
            8'b1000_01xx: case (s2)         // XCHG rm,r

                0: begin

                    fn      <= WBACK;
                    fnext   <= INSTR;
                    s2      <= 1;
                    dir     <= 1;
                    wb      <= op1;

                end
                1: begin

                    fn      <= WBACK;
                    fnext   <= START;
                    cp      <= 1;
                    dir     <= 0;
                    wb      <= op2;

                end

            endcase
            8'b1001_1101: begin             // POPF

                fn      <= START;
                flags   <= wb | 2;

            end
            8'b1010_100x: case (s2)         // TEST a,i

                // Считывание младшего байта
                0: begin s2 <= size ? 1 : 2; alu <= ALU_AND; op1 <= ax; op2 <= in; ip <= ip + 1; end

                // Если size, считывание старшего байта
                1: begin s2 <= 2; op2[15:8] <= in; ip <= ip + 1; end

                // Запись результата в АЛУ
                2: begin flags <= alu_f; fn <= START; end

            endcase
            8'b0111_xxxx,                   // Jccc
            8'b1110_00xx,                   // LOOPNZ, JCXZ
            8'b1110_1011: begin             // JMP b8

                fn <= START;
                ip <= ip + 1 + signex;

            end
            8'b1110_1001: case (s2)         // JMP b16

                0: begin s2 <= 1;     ip <= ip + 1; ea[7:0] <= in; end
                1: begin fn <= START; ip <= ip + 1 + {in, ea[7:0]}; end

            endcase
            8'b1110_1010: case (s2)         // JMP far

                // Прочитаьть 4 байта для нового CS:IP
                0: begin ip <= ip + 1; s2 <= 1; ea       <= in; end
                1: begin ip <= ip + 1; s2 <= 2; ea[15:8] <= in; end
                2: begin ip <= ip + 1; s2 <= 3; op1      <= in; end
                3: begin ip <= ea;     cs <= {in, op1[7:0]}; fn <= START; end

            endcase
            8'b1110_1000: case (s2)         // CALL b16

                0: begin s2 <= 1; ea <= in; ip <= ip + 1; end
                1: begin fn <= PUSH; wb <= ip + 1; ip <= ip + 1 + {in, ea[7:0]}; end

            endcase
            8'b1100_0011: begin             // RET

                fn <= START;
                ip <= wb;

            end
            8'b1100_0010: case (s2)         // RET i16

                0: begin s2 <= 1; ea <= in; ip <= ip + 1; end
                1: begin fn <= START; ip <= wb; sp <= sp + {in, ea[7:0]}; end

            endcase
            8'b1100_101x: case (s2)         // RETF; RETF i16

                0: begin fn <= POP;   s2 <= 1;  op1 <= wb;  op2 <= in; ip <= ip + 1; end
                1: begin fn <= START; cs <= wb; ip  <= op1; if (!opcode[0]) sp <= sp + {in, op2[7:0]}; end

            endcase
            8'b1100_1111: case (s2)         // IRET

                0: begin s2 <= 1; fn <= POP; ip <= wb; end
                1: begin s2 <= 2; fn <= POP; cs <= wb; end
                2: begin fn <= START; flags <= wb[11:0] | 2; end

            endcase
            8'b1000_1100: begin             // MOV rm,s

                fn   <= WBACK;
                size <= 1;

                case (modrm[5:3])
                0: wb <= es; 1: wb <= cs;
                2: wb <= ss; 3: wb <= ds;
                4: wb <= fs; 5: wb <= gs;
                endcase

            end
            8'b1000_1110: begin             // MOV s,rm

                fn <= START;
                case (modrm[5:3])
                0: es <= op2;
                2: ss <= op2; 3: ds <= op2;
                4: fs <= op2; 5: gs <= op2;
                endcase

            end
            8'b1001_1010: case (s2)         // CALLF b16

                0: begin s2 <= 1;   ip <= ip + 1; op1[ 7:0] <= in; end
                1: begin s2 <= 2;   ip <= ip + 1; op1[15:8] <= in; end
                2: begin s2 <= 3;   ip <= ip + 1; op2[ 7:0] <= in; end
                3: begin s2 <= 4;   ip <= ip + 1; op2[15:8] <= in; fn <= PUSH; wb <= cs; fnext <= INSTR; end
                4: begin s2 <= 5;   fn <= PUSH;  wb <= ip; fnext <= INSTR; end
                5: begin ip <= op1; fn <= START; cs <= op2;  end

            endcase
            8'b1100_010x: case (s2)         // LES|LDS r,m

                0: begin

                    s2 <= 1;
                    ea <= ea + 2;

                end
                1: begin s2 <= 2; wb[7:0] <= in;  ea <= ea + 1; end
                2: begin

                    fn <= WBACK;
                    wb <= op2;

                    if (opcode[0])
                         ds <= {in, wb[7:0]};
                    else es <= {in, wb[7:0]};

                end

            endcase
            8'b1000_1111: case (s2)         // POP rm

                0: begin s2 <= 1; fn <= MODRM; cpen  <= 0; dir <= 0; end
                1: begin cp <= 1; fn <= WBACK; fnext <= START; end

            endcase
            8'b0110_10x0: case (s2)         // PUSH i

                0: begin s2 <= opcode[1] ? 2 : 1; wb       <= signex; ip <= ip + 1; end
                1: begin s2 <= 2;                 wb[15:8] <= in;     ip <= ip + 1; end
                2: begin fn <= PUSH; fnext <= START; end

            endcase
            8'b1101_0111: begin             // XLATB

                fn      <= START;
                ax[7:0] <= in;

            end
            8'b1100_1101: begin             // INT i

                fn      <= INTR;
                intr    <= in;
                ip      <= ip + 1;

            end
            8'b1100_000x,
            8'b1101_00xx: case (s2)         // Grp#2 Сдвиги

                // Выбор второго операнда
                // Если тут был указатель на память, то сбросить его
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
                    else begin wb <= op1; cp <= 1; fn <= WBACK; end

                    op2 <= op2 - 1;

                end

            endcase
            8'b1110_x10x: case (s2)         // IN a,p

                // Чтение номера порта
                0: begin

                    s2     <= 1;
                    cpen   <= 0;
                    port_a <= opcode[3] ? dx : in;
                    if (!opcode[3]) ip <= ip + 1;

                end

                // Чтение, ожидание результата 1 такт
                1: begin s2 <= 2; port_r <= 1; end
                2: begin s2 <= 3; end

                // Запись ответа в AL|AH
                3: begin

                    if (size) begin s2 <= 1; cpen <= 1; end
                    else fn <= START;

                    if (cpen)
                         ax[15:8] <= port_i;
                    else ax[ 7:0] <= port_i;

                    port_a <= port_a + 1;
                    size   <= 0;

                end

            endcase
            8'b1110_x11x: case (s2)         // OUT p,a

                0: begin

                    s2 <= 1;

                    port_a  <= opcode[3] ? dx : in;
                    port_o  <= ax[7:0];
                    port_w  <= 1;

                    if (!opcode[3]) ip <= ip + 1;
                    if (!size)      fn <= START;

                end
                1: begin

                    port_a  <= port_a + 1;
                    port_o  <= ax[15:8];
                    port_w  <= 1;
                    fn      <= START;

                end

            endcase
            8'b1111_011x: case (modrm[5:3]) // Grp#3

                // TEST imm8/16
                0, 1: case (s2)

                    0: begin s2 <= 1; cp <= 0; alu <= ALU_AND; end
                    1: begin s2 <= size ? 2 : 3; op2 <= in; ip <= ip + 1; end
                    2: begin s2 <= 3; op2[15:8] <= in; ip <= ip + 1; end
                    3: begin fn <= START; flags <= alu_f; end

                endcase

                // NOT rm
                2: begin wb <= ~op1; fn <= WBACK; end

                // NEG rm
                3: case (s2)

                    0: begin s2 <= 1; alu <= ALU_SUB; op2 <= op1; op1 <= 0; end
                    1: begin fn <= WBACK; wb <= alu_r; flags <= alu_f; end

                endcase

                // MUL, IMUL rm [IMUL знакорасширяется op1/op2]
                4, 5: case (s2)

                    0: begin

                        s2      <= 1;
                        op1     <= size ? op1 : {modrm[3] ? {8{op1[7]}} : 8'h00, op1[7:0]};
                        op2     <= size ? ax  : {modrm[3] ? {8{ ax[7]}} : 8'h00,  ax[7:0]};
                        imulw   <= modrm[3];

                    end
                    1: begin

                        fn <= START;

                        if (size) {dx, ax} <= mult[31:0]; else ax <= mult[15:0];
                        flags[ZF] <= multzf;
                        flags[CF] <= multcf;
                        flags[OF] <= multcf;

                    end

                endcase

                // DIV [op1, op2] Беззнаковое деление
                // IDIV Деление со знаком
                6, 7: case (s2)

                    // Запрос
                    0: begin

                        s2   <= 1;
                        fn   <= DIV;
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
                    1: begin

                        // #0 Overflow если в старшем слове или байте есть ненулевое значение
                        fn   <= (size ? diva[31:16] : diva[15:8]) ? INTR : START;
                        intr <= 0;

                        // Результат DIV или IDIV
                        if (size) {dx, ax} <= {sign ? -divr[15:0] : divr[15:0], sign ? -diva[15:0] : diva[15:0]};
                        else      ax       <= {sign ? -divr[ 7:0] : divr[ 7:0], sign ? -diva[ 7:0] : diva[ 7:0]};

                    end

                endcase

            endcase
            8'b1111_111x: case (modrm[5:3]) // Grp#4|5

                // INC|DEC rm
                0,
                1: case (s2)

                    0: begin s2 <= 1; op2 <= 1; alu <= modrm[3] ? ALU_SUB : ALU_ADD; end
                    1: begin fn <= WBACK; wb <= alu_r; flags <= alu_f; end

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
            // -----------------------------------------------------
            8'b1010_101x: case (s2)         // STOSx :: 2*+(2/1)*CX

                0: begin // STOSB

                    s2      <= 1;
                    out     <= ax[7:0];
                    segment <= es;
                    ea      <= di;
                    we      <= 1;
                    di      <= flags[DF] ? di - 1 : di + 1;

                    // Если это STOSB
                    if (size == 0) begin

                        s2  <= 0;
                        cx  <= cx - rep[1];
                        fn  <= repb ? INSTR : START;

                    end

                end
                1: begin // STOSW

                    s2      <= 0;
                    we      <= 1;
                    ea      <= ea + 1;
                    out     <= ax[15:8];
                    di      <= flags[DF] ? di - 1 : di + 1;
                    cx      <= cx - rep[1];
                    fn      <= repb ? INSTR : START;

                end

            endcase
            8'b1010_110x: case (s2)         // LODSx :: 3* или 4*

                0: begin

                    fn      <= size ? INSTR : START;
                    s2      <= 1;
                    ea      <= ea + 1;
                    si      <= flags[DF] ? ea-1-size : ea+1+size;
                    ax[7:0] <= in;

                end

                1: begin ax[15:8] <= in; fn <= START; end

            endcase
            8'b1010_010x: case (s2)         // MOVSx :: 2*+4/2*CX

                // Запись младшего байта [size=0]
                0: begin

                    s2  <= size ? 1 : 3;
                    wb  <= in;
                    out <= in;

                    if (size)  ea <= ea + 1;
                    else begin ea <= di; segment <= es; we <= 1; end

                end

                // Чтение старшего байта, запись младшего байта [size=1]
                1: begin

                    s2  <= 2;
                    wb  <= in;
                    we  <= 1;
                    ea  <= di;
                    out <= wb[7:0];
                    segment <= es;

                end

                // Запись старшего байта
                2: begin s2 <= 3; ea <= ea + 1; we <= 1; out <= wb[7:0]; end

                // Инкремент или декремент SI/DI, выключение записи
                3: begin

                    s2      <= 0;
                    we      <= 0;
                    segment <= op1;
                    ea      <= sinc;
                    si      <= sinc;
                    di      <= dinc;
                    fn      <= repb ? INSTR : START;
                    cx      <= cx - rep[1];

                end

            endcase
            8'b1010_011x: case (s2)         // CMPSx :: (3|5)*CX+2*

                // Чтение DS:SI
                0: begin

                    s2      <= size ? 1 : 2;
                    ea      <= size ? ea + 1 : di;
                    tmp16   <= segment;
                    segment <= size ? segment : es;
                    op1     <= in;

                end

                // Старший байт из SI+1
                1: begin s2 <= 2; op1[15:8] <= in; segment <= es; ea <= di; end

                // Чтение из ES:DI
                2: begin s2 <= size ? 3 : 4; op2 <= in; ea <= ea + 1; end
                3: begin s2 <= 4; op2[15:8] <= in; end

                // Сравнение и повтор цикла (если необходимо)
                4: begin

                    s2      <= 0;
                    ea      <= sinc;
                    si      <= sinc;
                    di      <= dinc;
                    flags   <= alu_f;
                    segment <= tmp16;
                    fn      <= repb && (rep[0] == alu_f[ZF]) ? INSTR : START;
                    cx      <= cx - rep[1];

                end

            endcase
            8'b1010_111x: case (s2)         // SCASx :: 2*+(2|3)*CX

                // Прочитать младший байт
                0: begin

                    s2  <= size ? 1 : 2;
                    op1 <= size ? ax : ax[7:0];
                    op2 <= in;
                    ea  <= ea + 1;

                end

                // Прочитать старший байт
                1: begin s2 <= 2; op2[15:8] <= in; di <= dinc; end

                // Сравнить A со значением из памяти
                2: begin

                    s2      <= 0;
                    flags   <= alu_f;
                    di      <= dinc;
                    ea      <= dinc;
                    fn      <= repb && (rep[0] == alu_f[ZF]) ? INSTR : START;
                    cx      <= cx - rep[1];

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
        WBACK: case (s1)

            // Выбор - регистр или память
            0: begin

                // reg-часть или rm:reg
                if (dir || modrm[7:6] == 2'b11) begin

                    cp <= 0;
                    s1 <= 0;
                    fn <= fnext;

                    case (dir ? modrm[5:3] : modrm[2:0])
                    REG_AX: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0];
                    REG_CX: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0];
                    REG_DX: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0];
                    REG_BX: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0];
                    REG_SP: if (size) sp <= wb; else ax[15:8] <= wb[7:0];
                    REG_BP: if (size) bp <= wb; else cx[15:8] <= wb[7:0];
                    REG_SI: if (size) si <= wb; else dx[15:8] <= wb[7:0];
                    REG_DI: if (size) di <= wb; else bx[15:8] <= wb[7:0];
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

        // Деление diva на divb; повторять op1 раз (количество сдвигов)
        // divr = 0 на старте и является остатком; diva это результат
        DIV: begin

            {divr, diva} <= {div4r, div4a};

            fn  <= op1 != 1 ? DIV : INSTR;
            op1 <= op1 - 1;

        end

    endcase

end

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

// Арифметико-логическое устройство
// ---------------------------------------------------------------------

wire [16:0] alu_r =

    alu == ALU_ADD ? op1 + op2 :
    alu == ALU_OR  ? op1 | op2 :
    alu == ALU_ADC ? op1 + op2 + flags[CF] :
    alu == ALU_SBB ? op1 - op2 - flags[CF] :
    alu == ALU_AND ? op1 & op2:
    alu == ALU_XOR ? op1 ^ op2:
                     op1 - op2; // SUB, CMP

wire [ 3:0] alu_top = size ? 15 : 7;
wire [ 4:0] alu_up  = alu_top + 1'b1;

wire is_add  = alu == ALU_ADD || alu == ALU_ADC;
wire is_lgc  = alu == ALU_XOR || alu == ALU_AND || alu == ALU_OR;
wire alu_cf  = alu_r[alu_up];
wire alu_af  = op1[4] ^ op2[4] ^ alu_r[4];
wire alu_sf  = alu_r[alu_top];
wire alu_zf  = (size ? alu_r[15:0] : alu_r[7:0]) == 0;
wire alu_pf  = ~^alu_r[7:0];
wire alu_of  = (op1[alu_top] ^ op2[alu_top] ^ is_add) & (op1[alu_top] ^ alu_r[alu_top]);

wire [11:0] alu_f = {
    /* OF  */ alu_of & ~is_lgc,
    /* DIT */ flags[10:8],
    /* SF  */ alu_sf,
    /* ZF  */ alu_zf,
    /* 5   */ 1'b0,
    /* AF  */ alu_af & ~is_lgc,
    /* 3   */ 1'b0,
    /* PF  */ alu_pf,
    /* 1   */ 1'b1,
    /* CF  */ alu_cf & ~is_lgc
};

// ---------------------------------------------------------------------
// Сдвиговый регистр
// ---------------------------------------------------------------------

reg [15:0] rot_r;
reg [11:0] rot_f;

always @* begin

    rot_f = flags;

    case (alu)
    ALU_ROL: rot_r = size ? {op1[14:0], op1[15]}   : {op1[6:0], op1[7]};
    ALU_ROR: rot_r = size ? {op1[0], op1[15:1]}    : {op1[0], op1[7:1]};
    ALU_RCL: rot_r = size ? {op1[14:0], flags[CF]} : {op1[6:0], flags[CF]};
    ALU_RCR: rot_r = size ? {flags[CF], op1[15:1]} : {flags[CF], op1[7:1]};
    ALU_SHL,
    ALU_SAL: rot_r = size ? {op1[14:0], 1'b0}    : {op1[6:0], 1'b0};
    ALU_SHR: rot_r = size ? {1'b0, op1[15:1]}    : {1'b0, op1[7:1]};
    ALU_SHR: rot_r = size ? {op1[15], op1[15:1]} : {op1[7], op1[7:1]};
    endcase

    // Флаг CF
    rot_f[CF] = alu[0] ? op1[0] : op1[alu_top];

    // Флаг OF
    case (alu)
    ALU_ROL,
    ALU_RCL,
    ALU_SAL,
    ALU_SHL: rot_f[OF] = op1[alu_top] ^ op1[alu_top - 1];
    ALU_ROR,
    ALU_RCR: rot_f[OF] = rot_r[alu_top] ^ rot_r[alu_top - 1];
    ALU_SHR: rot_f[OF] = op1[alu_top];
    ALU_SAR: rot_f[OF] = 1'b0;
    endcase

    // S, Z, P для 4 инструкции
    if (alu == ALU_SHL || alu == ALU_SHR || alu == ALU_SAL || alu == ALU_SHR) begin

        rot_f[SF] = rot_r[alu_top];
        rot_f[ZF] = (size ? rot_r[15:0] : rot_r[7:0]) == 0;
        rot_f[PF] = ~^rot_r[7:0];

    end

end

endmodule
