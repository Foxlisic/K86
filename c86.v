/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module c86
(
    input               clock,      // 25Мгц
    input               reset_n,    // =0 Сброс процессора
    input               ce,         // =1 Активация чипа
    // ----------------
    output      [19:0]  a,          // Адрес в общей памяти
    input       [ 7:0]  i,          // Данные из памяти
    output reg  [ 7:0]  o,          // Данные в память
    output reg          w,          // Запись в память
    // ----------------
    output reg  [15:0]  pa,         // Порт адрес
    input       [ 7:0]  pi,         // Входящие данные из порта
    output reg  [ 7:0]  po,         // Исходящие в порт данные
    output reg          pr,         // Сигнал на чтение из порта
    output reg          pw,         // Сигнал на запись в порт
    // ----------------
    output reg          halt,       // Остановка процессора
    output              m0          // Первый такт
);

assign m0 = (t == RUN) && (m == 0);
assign a  = cp ? {sgn,4'h0} + ea : {cs,4'h0} + ip;

`define TERM begin term <= 1; m <= 0; end
`define REG  modrm[5:3]

// Запись в Reg8, Reg16
`define W8   {dir, size} <= 2'b10; modrm[5:3]
`define W16  {dir, size} <= 2'b11; modrm[5:3]

// Если cpen=0, то выйти из процедуры считывания операндов
`define CPEN cp <= cpen; if (cpen == 0) begin m1 <= 0; t <= RUN; end

localparam

    RUN     = 0,
    MODRM   = 1,
    WB      = 2,
    PUSH    = 3,
    POP     = 4,
    INTR    = 5,
    DIV     = 6,
    UNDEF   = 7;

localparam CF  = 0, PF  = 2, AF  = 4, ZF  = 6, SF  = 7, TF  = 8, IF  = 9, DF  = 10, OF = 11;
localparam ADD = 0, OR  = 1, ADC = 2, SBB = 3, AND = 4, SUB = 5, XOR = 6, CMP = 7;
localparam ROL = 0, ROR = 1, RCL = 2, RCR = 3, SHL = 4, SHR = 5, SAL = 6, SAR = 7;

// Для того чтобы не использовать ES:
localparam FS  = 16'hA000, GS = 16'hB800;

// ---------------------------------------------------------------------
// Регистры общего назначения и сегментные
reg [15:0]  ax = 16'hDE0F, cx = 16'hBEEF, dx = 16'hBABE, bx = 16'hF00D,
            sp = 16'h50A0, bp = 16'hF1FA, si = 16'hFACE, di = 16'h0777;
reg [15:0]  es = 16'hFEBA, cs = 16'h0000, ss = 16'h1000, ds = 16'hDAEB;
reg [15:0]  ip = 16'h0000;
//                      0DIT SZ A  P C
reg [11:0]  flags = 12'b0000_0000_0010;
// ---------------------------------------------------------------------
reg         cp;                     // =1 Указатель на SGN:EA =0 Иначе CS:IP
reg         cpm;                    // =0 Устанавливается cp после MODRM
reg         size;                   // =1 16bit =0 8bit
reg         dir;                    // =0 rm,r; =1 r,rm
reg         term;                   // =1 Конец инструкции
reg         over;                   // =1 Сегмент переопределен
reg         cpen;                   // =0 То пропускает чтение операндов
reg [ 3:0]  t, next;                // Исполняемая команда в данный момент
reg [ 3:0]  m, m1;                  // Фаза исполнения m(T), m1(MODRM)
reg [ 2:0]  m2, m3, m4;             // Фаза исполнения m2(WB), m3(PUSH,POP), m4(INT)
reg [ 2:0]  alu;                    // Функция АЛУ или сдвигов
reg [ 7:0]  opcache, modrm;         // Кеш опкода
reg [ 7:0]  interrupt;              // Номер прерывания
reg [ 1:0]  rep;                    // Наличие REP:
reg [15:0]  sgn, ea;                // Выбранный SEGMENT:EA
reg [15:0]  op1, op2, wb, t16;      // Операнды; wb-что записывать
// ---------------------------------------------------------------------

wire [ 7:0] opcode  = m ? opcache : i;
wire        o1      = opcode[1];
wire [15:0] ipn     = ip + 1;
wire [15:0] sign    = {{8{i[7]}}, i};

// Мультиплексор на выбор регистров из диапазона [2:0]
wire [15:0] i20 =
    i[2:0] == 3'h0 ? (size ? ax : ax[ 7:0]) :
    i[2:0] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[2:0] == 3'h2 ? (size ? dx : dx[ 7:0]) :
    i[2:0] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[2:0] == 3'h4 ? (size ? sp : ax[15:8]) :
    i[2:0] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[2:0] == 3'h6 ? (size ? si : dx[15:8]) :
                     (size ? di : bx[15:8]);

// Мультиплексор на выбор регистров из диапазона [5:3]
wire [15:0] i53 =
    i[5:3] == 3'h0 ? (size ? ax : ax[ 7:0]) :
    i[5:3] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[5:3] == 3'h2 ? (size ? dx : dx[ 7:0]) :
    i[5:3] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[5:3] == 3'h4 ? (size ? sp : ax[15:8]) :
    i[5:3] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[5:3] == 3'h6 ? (size ? si : dx[15:8]) :
                     (size ? di : bx[15:8]);

// 16-битный регистр
wire [15:0] r16 =
    i[2:0] == 3'h0 ? ax : i[2:0] == 3'h1 ? cx :
    i[2:0] == 3'h2 ? dx : i[2:0] == 3'h3 ? bx :
    i[2:0] == 3'h4 ? sp : i[2:0] == 3'h5 ? bp :
    i[2:0] == 3'h6 ? si : di;

// ---------------------------------------------------------------------
// Базовое арифметическо-логическое устройство
// ---------------------------------------------------------------------

wire [16:0] ar =
    alu == ADD ? op1 + op2 :
    alu == ADC ? op1 + op2 + flags[CF] :
    alu == SBB ? op1 - op2 - flags[CF] :
    alu == AND ? op1 & op2 :
    alu == XOR ? op1 ^ op2 :
    alu == OR  ? op1 | op2 :
                 op1 - op2;

wire [3:0]  top = size ? 15 : 7;
wire        isa = alu == ADD || alu == ADC;
wire        isl = alu != AND && alu != OR && alu != XOR;

wire new_o = (op1[top] ^ op2[top] ^ isa) & (op1[top] ^ ar[top]);
wire new_s = ar[top];
wire new_z = 0 == (size ? ar[15:0] : ar[7:0]);
wire new_a = op1[4] ^ op2[4] ^ ar[4];
wire new_p = ~^ar[7:0];
wire new_c = ar[top + 1];

wire [11:0] af = {isl&new_o, flags[10:8], new_s, new_z, 1'b0, isl&new_a, 1'b0, new_p, 1'b1, isl&new_c};

// ---------------------------------------------------------------------
// Десятичная коррекция DAA, DAS, AAA, AAS
// ---------------------------------------------------------------------

wire        das   = opcode[3];
wire        daa_a = flags[AF] || ax[3:0] > 8'h09;
wire        daa_c = flags[CF] || ax[7:0] > 8'h9F || daa_t[8];
wire [ 8:0] daa_t = das ? (ax[7:0] - (daa_a ? 8'h06 : 0)) : (ax[7:0] + (daa_a ? 8'h06 : 0));
wire [ 7:0] daa   = das ? (daa_t   - (daa_c ? 8'h60 : 0)) : (daa_t   + (daa_c ? 8'h60 : 0));
wire [11:0] daa_f = {flags[11:8], daa[7], daa == 0, 1'b0, daa_a | flags[AF], 1'b0, ~^daa, 1'b1, daa_c | flags[CF]};
wire [ 3:0] aaa_a = das ? (ax[ 7:0] - (daa_a ? 8'h06 : 0)) : (ax[ 7:0] + (daa_a ? 8'h06 : 0));
wire [ 7:0] aaa_b = das ? (ax[15:8] - (daa_a ? 8'h01 : 0)) : (ax[15:8] + (daa_a ? 8'h01 : 0));

// Знаковое умножение это просто умножение обычное
reg         imulw;
wire [31:0] imul_r = op1 * op2;
wire        imul_o = |imul_r[31:16];
wire        imul_z =  imul_r[15:0] == 0;

// ---------------------------------------------------------------------
// УСЛОВИЯ
// ---------------------------------------------------------------------

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

wire [15:0] sinc = flags[DF] ? si - (size ? 2 : 1) : si + (size ? 2 : 1);
wire [15:0] dinc = flags[DF] ? di - (size ? 2 : 1) : di + (size ? 2 : 1);

// Разрешение выполнения инструкции с REP: или без
wire        repa = (rep[1] && cx || rep[1] == 0);           // Начало исполнения
wire        repb = (rep[1] && cx != 1);                     // Продолжение исполения
wire [15:0] repc = (i[0] ? 2:1)*(rep[1] ? cx-1 : 0);        // Количество отступов для LODSx

// -----------------------------------------------------------------------------
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
    alu == SHR ? barr[top] :
    alu == SAR ? 1'b0 : barr[top-1] ^ barr[top];

// Флаг переноса CF после выполнения сдвига
wire rtcf =
    alu == ROL ? _rol[32] : alu == RCL ? _rcl[32] :
    alu == ROR ? _ror[0]  : alu == RCR ? _rcr[0] :
    alu == SHL ? _shl[16] : alu == SHR ? _shr[0] :
    alu == SAR ? _sar[0]  : 1'b0;

// SZP флаги
wire rtsf = rtfl ? barr[top] : flags[SF];
wire rtzf = rtfl ? (size ? barr[15:0] : barr[7:0]) == 0 : flags[ZF];
wire rtpf = rtfl ?  ~^barr[7:0] : flags[PF];

wire [11:0] barf = {rtof, flags[10:8], rtsf, rtzf, 1'b0, flags[AF], 1'b0, rtpf, 1'b1, rtcf};

// -----------------------------------------------------------------------------
// Модуль деления
// -----------------------------------------------------------------------------

reg         divs;
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
// -----------------------------------------------------------------------------


always @(posedge clock)
// Сброс процессора
if (reset_n == 0) begin

    t       <= RUN;              // Исполнение инструкции начинается сразу
    m       <= 0;
    cp      <= 0;                // Установить на CS:IP
    cs      <= 0;
    ip      <= 0;
    ea      <= 0;
    sgn     <= 0;
    rep     <= 0;
    w       <= 0;
    term    <= 1;
    over    <= 0;
    halt    <= 0;
    modrm   <= 0;

// Запуск выполнения команд процессора
end else if (ce) begin

    w    <= 0;
    pw   <= 0;

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
            cpm     <= 1;
            cpen    <= 1;
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

        8'b001xx110: case (m) // ### Префикс es/cs/ss/ds: [1T]
        0: begin over <= 1; case (i[4:3]) 0:sgn<=es; 1:sgn<=cs; 2:sgn<=ss; 3:sgn<=ds; endcase m <= 0; end
        endcase

        8'b0010x111: case (m) // ### Десятичная коррекция [1T]
        0: begin ax[7:0] <= daa; flags <= daa_f; `TERM; end
        endcase

        8'b0011x111: case (m) // ### ASCII коррекция [1T]
        0: begin ax <= {aaa_b, ax[7:4], aaa_a}; {flags[AF], flags[CF]} <= {daa_a, daa_a}; `TERM; end
        endcase

        8'b0100xxxx: case (m) // ### INC/DEC r16 [4T]
        0: begin ip <= ip; {dir, size} <= 2'b11; alu <= opcode[3] ? SUB : ADD; end
        1: begin ip <= ipn; op1 <= i20; op2 <= 1; m <= 2; end
        2: begin wb <= ar; `REG <= opcode[2:0]; t <= WB; flags <= {af[11:1], flags[CF]}; `TERM; end
        endcase

        8'b01010xxx: case (m) // ### PUSH r16 [5T]
        0: begin ip <= ip; size <= 1'b1; end
        1: begin ip <= ipn; wb <= i20; t <= PUSH; `TERM; end
        endcase

        8'b01011xxx: case (m) // ### POP r16 [6T]
        0: begin t <= POP; {size, dir} <= 2'b11; end
        1: begin t <= WB; `REG <= opcode[2:0]; `TERM; end
        endcase

        8'b01100000: case (m) // ### PUSHA [18T]
        0: begin ea <= sp; sgn <= ss; cp <= 1; end
        1: begin

            w   <= 1;
            m1  <= m1 + 1;
            ea  <= ea - 1;

            if (m1 == 15) begin m <= 2; m1 <= 0; end

            case (m1)
            0:  o <= ax[15:8];  1: o <= ax[7:0];
            2:  o <= cx[15:8];  3: o <= cx[7:0];
            4:  o <= dx[15:8];  5: o <= dx[7:0];
            6:  o <= bx[15:8];  7: o <= bx[7:0];
            8:  o <= sp[15:8];  9: o <= sp[7:0];
            10: o <= bp[15:8]; 11: o <= bp[7:0];
            12: o <= si[15:8]; 13: o <= si[7:0];
            14: o <= di[15:8]; 15: o <= di[7:0];
            endcase

        end
        2: begin cp <= 0; sp <= sp - 16; `TERM; end
        endcase

        8'b01100001: case (m) // ### POPA [18T]
        0: begin ea <= sp; sgn <= ss; cp <= 1; end
        1: begin

            m1  <= m1 + 1;
            ea  <= ea + 1;

            if (m1 == 15) begin m <= 2; m1 <= 0; end

            case (m1)
            0:  di[ 7:0] <= i;  1: di[15:8] <= i;
            2:  si[ 7:0] <= i;  3: si[15:8] <= i;
            4:  bp[ 7:0] <= i;  5: bp[15:8] <= i;
            6:  sp[ 7:0] <= i;  7: sp[15:8] <= i;
            8:  bx[ 7:0] <= i;  9: bx[15:8] <= i;
            10: dx[ 7:0] <= i; 11: dx[15:8] <= i;
            12: cx[ 7:0] <= i; 13: cx[15:8] <= i;
            14: ax[ 7:0] <= i; 15: ax[15:8] <= i;
            endcase

        end
        2: begin cp <= 0; sp <= ea; `TERM; end
        endcase

        8'b0110010x: case (m) // ### FS: GS: [1T]
        0: begin m <= 0; over <= 1; sgn <= i[0] ? GS : FS; end
        endcase

        8'b011010x0: case (m) // ### PUSH s8/u16 [5/6T]
        1: begin ip <= ipn; wb <= o1 ? sign : i; if (op1) begin t <= PUSH; `TERM; end else m <= 2; end
        2: begin ip <= ipn; wb[15:8] <= i; t <= PUSH; `TERM; end
        endcase

        8'b011010x1: case (m) // ### IMUL r16,rm,imm [7T+]
        0: begin {dir, size} <= 2'b11; t <= MODRM; end
        1: begin cp  <= 0;       m <= 2;  end
        2: begin op2 <= sign;    m <= 3 + o1; ip <= ipn; end
        3: begin op2[15:8] <= i; m <= 4;      ip <= ipn; end
        4: begin

            t  <= WB;
            wb <= imul_r[15:0];

            flags[CF] <= imul_o;
            flags[OF] <= imul_o;
            flags[ZF] <= imul_z;

            `TERM;

        end
        endcase

        8'b0111xxxx: case (m) // ### JCC short [1/2T]

            0: if (branch[i[3:1]] == i[0]) begin ip <= ip + 2; `TERM; end
            1: begin ip <= ip + 1 + sign; `TERM; end

        endcase

        8'b100000xx: case (m) // ### ALU GROUP [5*T]

            0: begin t <= MODRM; dir <= 0; cpm <= 0; end
            1: begin

                ip  <= ip + 1;
                alu <= `REG;
                op2 <= opcode[1:0] == 3 ? sign : i;
                m   <= opcode[1:0] == 1 ? 2 : 3;

            end
            2: begin m <= 3; op2[15:8] <= i; ip <= ip + 1; end
            3: begin m <= (alu == CMP ? RUN : WB); wb <= ar; flags <= af; `TERM; end

        endcase

        8'b1000010x: case (m) // ### TEST rm, r [3T+]

            0: begin t <= MODRM; alu <= AND; end
            1: begin flags <= af; `TERM; end

        endcase

        8'b1000011x: case (m) // ### XCHG r,rm [6*T]

            0: begin t <= MODRM; end
            1: begin t <= WB; wb <= op2; m <= 2; end
            2: begin t <= WB; wb <= op1; dir <= 0; `TERM; end

        endcase

        8'b100010xx: case (m) // ### MOV rm,r|r,rm [4*T]

            0: begin t <= MODRM; cpen <= i[1]; end
            1: begin t <= WB; wb <= op2; cp <= 1; `TERM; end

        endcase

        8'b10001100: case (m) // ### MOV rm, sreg

            0: begin t <= MODRM; cpen <= 0; {dir, size} <= 2'b01; end
            1: begin t <= WB; case (`REG) 0: wb <= es; 1: wb <= cs; 2: wb <= ss; 3: wb <= ds; endcase `TERM; end

        endcase

        8'b10001101: case (m) // ### LEA r, rm [4T+]

            0: begin t <= MODRM; cpen <= 0; {dir, size} <= 2'b11; end
            1: begin t <= WB; wb <= ea; `TERM; end

        endcase

        8'b10001110: case (m) // ### MOV sreg, rm

            0: begin t <= MODRM; {dir, size} <= 2'b11; end
            1: begin case (`REG) 0: es <= op2; 2: ss <= op2; 3: ds <= op2; endcase `TERM; end

        endcase

        8'b10001111: case (m) // ### POP rm

            0: begin t <= POP;   end
            1: begin t <= MODRM; m <= 2; cpen <= 0; dir <= 0; end
            2: begin t <= WB; cp <= 1; `TERM; end

        endcase

        8'b10010000,          // ### FWAIT
        8'b11110000,          // ### LOCK:
        8'b10011011: case (m) // ### NOP [1T]

            0: begin `TERM; end

        endcase

        8'b10010xxx: case (m) // ### 2T XCHG ax, r [2T]

            0: begin

                ax   <= r16;
                wb   <= ax;
                t    <= WB;
                `W16 <= opcode[2:0];
                `TERM;

            end

        endcase

        8'b10011000: case (m) // ### CBW

            0: begin ax <= {{8{ax[7]}}, ax[7:0]}; `TERM; end

        endcase

        8'b10011001: case (m) // ### CWD

            0: begin dx <= {16{ax[15]}}; `TERM; end

        endcase

        8'b10011010: case (m) // ### CALL FAR [13T]

            0: begin next <= RUN; end
            1: begin m <= 2; ip <= ip + 1; op1[ 7:0] <= i; end
            2: begin m <= 3; ip <= ip + 1; op1[15:8] <= i; end
            3: begin m <= 4; ip <= ip + 1; op2[ 7:0] <= i; end
            4: begin m <= 5; ip <= ip + 1; op2[15:8] <= i; t <= PUSH; wb <= cs; end
            5: begin m <= 6; wb <= ip;  t  <= PUSH; end
            6: begin `TERM;  ip <= op1; cs <= op2; end

        endcase

        8'b10011100: case (m) // ### PUSHF [4T]

            0: begin t <= PUSH; wb <= flags; `TERM; end

        endcase

        8'b10011101: case (m) // ### POPF [5T]

            0: begin t <= POP; end
            1: begin flags <= wb | 2; `TERM; end

        endcase

        8'b10011110: case (m) // ### SAHF [1T]

            0: begin flags <= ax[15:8]; `TERM; end

        endcase

        8'b10011111: case (m) // ### LAHF [1T]

            0: begin ax[15:8] <= flags[7:0] | 2; `TERM; end

        endcase

        8'b101000xx: case (m) // ### MOV a,[m] | [m],a

            // Прочесть адрес
            1: begin ea[ 7:0] <= i; ip <= ip + 1; m <= 2; end
            2: begin ea[15:8] <= i; ip <= ip + 1; m <= dir ? 3 : 6; cp <= 1; end

            // Запись A в память
            3: begin w <= 1; o <= ax[ 7:0]; m <= size ? 4 : 5; end
            4: begin w <= 1; o <= ax[15:8]; m <= 5; ea <= ea + 1; end
            5: begin `TERM; cp <= 0; end

            // Чтение A из памяти
            6: begin m <= 7; ax[ 7:0] <= i; ea <= ea + 1; if (!size) begin `TERM; cp <= 0; end end
            7: begin `TERM;  ax[15:8] <= i; cp <= 0; end

        endcase

        8'b1010100x: case (m) // ### TEST a, i [4*T]

            0: begin alu <= AND; op1 <= opcode[0] ? ax : ax[7:0]; end
            1: begin ip <= ip + 1; op2       <= i; m <= size ? 2 : 3; end
            2: begin ip <= ip + 1; op2[15:8] <= i; m <= 3; end
            3: begin flags <= af; `TERM; end

        endcase

        8'b1010010x: case (m) // ### MOVSx [2*+4/2*CX]

            1: begin

                m   <= 2;
                cp  <= repa;
                op1 <= sgn;
                ea  <= si;

                if (!repa) begin `TERM; end

            end

            // Запись младшего байта [size=0]
            2: begin

                m   <= size ? 3 : 5;
                wb  <= i;
                o   <= i;

                if (size)  ea <= ea + 1;
                else begin ea <= di; sgn <= es; w <= 1; end

            end

            // Чтение старшего байта, запись младшего байта [size=1]
            3: begin

                m   <= 4;
                wb  <= i;
                w   <= 1;
                ea  <= di;
                o   <= wb[7:0];
                sgn <= es;

            end

            // Запись старшего байта
            4: begin t <= 5; ea <= ea + 1; w <= 1; o <= wb[7:0]; end

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

        8'b1010011x: case (m) // ### CMPSx :: (3|5)*CX+2*

            1: begin

                m   <= 2;
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
            3: begin m <= 4; op1[15:8] <= i; sgn <= es; ea <= di; end

            // Чтение из ES:DI
            4: begin m <= size ? 5 : 6; op2 <= i; ea <= ea + 1; end
            5: begin m <= 6; op2[15:8] <= i; end

            // Сравнение и повтор цикла (если необходимо)
            6: begin

                m       <= 2;
                ea      <= sinc;
                si      <= sinc;
                di      <= dinc;
                flags   <= af;
                sgn     <= t16;
                cx      <= cx - rep[1];

                if (!(repb && (rep[0] == af[ZF]))) begin `TERM; cp <= 0; end

            end

        endcase

        8'b1010101x: case (m) // ### STOSx :: 3+(2/1)*CX

            1: begin m <= 2; cp <= repa; if (!repa) begin `TERM; end end
            2: begin // STOSB

                m   <= size ? 3 : 2;
                o   <= ax[7:0];
                sgn <= es;
                ea  <= di;
                w   <= 1;
                di  <= flags[DF] ? di - 1 : di + 1;

                if (!size) begin cx <= cx - rep[1]; if (!repb) t <= 4; end

            end
            3: begin // STOSW

                m   <= repb ? 2 : 4;
                w   <= 1;
                ea  <= ea + 1;
                o   <= ax[15:8];
                di  <= flags[DF] ? di - 1 : di + 1;
                cx  <= cx - rep[1];

            end

            4: begin cp <= 0; `TERM; end

        endcase

        8'b1010110x: case (m) // ### LODSx :: 3*

            1: begin

                m  <= 2;
                cp <= repa;
                ea <= flags[DF] ? si - repc : si + repc;

                if (!repa) begin `TERM; end

            end

            2: begin

                m       <= 3;
                ea      <= ea + 1;
                si      <= flags[DF] ? ea-1-size : ea+1+size;
                ax[7:0] <= i;

                if (!size) begin `TERM; end

            end

            3: begin ax[15:8] <= i; `TERM; cp <= 0; end

        endcase

        8'b1010111x: case (m) // ### SCASx :: 2*+(2|3)*CX

            1: begin

                m   <= 2;
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
            3: begin m <= 4; op2[15:8] <= i; di <= dinc; end

            // Сравнить A со значением из памяти
            4: begin

                t       <= 2;
                flags   <= af;
                di      <= dinc;
                ea      <= dinc;
                cx      <= cx - rep[1];

                if (!(repb && (rep[0] == af[ZF]))) begin `TERM; cp <= 0; end

            end

        endcase

        8'b1011xxxx: case (m) // ### MOV r,i [3*T]

            1: begin ip <= ip + 1; wb <= i; m <= 2; if (!opcode[3]) begin t <= WB; `W8 <= opcode[2:0]; `TERM; end end
            2: begin ip <= ip + 1; wb[15:8] <= i; t <= WB; `W16 <= opcode[2:0]; `TERM; end

        endcase

        8'b1100000x: case (m) // ### {ROT} rm, i

            0: begin t <= MODRM; dir <= 0; cpm <= 0; end
            1: begin m <= 2; op2 <= i; ip <= ip + 1; alu <= modrm[5:3]; end
            2: begin t <= WB; wb <= barr; flags <= barf; `TERM; end

        endcase

        8'b1100001x: case (m) // ### RET; RET imm [5/7T]

            0: begin t <= POP; m <= opcode[0] ? 3 : 1; t16 <= 0; end
            1: begin m <= 2; t16[ 7:0] <= i; ip <= ip + 1; end
            2: begin m <= 3; t16[15:8] <= i; end
            3: begin ip <= wb; sp <= sp + t16; `TERM; end

        endcase

        8'b1100010x: case (m) // ### LES|LDS r,m

            0: begin t <= MODRM; {dir, size} <= 2'b11; end
            1: begin m <= 2; ea <= ea + 2; end
            2: begin m <= 3; ea <= ea + 1; wb[7:0] <= i; end
            3: begin t <= WB; wb <= op2; if (opcode[0]) ds <= {i, wb[7:0]}; else es <= {i, wb[7:0]}; `TERM; end

        endcase

        8'b1100011x: case (m) // ### MOV rm, i

            0: begin t <= MODRM; {cpm, cpen, dir} <= 0; end
            1: begin wb <= i; ip <= ip + 1; if (size) m <= 2; else begin t <= WB; `TERM; end end
            2: begin wb[15:8] <= i; ip <= ip + 1; t <= WB; `TERM; end

        endcase

        8'b1100101x: case (m) // ### RETF; RETF i16

            0: begin t <= POP; end
            1: begin t <= POP; m  <= 2;  op1 <= wb;  op2 <= i; ip <= ip + 1; end
            2: begin `TERM;    cs <= wb; ip  <= op1; if (!opcode[0]) sp <= sp + {i, op2[7:0]}; end

        endcase

        8'b110011x0: case (m) // ### INT 3; INTO

            0: begin

                t <= (i[1] && flags[OF]) || !i[1] ? INTR : RUN;
                interrupt <= i[1] ? 4 : 3;
                `TERM;

            end

        endcase

        8'b11001101: case (m) // ### INT i

            1: begin t <= INTR; interrupt <= i; ip <= ip + 1; `TERM; end

        endcase

        8'b11001111: case (m) // ### IRET

            0: begin t <= POP; end
            1: begin t <= POP; m <= 2; ip <= wb; end
            2: begin t <= POP; m <= 3; cs <= wb; end
            3: begin `TERM; flags <= wb[11:0] | 2; end

        endcase

        8'b110100xx: case (m) // ### {ROT} rm, (1|cl)

            0: begin t <= MODRM; dir <= 0; end
            1: begin m <= 2; alu <= modrm[5:3]; op2 <= opcode[1] ? cx[7:0] : 1; end
            2: begin t <= WB; wb <= barr; flags <= barf; `TERM; end

        endcase

        8'b11010110: case (m) // ### SALC 1T

            0: begin ax[7:0] <= {8{flags[CF]}}; `TERM; end

        endcase

        8'b11010111: case (m) // ### XLATB

            0: begin ea <= bx; cp <= 1; end
            1: begin ax[7:0] <= i; cp <= 0; `TERM; end

        endcase

        8'b11011xxx: case (m) // ### {FPU}

            0: begin t <= MODRM; {cpen, dir, size, cpm} <= 4'b0; `TERM; end

        endcase

        8'b1110000x,
        8'b11100010: case (m) // ### LOOP(NZ|Z)

            0: begin

                cx <= cx - 1;
                if (cx == 1 || (!i[1] && flags[ZF] ^ i[0])) begin ip <= ip + 2; `TERM; end

            end
            1: begin ip <= ip + 1 + sign; `TERM; end

        endcase

        8'b11100011: case (m) // ### JCXZ x

            0: begin if (cx) begin ip <= ip + 2; `TERM; end end
            1: begin ip <= ip + 1 + sign; `TERM; end

        endcase

        8'b1110x10x: case (m) // ### IN a,p 3/4T*

            0: begin m <= i[3] ? 2 : 1; pa <= dx; pr <= i[3]; end
            1: begin m <= 2; pr <= 1; pa <= i; ip <= ip + 1; end
            2: begin m <= 3; pr <= 1; pa <= size ? pa + 1 : pa; end
            3: begin m <= 4; ax[7:0] <= pi; if (size == 0) begin `TERM; end end
            4: begin ax[15:8] <= pi; `TERM; end

        endcase

        8'b1110x11x: case (m) // ### OUT p,a 2/3T

            1: begin

                m <= 2;

                pa  <= opcode[3] ? dx : i;
                po  <= ax[7:0];
                pw  <= 1;

                if (!opcode[3]) ip <= ip + 1;
                if (!size) begin `TERM; end

            end
            2: begin

                pa  <= pa + 1;
                po  <= ax[15:8];
                pw  <= 1;
                `TERM;

            end

        endcase

        8'b11101000: case (m) // ### CALL b16 6T

            1: begin m <= 2;    ip <= ip + 1; ea <= i; end
            2: begin t <= PUSH; wb <= ip + 1; ip <= ip + 1 + {i, ea[7:0]}; `TERM; end

        endcase

        8'b11101001: case (m) // ### JMP o16 3T

            1: begin ea <= i; ip <= ip + 1; m <= 2; end
            2: begin ip <= ip + 1 + {i, ea[7:0]}; `TERM; end

        endcase

        8'b11101010: case (m) // ### JMP far 5T

            // Прочитаьть 4 байта для нового CS:IP
            1: begin ip <= ip + 1; m <= 2; ea       <= i; end
            2: begin ip <= ip + 1; m <= 3; ea[15:8] <= i; end
            3: begin ip <= ip + 1; m <= 4; op1      <= i; end
            4: begin ip <= ea;     cs <= {i, op1[7:0]}; `TERM; end

        endcase

        8'b11101011: case (m) // ### JMP b 2T

            1: begin ip <= ip + sign + 1; `TERM; end

        endcase

        8'b11110001: case (m) // ### INT 1

            0: begin t <= INTR; interrupt <= 1; `TERM; end

        endcase

        8'b1111001x: case (m) // ### REPNZ, REPZ

            0: begin m <= 0; rep <= i[1:0]; end

        endcase

        8'b11110100: case (m) // ### 1T HLT -- Остановка процессора

            0: begin ip <= ip; halt <= 1; `TERM; end

        endcase

        8'b11110101: case (m) // ### CMC

            0: begin flags[CF] <= ~flags[CF]; `TERM; end

        endcase

        8'b1111100x: case (m) // ### CLC, STC

            0: begin flags[CF] <= i[0]; `TERM; end

        endcase

        8'b1111101x: case (m) // ### CLI, STI

            0: begin flags[IF] <= i[0]; `TERM; end

        endcase

        8'b1111110x: case (m) // ### CLD, STD

            0: begin flags[DF] <= i[0]; `TERM; end

        endcase

        8'b1111011x: case (m) // ### GROUP #3 rm, op [F6-F7]

            // Запрос операндов
            0: begin t <= MODRM; cpm <= 0; dir <= 1'b0; end

            // Исполнение инструкции
            default: case (`REG)

                // 5T+ TEST imm8/16
                0, 1: case (m)

                    1: begin m  <= 2; alu <= AND; end
                    2: begin ip <= ip + 1; op2[15:0] <= i; m <= size ? 3 : 4; end
                    3: begin ip <= ip + 1; op2[15:8] <= i; m <= 4; end
                    4: begin flags <= af; `TERM; end

                endcase

                // 4T+ NOT rm
                2: begin wb <= ~op1; t <= WB; `TERM; end

                // 5T+ NEG rm
                3: case (m)

                    1: begin m <= 2; alu <= SUB; op2 <= op1; op1 <= 0; end
                    2: begin t <= WB; wb <= ar; flags <= af; `TERM; end

                endcase

                // 4T+ MUL, IMUL rm [IMUL знакорасширяется op1/op2]
                4, 5: case (m)

                    1: begin

                        m       <= 2;
                        op1     <= size ? op1 : {modrm[3] ? {8{op1[7]}} : 8'h00, op1[7:0]};
                        op2     <= size ? ax  : {modrm[3] ? {8{ ax[7]}} : 8'h00,  ax[7:0]};
                        imulw   <= modrm[3];

                    end
                    2: begin

                        if (size) {dx, ax} <= imul_r[31:0]; else ax <= imul_r[15:0];

                        flags[ZF] <= imul_z;
                        flags[CF] <= imul_o;
                        flags[OF] <= imul_o;

                        `TERM;

                    end

                endcase

                // DIV [op1, op2] Беззнаковое деление
                // IDIV Деление со знаком
                6, 7: case (m)

                    // Запрос
                    1: begin

                        m    <= 2;
                        t    <= DIV;
                        divr <= 0;
                        op1  <= size ? 8 : 4;

                        if (modrm[3]) begin

                            divs <= divi[31] ^ op1[size ? 15 : 7];
                            diva <= divi[31] ? -divi : divi;
                            divb <= size ? (op1[15] ? -op1 : op1) : (op1[7] ? -op1[7:0] : op1[7:0]);

                        end else begin

                            divs <= 0;
                            diva <= divi;
                            divb <= op1;

                        end

                    end

                    // Результат
                    2: begin

                        // #0 Overflow если в старшем слове или байте есть ненулевое значение
                        t <= (size ? diva[31:16] : diva[15:8]) ? INTR : RUN;
                        interrupt <= 0;

                        // Результат DIV или IDIV
                        if (size) {dx, ax} <= {sign ? -divr[15:0] : divr[15:0], sign ? -diva[15:0] : diva[15:0]};
                        else      ax       <= {sign ? -divr[ 7:0] : divr[ 7:0], sign ? -diva[ 7:0] : diva[ 7:0]};

                        `TERM;

                    end

                endcase

            endcase

        endcase

        8'b1111111x: case (m) // ### GROUP #4 rm, op [FE-FF]

            // Запрос операндов
            0: begin t <= MODRM; cpm <= 0; dir <= 1'b0; end

            // Исполнение инструкции
            default: case (`REG)

                // 5T+ INC|DEC rm
                0, 1: case (m)

                    1: begin m <= 2; op2 <= 1; alu <= modrm[3] ? SUB : ADD; end
                    2: begin t <= WB; wb <= ar; flags <= af; `TERM; end

                endcase

                // CALL rm
                2: begin

                    ip <= op1;
                    wb <= ip;
                    t  <= size ? PUSH : UNDEF;
                    `TERM;

                end

                // CALL far rm
                3: case (m)

                    1: begin m <= 2;    ea <= ea + 2; ip <= op1; op1 <= ip; op2 <= cs; if (size == 0) t <= UNDEF; end
                    2: begin m <= 3;    ea <= ea + 1; wb <= i; end
                    3: begin m <= 4;    t <= PUSH; cs <= {i, wb[7:0]}; wb <= op2; end
                    4: begin wb <= op1; t <= PUSH; `TERM; end

                endcase

                // 3T+ JMP rm
                4: begin ip <= op1; `TERM; if (size == 0) t <= UNDEF; end

                // 7T+ JMP far rm
                5: case (m)

                    1: begin m <= 2; ea <= ea + 2; ip <= op1; if (size == 0) t <= UNDEF; end
                    2: begin m <= 3; ea <= ea + 1; wb <= i; end
                    3: begin cs <= {i, wb[7:0]}; `TERM; end

                endcase

                // PUSH rm
                6: begin t <= PUSH; wb <= op1; `TERM; end
                7: begin t <= UNDEF; end

            endcase

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
            8'b00_xxx_xxx: begin m1 <= 4; `CPEN; end // Читать операнд
            8'b01_xxx_xxx: begin m1 <= 1; end // DISP8
            8'b10_xxx_xxx: begin m1 <= 2; end // DISP16
            8'b11_xxx_xxx: begin m1 <= 0; t <= RUN; end // Регистры. Вернуться к RUN
            endcase

            // Проставить сегмент SS: там где есть упоминания BP
            if (!over && ((^i[7:6] && i[2:0] == 3'b110) || i[2:1] == 2'b01)) sgn <= ss;

        end

        // DISP8
        1: begin m1 <= 4; ip <= ipn; ea <= ea + sign;       `CPEN; end
        2: begin m1 <= 3; ip <= ipn; ea <= ea + {8'h00, i}; end
        3: begin m1 <= 4; ip <= ipn; ea <= ea + {i, 8'h00}; `CPEN; end

        // Чтение 8-битный операнд
        4: begin

            if (dir) op2 <= i; else op1 <= i;
            if (size) begin m1 <= 5; ea <= ea + 1; end else begin m1 <= 0; cp <= cpm; t <= RUN; end

        end

        // Читать 16-битный операнд
        5: begin

            if (dir) op2[15:8] <= i; else op1[15:8] <= i;

            t  <= RUN;
            m1 <= 0;
            cp <= cpm;
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
    2: begin m3 <= 0; wb[15:8] <= i; cp <= 0; t <= next; end
    endcase

    // -------------------------------------------------------------
    // Прерывание interrupt; считается за выполнение инструкции
    // -------------------------------------------------------------
    INTR: case (m4)
    0: begin m4 <= 1; t <= PUSH; wb <= flags; next <= INTR; end
    1: begin m4 <= 2; t <= PUSH; wb <= cs; end
    2: begin m4 <= 3; t <= PUSH; wb <= ip; end
    3: begin m4 <= 4; ea <= {interrupt, 2'b00}; sgn <= 0; cp <= 1; end
    4: begin m4 <= 5; ip[ 7:0] <= i; ea <= ea + 1; end
    5: begin m4 <= 6; ip[15:8] <= i; ea <= ea + 1; end
    6: begin m4 <= 7; cs[ 7:0] <= i; ea <= ea + 1; end
    7: begin m4 <= 0; cs[15:8] <= i; cp <= 0; t <= RUN; flags[IF] <= 1'b0; end
    endcase

    // -------------------------------------------------------------
    // Деление diva на divb; повторять op1 раз (количество сдвигов)
    // divr = 0 на старте и является остатком; diva это результат
    // -------------------------------------------------------------
    DIV: begin

        {divr, diva} <= {div4r, div4a};
        t   <= op1 != 1 ? DIV : RUN;
        op1 <= op1 - 1;

    end

    endcase

end

endmodule
