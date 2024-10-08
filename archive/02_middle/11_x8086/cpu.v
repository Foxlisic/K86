module cpu(

    input   wire        clk,            // 25 Mhz
    input   wire        lock,           // Memory Locked?
    output  wire [19:0] o_addr,         // Адрес на чтение, 1 Мб
    input   wire [7:0]  i_data,         // Входящие данные
    output  reg  [7:0]  o_data,         // Исходящие данные
    output  reg         o_write         // Запрос на запись

);

// ---------------------------------------------------------------------
`define OPCODE_DECODER      3'h0
`define MODRM_DECODE        3'h1
`define OPCODE_EXEC         3'h2
`define WRITE_BACK_MODRM    3'h3
// ---------------------------------------------------------------------
`define CARRY               0
`define PARITY              2
`define AUX                 4
`define ZERO                6
`define SIGN                7
`define TRAP                8
`define INTERRUPT           9
`define DIRECTION           10
`define OVERFLOW            11
// ---------------------------------------------------------------------

assign o_addr = memory? {ms, 4'b000} + ma : {cs, 4'b000} + ip;

// ---------------------------------------------------------------------
// Все регистры - сегментные, флаги, ip
reg [15:0] ax; reg [15:0] cx; reg [15:0] dx; reg [15:0] bx;
reg [15:0] sp; reg [15:0] bp; reg [15:0] si; reg [15:0] di;
reg [15:0] es; reg [15:0] cs; reg [15:0] ss; reg [15:0] ds;
reg [15:0] ip; reg [11:0] fl;

// Инициализируем
initial begin

    ax = 16'h1041; bx = 16'h0001; cx = 16'h0006; dx = 16'h0000;
    sp = 16'h0012; bp = 16'h5000; si = 16'h0010; di = 16'h0020;
    es = 16'h2377; cs = 16'hFC00; ss = 16'h0000; ds = 16'h0000;
    ip = 16'h0000;
    //       ODITSZ-A-P-C
    fl = 12'b000001000000;

    o_write = 1'b0;
    o_data  = 8'h00;

end
// ---------------------------------------------------------------------

// Машинное состояния. Это не микрокод.
reg [2:0]   m = 3'b0;
reg [3:0]   mcode = 1'b0;
reg [2:0]   modm_stage = 1'b0;
reg [7:0]   modrm = 8'h00;
reg [7:0]   opcode = 8'h00;

// wide =0 (byte), =1 (word)
reg         wide = 1'b0;

// =0 rm, reg
// =1 reg, rm
reg         direct = 1'b0;
reg [15:0]  op1 = 1'b0;
reg [15:0]  op2 = 1'b0;
reg [ 7:0]  hibyte = 1'b0;

reg [1:0]   wbmcode = 1'b0;
reg [15:0]  wb_data = 1'b0;
reg [15:0]  tmpdata = 1'b0;

// режим АЛУ
reg [2:0]   alu = 1'b0;
reg [16:0]  result;
reg [11:0]  rflags;

// Используется для указателя на память [mm_seg : mm_addr]
reg         memory = 1'b0;
reg [15:0]  ms = 1'b0;
reg [15:0]  ma = 1'b0;

// При сканировании опкода, если попался префикс, то он записывается сюда
reg [1:0]   prefix_id = 2'b00;

// Если равен 1, значит, инструкция имеет префикс
reg prefix     = 1'b0;
reg repnz      = 1'b0;
reg repz       = 1'b0;
reg prefix_tmp = 1'b0;
reg lock_tmp   = 1'b0;
reg repnz_tmp  = 1'b0;
reg repz_tmp   = 1'b0;

// относительный переход (8 бит)
wire [15:0] ip_rel8 = ip + {{8{i_data[7]}}, i_data[7:0]} + 1'b1;
wire [15:0] ip_next = ip + 1'b1;

always @(posedge clk) begin

    // Декодирование опкода либо полное/частичное исполнение
    if (m == `OPCODE_DECODER) begin

        // Стадия декодера ModRM
        modm_stage  <= 1'b0;
        opcode      <= i_data;
        mcode       <= 1'b0;
        wbmcode     <= 1'b0;
        wb_data     <= 1'b0;

        // Декодирование префиксов
        casex (i_data)

            // 26, 2e, 36, 3e (es: cs: ss: ds:)
            8'b001x_x110: begin

                prefix_tmp <= 1'b1;
                prefix_id  <= i_data[4:3];

            end

            // LOCK: это вообще не нужная вещь
            8'b1111_0000: begin lock_tmp <= 1'b1; end
            8'b1111_0010: begin repnz_tmp <= 1'b1; end
            8'b1111_0011: begin repz_tmp <= 1'b1; end

            // Это реальный опкод, удаляем временные префиксы, перенося
            // данные о наличии префикса далее, в саму инструкцию

            default: begin

                prefix      <= prefix_tmp;
                repnz       <= repnz_tmp;
                repz        <= repz_tmp;
                prefix_tmp  <= 1'b0;
                lock_tmp    <= 1'b0;
                repnz_tmp   <= 1'b0;
                repz_tmp    <= 1'b0;

            end

        endcase

        // Декодер реальных опкодов
        casex (i_data)

            // <ALU> ModRM
            // MOV ModrM
            8'b00xx_x0xx,
            8'b1000_10xx: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= i_data[1];
                alu     <= opcode[5:3];

            end

            // <ALU> al/ax, i8/16
            8'b00xx_x10x: begin

                m       <= `OPCODE_EXEC;
                alu     <= opcode[5:3];
                op1     <= i_data[0] ? ax : ax[7:0];

            end

            // MOV rm16, sreg
            // MOV sreg, rm16
            // LEA r16, rm
            8'b1000_11x0,
            8'b1000_1101: begin

                m       <= `MODRM_DECODE;
                wide    <= 1'b1;
                direct  <= 1'b0;

            end

            // ModRM=<ALU>, r/m
            8'b1000_00xx: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= 1'b0;

            end

            // PUSH seg | r16 | PUSHF
            8'b000x_x110,
            8'b0101_0xxx,
            8'b1001_1100: begin

                m       <= `OPCODE_EXEC;
                ms      <= ss;
                ma      <= sp - 2'h2;
                sp      <= sp - 2'h2;
                memory  <= 1'b1;
                o_write <= 1'b1;

                // PUSHF
                if (i_data[7]) begin

                    o_data <= fl[7:0];
                    hibyte <= {4'b0000, fl[11:8]};

                end

                // PUSH r16
                else if (i_data[6])

                    case (i_data[2:0])

                        3'b000: begin o_data <= ax[7:0]; hibyte <= ax[15:8]; end
                        3'b001: begin o_data <= cx[7:0]; hibyte <= cx[15:8]; end
                        3'b010: begin o_data <= dx[7:0]; hibyte <= dx[15:8]; end
                        3'b011: begin o_data <= bx[7:0]; hibyte <= bx[15:8]; end
                        3'b100: begin o_data <= sp[7:0]; hibyte <= sp[15:8]; end
                        3'b101: begin o_data <= bp[7:0]; hibyte <= bp[15:8]; end
                        3'b110: begin o_data <= si[7:0]; hibyte <= si[15:8]; end
                        3'b111: begin o_data <= di[7:0]; hibyte <= di[15:8]; end

                    endcase

                else

                    case (i_data[4:3])

                        2'b00: begin o_data <= es[7:0]; hibyte <= es[15:8]; end
                        2'b01: begin o_data <= cs[7:0]; hibyte <= cs[15:8]; end
                        2'b10: begin o_data <= ss[7:0]; hibyte <= ss[15:8]; end
                        2'b11: begin o_data <= ds[7:0]; hibyte <= ds[15:8]; end

                    endcase

            end

            // POP seg | r16 | POPF | IRET
            8'b000x_x111,
            8'b0101_1xxx,
            8'b1001_1101,
            8'b1100_1111: begin

                m       <= `OPCODE_EXEC;
                ms      <= ss;
                ma      <= sp;
                sp      <= sp + (i_data == 8'hCF ? 3'h6 : 2'h2);
                memory  <= 1'b1;

            end

            // SAHF, LAHF
            8'b1001_1110: fl[7:0] <= ax[15:8];
            8'b1001_1111: ax[15:8] <= fl[7:0];

            // INC/DEC r16
            8'b0100_xxxx: begin

                case (i_data[2:0])

                    3'b000: op1 <= i_data[3] ? ax - 1'b1 : ax + 1'b1;
                    3'b001: op1 <= i_data[3] ? cx - 1'b1 : cx + 1'b1;
                    3'b010: op1 <= i_data[3] ? dx - 1'b1 : dx + 1'b1;
                    3'b011: op1 <= i_data[3] ? bx - 1'b1 : bp + 1'b1;
                    3'b100: op1 <= i_data[3] ? sp - 1'b1 : sp + 1'b1;
                    3'b101: op1 <= i_data[3] ? bp - 1'b1 : bp + 1'b1;
                    3'b110: op1 <= i_data[3] ? si - 1'b1 : si + 1'b1;
                    3'b111: op1 <= i_data[3] ? di - 1'b1 : di + 1'b1;

                endcase

                m <= `OPCODE_EXEC;

            end

            // J<ccc>
            8'b0111_xxxx: m <= `OPCODE_EXEC;

            // XCHG ax, r16
            8'b1001_0xxx: begin

                case (i_data[2:0])

                    3'b001: begin ax <= cx; cx <= ax; end
                    3'b010: begin ax <= dx; dx <= ax; end
                    3'b011: begin ax <= bx; bx <= ax; end
                    3'b100: begin ax <= sp; sp <= ax; end
                    3'b101: begin ax <= bp; bp <= ax; end
                    3'b110: begin ax <= si; si <= ax; end
                    3'b111: begin ax <= di; di <= ax; end

                endcase

            end

            // MOV r8/16, i8/16
            8'b1011_xxxx: m <= `OPCODE_EXEC;

            // MOV al/ax, [m16]
            // MOV [m16], al/ax
            8'b1010_00xx: m <= `OPCODE_EXEC;

            // TEST rm, r8/16
            8'b1000_010x: begin

                m       <= `MODRM_DECODE;
                direct  <= 1'b0;
                wide    <= i_data[0];
                alu     <= 3'b100; // AND
                op2     <= i_data[0] ? ax : ax[7:0];

            end

            // TEST al/ax, i8/16
            8'b1010_100x: begin

                alu  <= 3'b100;
                wide <= i_data[0];
                op1  <= i_data[0] ? ax : ax[7:0];
                m    <= `OPCODE_EXEC;

            end

            // CBW / CWD
            8'b1001_1000: ax[15:8] <= {8{ax[7]}};
            8'b1001_1001: dx[15:0] <= {16{ax[15]}};
            // CLC, STC
            8'b1111_100x: fl[ `CARRY ] <= i_data[0];
            // CLI, STI
            8'b1111_101x: fl[ `INTERRUPT ] <= i_data[0];
            // CLD, STD
            8'b1111_110x: fl[ `DIRECTION ] <= i_data[0];
            // CMC
            8'b1111_0101: fl[ `CARRY ] <= !fl[ `CARRY ];

            // MOV rm, i8
            8'b1100_011x: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= 1'b0;

            end

            // JMP rel8/rel16/far; CALL; CALL far
            8'b1110_10xx,
            8'b1001_1010: m <= `OPCODE_EXEC;

            // RET/RETF
            // RET i16 / RETF i16
            8'b1100_x011,
            8'b1100_x010: begin

                ms      <= ss;
                ma      <= sp;
                memory  <= 1'b1;
                sp      <= sp + i_data[3] ? 4'h4 : 2'h2;
                m       <= `OPCODE_EXEC;

            end

            // LOOPNZ/LOOPZ/LOOP/JCXZ
            8'b1110_00xx: begin

                if (i_data[1:0] != 2'b11)
                    cx <= cx - 1'b1;

                m <= `OPCODE_EXEC;

            end

            // POP r/m16
            8'b1000_1111: begin

                m       <= `MODRM_DECODE;
                wide    <= 1'b1;
                direct  <= 1'b0;

            end

            // XCHG r8/16, rm
            8'b1000_011x: begin

                m       <= `MODRM_DECODE;
                wide    <= i_data[0];
                direct  <= 1'b0;

            end

            // LES r16, rm
            8'b1100_010x: begin

                m       <= `MODRM_DECODE;
                wide    <= 1'b1;
                direct  <= 1'b1;

            end

            // INT3
            8'b1100_1100: begin hibyte <= 3'h3; m <= `OPCODE_EXEC; end
            // INT i8
            8'b1100_1101: m <= `OPCODE_EXEC;
            // INTO Вызывается если Overflow=1
            8'b1100_1110: if (fl[11]) begin

                hibyte  <= 3'h4;
                m       <= `OPCODE_EXEC;

            end

        endcase

        // HLT
        if (i_data != 8'hF4)
            ip <= ip + 1'b1;

    end

    // Декодирование байта ModRM
    else if (m == `MODRM_DECODE) case (modm_stage)

        2'h0: begin

            modrm   <= i_data;
            ip      <= ip + 1'b1;

            // Операнд 1
            case (direct ? i_data[5:3] : i_data[2:0])

                3'b000: op1 <= wide ? ax : ax[ 7:0];
                3'b001: op1 <= wide ? cx : cx[ 7:0];
                3'b010: op1 <= wide ? dx : dx[ 7:0];
                3'b011: op1 <= wide ? bx : bx[ 7:0];
                3'b100: op1 <= wide ? sp : ax[15:8];
                3'b101: op1 <= wide ? bp : cx[15:8];
                3'b110: op1 <= wide ? si : dx[15:8];
                3'b111: op1 <= wide ? di : bx[15:8];

            endcase

            // Операнд 2
            case (direct ? i_data[2:0] : i_data[5:3])

                3'b000: op2 <= wide ? ax : ax[ 7:0];
                3'b001: op2 <= wide ? cx : cx[ 7:0];
                3'b010: op2 <= wide ? dx : dx[ 7:0];
                3'b011: op2 <= wide ? bx : bx[ 7:0];
                3'b100: op2 <= wide ? sp : ax[15:8];
                3'b101: op2 <= wide ? bp : cx[15:8];
                3'b110: op2 <= wide ? si : dx[15:8];
                3'b111: op2 <= wide ? di : bx[15:8];

            endcase

            // ----------
            // Определение, какой сегмент будет загружен
            // ----------

            // сегмент перегружен префиксом
            if (prefix) case (prefix_id)
                2'b00: ms <= es;
                2'b01: ms <= cs;
                2'b10: ms <= ss;
                2'b11: ms <= ds;
            endcase
            // если выбран b010 [bp+si] или b011 [bp+di]
            else if (i_data[2:1] == 2'b01) ms <= ss;
            // если выбран b110, то ss: применяется только к mod <> 2'b00
            else if (i_data[2:0] == 3'b110) ms <= (i_data[7:6] == 2'b00 ? ds : ss);
            // все остальные по умолчанию ds:
            else ms <= ds;

            // ----------
            // Выборка смещения
            // ----------

            case (i_data[2:0])

                3'b000: ma <= bx + si;
                3'b001: ma <= bx + di;
                3'b010: ma <= bp + si;
                3'b011: ma <= bp + di;
                3'b100: ma <= si;
                3'b101: ma <= di;
                // тут +disp16
                3'b110: ma <= i_data[7:6] == 2'b00 ? 1'b0 : bp;
                3'b111: ma <= bx;

            endcase

            // Выбран регистр -> фаза выполнения опкода
            if (i_data[7:6] == 2'b11) begin

                m <= `OPCODE_EXEC;

            // Указатель на память
            end else begin

                modm_stage <= 2'h1;

                // чтение из памяти на след. такте возможно (mod=00 и r/m != b110)
                if (i_data[7:6] == 2'b00 && i_data[2:0] !== 3'b110)
                    memory <= 1'b1;

            end

        end

        2'h1: begin

            modm_stage <= 2'h2;

            case (modrm[7:6])

                2'b00: begin

                    // Это чистый disp16
                    if (modrm[2:0] == 3'b110) begin

                        ip <= ip + 1'b1;
                        ma[7:0] <= i_data;

                    // чтение данных из памяти
                    end else begin

                        if (direct) op2 <= i_data; else op1 <= i_data;
                        if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                    end

                end

                // +disp8
                2'b01: begin

                    ip <= ip + 1'b1;
                    ma <= ma + {{8{i_data[7]}}, i_data[7:0]};
                    memory <= 1'b1;

                end

                // +disp16
                2'b10: begin

                    ip <= ip + 1'b1;
                    ma <= ma + {8'h00, i_data[7:0]};

                end

            endcase

        end

        2'h2: begin

            modm_stage <= 2'h3;

            case (modrm[7:6])

                2'b00: begin

                    // к чтению из памяти (1 или 2 байта)
                    if (modrm[2:0] == 3'b110) begin

                        ip <= ip + 1'b1;
                        ma[15:8] <= i_data;
                        memory <= 1'b1;

                    // старший байт читается из памяти и переход к исполнению
                    end else begin

                        m <= `OPCODE_EXEC;
                        if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;
                        ma <= ma - 1'b1;

                    end

                end

                // чтение младшего байта (и переход к исполнению)
                2'b01: begin

                    if (direct) op2 <= i_data; else op1 <= i_data;
                    if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                end

                // +disp16
                2'b10: begin

                    ip <= ip + 1'b1;
                    ma[15:8] <= ma[15:8] + i_data;
                    memory <= 1'b1;

                end

            endcase

        end

        2'h3: begin

            modm_stage <= 3'h4;

            case (modrm[7:6])

                // чтение lo-байта
                2'b00, 2'b10: begin

                    if (direct) op2 <= i_data; else op1 <= i_data;
                    if (wide == 1'b0) m <= `OPCODE_EXEC; else ma <= ma + 1'b1;

                end

                // завершение чтения hi-байта
                2'b01: begin

                    m <= `OPCODE_EXEC;
                    ma <= ma - 1'b1;
                    if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;

                end

            endcase

        end

        3'h4: begin

            if (direct) op2[15:8] <= i_data; else op1[15:8] <= i_data;
            ma <= ma - 1'b1;
            m <= `OPCODE_EXEC;

        end

    endcase

    // Исполнение инструкции
    else if (m == `OPCODE_EXEC) casex (opcode)

        // <ALU> ModRM
        8'b00xx_x0xx: begin

            fl <= rflags;

            /* CMP не сохраняется */
            if (alu != 3'b111) begin

                m        <= `WRITE_BACK_MODRM;
                wb_data  <= result;

            end else begin

                m       <= `OPCODE_DECODER;
                memory  <= 1'b0;

            end

        end

        // <ALU> al/ax, i8/16
        8'b00xx_x10x: case (mcode)

            // imm8
            3'h0: begin

                ip      <= ip + 1'b1;
                op2     <= i_data;
                mcode   <= opcode[0] ? 3'h1 : 3'h2;

            end

            // imm16
            3'h1: begin

                ip        <= ip + 1'b1;
                op2[15:8] <= i_data;
                mcode     <= 3'h2;

            end

            // Запись результата
            3'h2: begin

                m <= `OPCODE_DECODER;

                // CMP не писать в регистр
                if (alu != 3'b111) begin
                    if (opcode[0])
                        ax[15:0] <= result;
                    else
                        ax[7:0] <= result[7:0];
                end

                fl <= rflags;

            end

        endcase

        // MOV rm16, sreg
        8'b1000_1100: begin

            // Определение регистра для записи в память или регистр
            case (modrm[4:3])

                2'b00: wb_data <= es;
                2'b01: wb_data <= cs;
                2'b10: wb_data <= ss;
                2'b11: wb_data <= ds;

            endcase

            m <= `WRITE_BACK_MODRM;

        end

        // MOV sreg, rm16
        8'b1000_1110: begin

            case (modrm[4:3])
                2'b00: es <= op1;
                2'b01: cs <= op1;
                2'b10: ss <= op1;
                2'b11: ds <= op1;
            endcase

            memory <= 1'b0;
            m      <= `OPCODE_DECODER;

        end

        // ALU Group
        8'b1000_00xx: case (mcode)

            // Accept
            4'h0: begin

                alu    <= modrm[5:3];
                memory <= 1'b0;
                mcode  <= 4'h1;

            end

            // Imm8
            4'h1: begin

                ip    <= ip + 1'b1;
                op2   <= opcode[1:0] == 2'b11 ? {{8{i_data[7]}}, i_data} : i_data;
                mcode <= opcode[1:0] == 2'b01 ? 4'h2 : 4'h3;

            end

            // Imm16
            4'h2: begin

                op2[15:8]   <= i_data;
                ip          <= ip + 1'b1;
                mcode       <= 4'h3;

            end

            // Запись результата (скопирован код из 8'b00xx_x0xx)
            3'h3: begin

                fl <= rflags;

                /* CMP не сохраняется */
                if (alu != 3'b111) begin

                    m        <= `WRITE_BACK_MODRM;
                    wb_data  <= result;

                // Переход к получению следующего опкода
                end else begin m <= `OPCODE_DECODER; end

            end

        endcase

        // PUSH seg | r16 | PUSHF
        8'b000x_x110,
        8'b0101_0xxx,
        8'b1001_1100: case (mcode)

            4'h0: begin ma <= ma + 1'b1; o_data <= hibyte; mcode <= 4'h1; end
            4'h1: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

        endcase

        // POP seg
        8'b000x_x111,
        8'b0101_1xxx,
        8'b1001_1101: case (mcode)

            /* LO */ 4'h0: begin

                if (opcode[7]) begin

                    fl[7:0] <= i_data;

                end
                else if (opcode[6])

                    // @TODO write back --> modrm == 2'b11_rrr_000, direct = 1, wide = 1
                    case (opcode[2:0])
                        3'b000: ax[7:0] <= i_data;
                        3'b001: cx[7:0] <= i_data;
                        3'b010: dx[7:0] <= i_data;
                        3'b011: bx[7:0] <= i_data;
                        3'b100: sp[7:0] <= i_data;
                        3'b101: bp[7:0] <= i_data;
                        3'b110: si[7:0] <= i_data;
                        3'b111: di[7:0] <= i_data;
                    endcase
                else
                    case (opcode[4:3])
                        2'b00: es[7:0] <= i_data;
                        2'b10: ss[7:0] <= i_data;
                        2'b11: ds[7:0] <= i_data;
                    endcase

                ma    <= ma + 1'b1;
                mcode <= 1'b1;

            end

            /* HI */ 4'h1: begin

                if (opcode[7])
                    fl[11:8] <= i_data[3:0];
                else if (opcode[6])
                    case (opcode[2:0])
                        3'b000: ax[15:8] <= i_data;
                        3'b001: cx[15:8] <= i_data;
                        3'b010: dx[15:8] <= i_data;
                        3'b011: bx[15:8] <= i_data;
                        3'b100: sp[15:8] <= i_data;
                        3'b101: bp[15:8] <= i_data;
                        3'b110: si[15:8] <= i_data;
                        3'b111: di[15:8] <= i_data;
                    endcase
                else
                case (opcode[4:3])
                    2'b00: es[15:8] <= i_data;
                    2'b10: ss[15:8] <= i_data;
                    2'b11: ds[15:8] <= i_data;
                endcase

                memory <= 1'b1;
                m <= `OPCODE_DECODER;

            end

        endcase

        // INC/DEC r16
        8'b0100_xxxx: begin

            fl <= {
                /* OF */ opcode[3] ? op1 == 8'h7f : op1 == 8'h80,
                /* DF */ fl[10],
                /* IF */ fl[9],
                /* TF */ fl[8],
                /* SF */ op1[15],
                /* ZF */ op1 == 1'b0,
                /*    */ 1'b0,
                /* AF */ opcode[3] ? op1[3:0] == 4'hF : op1[3:0] == 4'h0,
                /*    */ 1'b0,
                /* PF */ op1[0] ^ op1[1] ^ op1[2] ^ op1[3] ^ op1[4] ^ op1[5] ^ op1[6] ^ op1[7] ^ 1'b1,
                /*    */ 1'b1,
                /* CF */ opcode[3] ? op1 == 16'hffff : op1 == 16'h0000
            };

            case (opcode[2:0])

                3'b000: ax <= op1;
                3'b001: cx <= op1;
                3'b010: dx <= op1;
                3'b011: bx <= op1;
                3'b100: sp <= op1;
                3'b101: bp <= op1;
                3'b110: si <= op1;
                3'b111: di <= op1;

            endcase


            m <= `OPCODE_DECODER;

        end

        // MOV r8/16, i8/16
        8'b1011_xxxx: case (mcode)

            4'h0: begin

                case (opcode[2:0])

                    3'b000: ax[7:0] <= i_data;
                    3'b001: cx[7:0] <= i_data;
                    3'b010: dx[7:0] <= i_data;
                    3'b011: bx[7:0] <= i_data;
                    3'b100: if (opcode[3]) sp[7:0] <= i_data; else ax[15:8] <= i_data;
                    3'b101: if (opcode[3]) bp[7:0] <= i_data; else cx[15:8] <= i_data;
                    3'b110: if (opcode[3]) si[7:0] <= i_data; else dx[15:8] <= i_data;
                    3'b111: if (opcode[3]) di[7:0] <= i_data; else bx[15:8] <= i_data;

                endcase

                mcode <= 1'b1;
                ip <= ip + 1'b1;
                m <= opcode[3] ? `OPCODE_EXEC : `OPCODE_DECODER;

            end

            4'h1: begin

                ip <= ip + 1'b1;
                m  <= `OPCODE_DECODER;

                case (opcode[2:0])

                    3'b000: ax[15:8] <= i_data;
                    3'b001: cx[15:8] <= i_data;
                    3'b010: dx[15:8] <= i_data;
                    3'b011: bx[15:8] <= i_data;
                    3'b100: sp[15:8] <= i_data;
                    3'b101: bp[15:8] <= i_data;
                    3'b110: si[15:8] <= i_data;
                    3'b111: di[15:8] <= i_data;

                endcase
            end


        endcase

        // J<ccc>
        8'b0111_xxxx: begin

            case (opcode[3:0])

                /* JO  */ 4'b0000: if (fl[ `OVERFLOW ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNO */ 4'b0001: if (fl[ `OVERFLOW ] == 1'b0)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JB  */ 4'b0010: if (fl[ `CARRY ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNB */ 4'b0011: if (fl[ `CARRY ] == 1'b0)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JZ  */ 4'b0100: if (fl[ `ZERO ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNZ */ 4'b0101: if (fl[ `ZERO ] == 1'b0)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JBE */ 4'b0110: if (fl[ `CARRY ] == 1'b1 || fl[ `ZERO ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JA  */ 4'b0111: if (fl[ `CARRY ] == 1'b0 && fl[ `ZERO ] == 1'b0)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JS  */ 4'b1000: if (fl[ `SIGN ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNS */ 4'b1001: if (fl[ `SIGN ] == 1'b0)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JP  */ 4'b1010: if (fl[ `PARITY ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNP */ 4'b1011: if (fl[ `PARITY ] == 1'b1)
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JL  */ 4'b1100: if (fl[ `SIGN ] != fl[ `OVERFLOW ])
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JNL */ 4'b1101: if (fl[ `SIGN ] == fl[ `OVERFLOW ])
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JLE */ 4'b1110: if (fl[ `ZERO ] == 1'b1 || fl[ `SIGN ] != fl[ `OVERFLOW ])
                    ip <= ip_rel8; else ip <= ip + 1'b1;

                /* JG  */ 4'b1111: if (fl[ `ZERO ] == 1'b0 && fl[ `SIGN ] == fl[ `OVERFLOW ])
                    ip <= ip_rel8; else ip <= ip + 1'b1;

            endcase

            m <= `OPCODE_DECODER;

        end

        // MOV al/ax, [m16]
        // MOV [m16], al/ax
        8'b1010_00xx: case (mcode)

            4'h0: begin

                if (prefix)
                case (prefix_id)
                    2'b00: ms <= es;
                    2'b01: ms <= cs;
                    2'b10: ms <= ss;
                    2'b11: ms <= ds;
                endcase
                else ms <= ds;

                ma[7:0] <= i_data;
                ip      <= ip + 1'b1;
                mcode   <= 1'b1;

            end

            4'h1: begin

                mcode    <= 2'h2;
                ip       <= ip + 1'b1;
                ma[15:8] <= i_data;
                o_data   <= ax[7:0];
                memory   <= 1'b1;
                o_write  <= opcode[1];

            end

            // Запись или чтение из памяти LO
            4'h2: begin

                ma      <= ma + 1'b1;
                o_data  <= ax[15:8];
                mcode   <= 4'h3;

                // Завершить запись HI если BYTE
                if (opcode[0] == 1'b0) begin

                    m       <= `OPCODE_DECODER;
                    memory  <= 1'b0;
                    o_write <= 1'b0;

                end

                // Запись из памяти в AX
                if (opcode[1]) ax[7:0] <= i_data;

            end

            // Запись или чтение из памяти HI
            4'h3: begin

                m       <= `OPCODE_DECODER;
                memory  <= 1'b0;
                o_write <= 1'b0;

                if (opcode[1]) ax[15:8] <= i_data;

            end

        endcase

        // TEST rm, r8/16
        8'b1000_010x: begin

            memory  <= 1'b0;
            fl      <= rflags;
            m       <= `OPCODE_DECODER;

        end

        // TEST al/ax, i8/16
        8'b1010_100x: case (mcode)

            4'h0: begin

                ip      <= ip + 1'b1;
                op2     <= i_data;
                mcode   <= 4'h1;

            end

            // 8 bit
            4'h1: begin

                if (opcode[0] == 1'b0) begin

                    fl  <= rflags;
                    m   <= `OPCODE_DECODER;

                end else begin

                    ip      <= ip + 1'b1;
                    op2[15:8] <= i_data;
                    mcode   <= 4'h2;

                end

            end

            // 16 bit
            4'h2: begin

                fl  <= rflags;
                m   <= `OPCODE_DECODER;

            end

        endcase

        // MOV ModRM
        8'b1000_10xx: case (mcode)

            4'h0: begin

                // reg, r/m; r/m = reg --> сохранить в регистр
                if (direct | (!direct & modrm[7:6] == 2'b11)) begin

                    case (direct ? modrm[5:3] : modrm[2:0])

                        3'b000: if (wide) ax <= op2[15:0]; else ax[ 7:0] <= op2[7:0];
                        3'b001: if (wide) cx <= op2[15:0]; else cx[ 7:0] <= op2[7:0];
                        3'b010: if (wide) dx <= op2[15:0]; else dx[ 7:0] <= op2[7:0];
                        3'b011: if (wide) bx <= op2[15:0]; else bx[ 7:0] <= op2[7:0];
                        3'b100: if (wide) sp <= op2[15:0]; else ax[15:8] <= op2[7:0];
                        3'b101: if (wide) bp <= op2[15:0]; else cx[15:8] <= op2[7:0];
                        3'b110: if (wide) si <= op2[15:0]; else dx[15:8] <= op2[7:0];
                        3'b111: if (wide) di <= op2[15:0]; else bx[15:8] <= op2[7:0];

                    endcase

                    memory <= 1'b0;
                    m <= `OPCODE_DECODER;

                end

                // Сохранить в память
                else begin

                    o_data  <= op2[ 7:0];
                    hibyte  <= op2[15:8];
                    mcode   <= wide ? 3'h1 : 3'h2;
                    o_write <= 1'b1;

                end

            end

            // Запись результатов
            3'h1: begin mcode <= 3'h2; o_data <= hibyte; ma <= ma + 1'b1; end
            3'h2: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

        endcase

        // LEA r16, rm
        8'b1000_1101: begin

            case (modrm[5:3])

                3'b000: ax <= ma;
                3'b001: cx <= ma;
                3'b010: dx <= ma;
                3'b011: bx <= ma;
                3'b100: sp <= ma;
                3'b101: bp <= ma;
                3'b110: si <= ma;
                3'b111: di <= ma;

            endcase

            memory  <= 1'b0;
            m       <= `OPCODE_DECODER;

        end

        // MOV r/m, i8/16
        8'b1100_011x: case (mcode)

            4'h0: begin memory <= 1'b0; mcode <= 4'h1; end

            // Imm8
            4'h1: begin

                wb_data <= i_data;
                ip      <= ip + 1'b1;

                if (wide == 1'b0)
                    m <= `WRITE_BACK_MODRM;
                else
                    mcode <= 4'h2;

            end

            // Imm16
            4'h2: begin

                ip      <= ip + 1'b1;
                wb_data[15:8] <= i_data;
                m       <= `WRITE_BACK_MODRM;

            end

        endcase

        // JMP rel8
        8'b1110_1011: begin

            ip <= ip_rel8;
            m  <= `OPCODE_DECODER;

        end

        // JMP|CALL rel16
        8'b1110_1001, 8'b1110_1000: case (mcode)

            2'h0: begin hibyte <= i_data; mcode <= 2'h1; ip <= ip + 1'b1; end
            2'h1: begin

                mcode <= 2'h2;

                if (opcode[0]) m <= `OPCODE_DECODER; else begin

                    memory <= 1'b1;
                    ma <= sp - 2'h2;
                    ms <= ss;
                    sp <= sp - 2'h2;
                    o_write <= 1'b1;
                    o_data <= ip_next[7:0];
                    hibyte <= ip_next[15:8];

                end

                ip <= ip + 1'b1 + {i_data, hibyte};

            end

            2'h2: begin ma <= ma + 1'b1; o_data <= hibyte; mcode <= 2'h3; end
            2'h3: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

        endcase

        // JMP/CALL far
        8'b1110_1010,
        8'b1001_1010: case (mcode)

            2'h0: begin wb_data[7:0] <= i_data; mcode <= 2'h1; ip <= ip + 1'b1; end
            2'h1: begin wb_data[15:8] <= i_data; mcode <= 2'h2; ip <= ip + 1'b1; end
            2'h2: begin hibyte <= i_data; mcode <= 2'h3; ip <= ip + 1'b1; end
            2'h3: begin

                if /* CALLF */ (opcode[4]) begin

                    op1     <= cs;
                    memory  <= 1'b1;
                    ma      <= sp - 3'h4;
                    ms      <= ss;
                    sp      <= sp - 3'h4;
                    o_write <= 1'b1;
                    o_data  <= ip_next[7:0];
                    hibyte  <= ip_next[15:8];
                    mcode   <= 3'h4;

                end else m <= `OPCODE_DECODER;

                cs <= {i_data, hibyte};
                ip <= wb_data;

            end

            3'h4: begin ma <= ma + 1'b1; mcode <= 3'h5; o_data <= hibyte; end
            3'h5: begin ma <= ma + 1'b1; mcode <= 3'h6; o_data <= op1[7:0]; end
            3'h6: begin ma <= ma + 1'b1; mcode <= 3'h7; o_data <= op1[15:8];end
            3'h7: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

        endcase

        // RET/RETF [i16]
        8'b1100_x011,
        8'b1100_x010: case (mcode)

            4'h0: begin

                ip[7:0] <= i_data;
                mcode   <= 4'h1;
                ma      <= ma + 1'b1;
                wb_data <= ip;
                tmpdata <= cs;

            end

            4'h1: begin

                ip[15:8] <= i_data;

                ma       <= ma + 1'b1;

                // просто RET
                if (opcode[3] == 1'b0) begin

                    // Обычный RET
                    if (opcode[0]) begin

                        memory  <= 1'b0;
                        m       <= `OPCODE_DECODER;

                    // С Imm16
                    end else begin

                        ma <= wb_data;
                        ms <= tmpdata;
                        mcode <= 4'h4;

                    end

                end else mcode <= 4'h2;

            end

            4'h2: begin cs[7:0]  <= i_data; mcode <= 4'h3; ma <= ma + 1'b1; end
            4'h3: begin cs[15:8] <= i_data;

                mcode <= 4'h4;

                // Обычный RET/RETF
                if (opcode[0]) begin

                    memory  <= 1'b0;
                    m       <= `OPCODE_DECODER;

                end else begin

                    ma <= wb_data;
                    ms <= tmpdata;

                end

            end

            4'h4: begin mcode <= 4'h5; hibyte <= i_data; ma <= ma + 1'b1; end
            4'h5: begin

                sp <= sp + {i_data, hibyte};
                memory  <= 1'b0;
                m <= `OPCODE_DECODER;

            end

        endcase

        // LOOPNZ, LOOPE, LOOP, JCXZ
        8'b1110_00xx: begin

            if (opcode[1:0] == 2'b11) begin

                m  <= `OPCODE_DECODER;
                ip <= (cx == 16'h0000) ? ip + 1'b1 : ip_rel8;

            end
            else begin

                // Либо CX = 0, либо ZF = opcode[0] - перейти к следующему
                ip <= (cx == 16'h0000 || (opcode[1] == 1'b0 && fl[`ZERO ] != opcode[0])) ? ip + 1'b1 : ip_rel8;

            end

        end

        // POP r/m
        8'b1000_1111: case (mcode)

            4'h0: begin

                // Сохранить предыдущие ms: ma
                op1     <= ms;
                op2     <= ma;

                // Взять из стека значение
                ms      <= ss;
                ma      <= sp;
                sp      <= sp + 2'h2;
                memory  <= 1'b1;
                mcode   <= 1'b1;

            end

            // Low
            4'h1: begin wb_data[7:0] <= i_data; mcode <= 4'h2; ma <= ma + 1'b1; end

            // High, Сохранить результат
            4'h2: begin

                wb_data[15:8] <= i_data;

                ms <= op1;
                ma <= op2;
                m  <= `WRITE_BACK_MODRM;

            end


        endcase

        // XCHG r8/16, rm
        8'b1000_011x: begin

            // op1, op2 - пришедние данные
            // запись одного из них в регистр
            case (modrm[5:3])

                3'b000: if (wide) ax <= op1[15:0]; else ax[ 7:0] <= op1[7:0];
                3'b001: if (wide) cx <= op1[15:0]; else cx[ 7:0] <= op1[7:0];
                3'b010: if (wide) dx <= op1[15:0]; else dx[ 7:0] <= op1[7:0];
                3'b011: if (wide) bx <= op1[15:0]; else bx[ 7:0] <= op1[7:0];
                3'b100: if (wide) sp <= op1[15:0]; else ax[15:8] <= op1[7:0];
                3'b101: if (wide) bp <= op1[15:0]; else cx[15:8] <= op1[7:0];
                3'b110: if (wide) si <= op1[15:0]; else dx[15:8] <= op1[7:0];
                3'b111: if (wide) di <= op1[15:0]; else bx[15:8] <= op1[7:0];

            endcase

            // другого в память или регистр
            wb_data <= op2;
            m <= `WRITE_BACK_MODRM;

        end

        // L(ES/DS) r16, [rm]
        8'b1100_010x: case (mcode)

            // Чтение следующего байта для загрузки в сегмент
            4'h0: begin mcode <= 4'h1; ma <= ma + 2'h2; end

            4'h1: begin mcode <= 4'h2; hibyte <= i_data; ma <= ma + 1'b1; end

            // Загрузка в сегмент и регистр полученного значения
            4'h2: begin

                if (opcode[0])
                     ds <= {i_data, hibyte};
                else es <= {i_data, hibyte};

                // Пишем результат в регистр
                wb_data <= op2;
                m       <= `WRITE_BACK_MODRM;

            end

        endcase

        // IRET
        8'b1100_1111: case (mcode)

            4'h0: begin mcode <= 4'h1; ip[7:0]  <= i_data; ma <= ma + 1'b1; end
            4'h1: begin mcode <= 4'h2; ip[15:8] <= i_data; ma <= ma + 1'b1; end
            4'h2: begin mcode <= 4'h3; cs[7:0]  <= i_data; ma <= ma + 1'b1; end
            4'h3: begin mcode <= 4'h4; cs[15:8] <= i_data; ma <= ma + 1'b1; end
            4'h4: begin mcode <= 4'h5; fl[7:0]  <= i_data; ma <= ma + 1'b1; end
            4'h5: begin fl[11:8] <= i_data[3:0]; m <= `OPCODE_DECODER; memory <= 1'b0; end

        endcase

        // INT 3/i8/INTO
        8'b1100_1100,
        8'b1100_1101,
        8'b1100_1110: case (mcode)

            // Запись в стек
            4'h0: begin

                mcode   <= 4'h1;

                // Номер прерывания для INT i8
                if (opcode == 8'b1100_1101)
                    hibyte  <= i_data;

                sp      <= sp - 4'h6;
                ms      <= ss;
                ma      <= sp - 4'h6;
                memory  <= 1'b1;
                o_data  <= ip_next[7:0];
                o_write <= 1'b1;
                ip      <= ip + 1'b1;

            end

            4'h1: begin mcode <= 4'h2; o_data <= ip[15:8]; ma <= ma + 1'b1; end
            4'h2: begin mcode <= 4'h3; o_data <= cs[7:0]; ma <= ma + 1'b1; end
            4'h3: begin mcode <= 4'h4; o_data <= cs[15:8]; ma <= ma + 1'b1; end
            4'h4: begin mcode <= 4'h5; o_data <= fl[7:0]; ma <= ma + 1'b1; end

            // Извлечение адреса перехода
            4'h5: begin

                mcode   <= 4'h6;
                o_data  <= {4'b0000, fl[11:8]};

            end

            4'h6: begin mcode <= 4'h7; o_write <= 1'b0; ms <= 1'b0; ma <= {hibyte, 3'b000}; end
            4'h7: begin mcode <= 4'h8; ip[7:0] <= i_data; ma <= ma + 1'b1; end
            4'h8: begin mcode <= 4'h9; ip[15:8] <= i_data; ma <= ma + 1'b1; end
            4'h9: begin mcode <= 4'hA; cs[7:0] <= i_data; ma <= ma + 1'b1; end
            4'hA: begin cs[15:8] <= i_data; memory <= 1'b0; m <= `OPCODE_DECODER; end

        endcase

    endcase

    // Запись в регистр или в память (modrm и др.)
    else if (m == `WRITE_BACK_MODRM) casex (wbmcode)

        2'h0: begin

            // reg, r/m; r/m = reg --> сохранить в регистр
            if (direct | (!direct & modrm[7:6] == 2'b11)) begin

                case (direct ? modrm[5:3] : modrm[2:0])

                    3'b000: if (wide) ax <= wb_data[15:0]; else ax[ 7:0] <= wb_data[7:0];
                    3'b001: if (wide) cx <= wb_data[15:0]; else cx[ 7:0] <= wb_data[7:0];
                    3'b010: if (wide) dx <= wb_data[15:0]; else dx[ 7:0] <= wb_data[7:0];
                    3'b011: if (wide) bx <= wb_data[15:0]; else bx[ 7:0] <= wb_data[7:0];
                    3'b100: if (wide) sp <= wb_data[15:0]; else ax[15:8] <= wb_data[7:0];
                    3'b101: if (wide) bp <= wb_data[15:0]; else cx[15:8] <= wb_data[7:0];
                    3'b110: if (wide) si <= wb_data[15:0]; else dx[15:8] <= wb_data[7:0];
                    3'b111: if (wide) di <= wb_data[15:0]; else bx[15:8] <= wb_data[7:0];

                endcase

                memory  <= 1'b0;
                m       <= `OPCODE_DECODER;

            end

            // Или сохранить в память
            else begin

                o_data  <= wb_data[ 7:0];
                hibyte  <= wb_data[15:8];
                wbmcode <= wide ? 3'h1 : 3'h2;
                memory  <= 1'b1;
                o_write <= 1'b1;

            end

        end

        // Запись результатов
        3'h1: begin wbmcode <= 3'h2; o_data <= hibyte; ma <= ma + 1'b1; end
        3'h2: begin o_write <= 1'b0; memory <= 1'b0; m <= `OPCODE_DECODER; end

    endcase

end

// Арифметическо-логическое устройство
// ---------------------------------------------------------------------

wire parity = result[0]  ^ result[1]  ^ result[2]  ^ result[3] ^
              result[4]  ^ result[5]  ^ result[6]  ^ result[7] ^ 1'b1;

wire zero_8  = result[7:0]  == 8'h00;
wire zero_16 = result[15:0] == 16'h0000;

wire [3:0] bsw = wide ? 15 : 7;

always @* begin

    case (alu)

        /* ADD */ 3'b000: result = op1 + op2;
        /* OR  */ 3'b001: result = op1 | op2;
        /* ADC */ 3'b010: result = op1 + op2 + fl[ `CARRY ];
        /* SBB */ 3'b011: result = op1 - op2 - fl[ `CARRY ];
        /* AND */ 3'b100: result = op1 & op2;
        /* SUB */ 3'b101: result = op1 - op2;
        /* XOR */ 3'b110: result = op1 ^ op2;
        /* CMP */ 3'b110: result = op1 - op2;

    endcase

    case (alu)

        /* ADD */
        /* ADC */
        3'b000,
        3'b010: rflags = {
            /* OF */ (op1[ bsw ] ^ op2[ bsw ] ^ 1'b1) & (op1[ bsw ] ^ result[ bsw ]),
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ op1[3:0] + op2[3:0] + (alu[1] & fl[ `CARRY ]) >= 5'h10, // ADC = +Carry
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ result[ bsw + 1 ]
        };

        /* OR  */
        /* AND */
        /* XOR */
        3'b001,
        3'b100,
        3'b110: rflags = {
            /* OF */ 1'b0,
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ i_data[4], // Undefined
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ 1'b0
        };

        /* SUB */
        /* CMP */
        /* SBB */
        3'b101,
        3'b110,
        3'b011: rflags = {
            /* OF */ (op1[ bsw ] ^ op2[ bsw ]) & (op1[ bsw ] ^ result[ bsw ]),
            /* DF */ fl[10],
            /* IF */ fl[9],
            /* TF */ fl[8],
            /* SF */ result[ bsw ],
            /* ZF */ wide ? zero_16 : zero_8,
            /*    */ 1'b0,
            /* AF */ op1[3:0] < op2[3:0] + (!alu[2] & fl[ `CARRY ]), // SBB = -Carry
            /*    */ 1'b0,
            /* PF */ parity,
            /*    */ 1'b1,
            /* CF */ result[ bsw + 1 ]
        };

    endcase

end

endmodule
