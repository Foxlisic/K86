module cpu(

    input   wire        clk25,
    output  wire [19:0] address,    // 20 проводов
    input   wire [ 7:0] din,        // Входящие данные
    output  reg  [ 7:0] dout,       // Исходящие
    output  reg         we          // Write Enabled Signal

);

// -------------------------------------------------

// Состояния процессора
`define  INIT       1'b0
`define  FETCH      1'b1
`define  MODRM      2'h2
`define  EXEC       2'h3
`define  SAVERES    2'h4

// Процедуры
`define  GENERAL    3'h0            // Основная
`define  LOADIMM    3'h1            // Загрузка immediate
`define  PUSH       3'h2            // Сохранение в стек
`define  POP        3'h3            // Загрузка из стека
`define  INTERRUPT  3'h4            // Вызов прерывания
`define  WRITE      3'h5            // Запись в память

// -------------------------------------------------

/*
 * 00 11 35 32 56
 *
 * [префиксы] <опкод> [байт modrm / sib] [операнды] [непосредственное значение]
 *
 * 66 05 33 44 12 44  ADD EAX, 0x44124433
 *    05 33 44        ADD  AX, 0x4433
 */

// 20 bit = 16 * cs + ip или 16 * segment + ea
assign address = {am ? segment : cs, 4'b0000} + (am ? ea : ip);

// ------------------------------------
reg [31:0] eax = 32'h7711_5544; // 0
reg [31:0] ecx = 32'h0000_0000; // 1
reg [31:0] edx = 32'h0000_0000; // 2
reg [31:0] ebx = 32'h0000_1122; // 3
reg [31:0] esp = 32'h0000_7799; // 4
reg [31:0] ebp = 32'h0000_0000; // 5
reg [31:0] esi = 32'h0000_2233; // 6
reg [31:0] edi = 32'h0000_0000; // 7

reg [15:0] es = 16'h0000;
reg [15:0] cs = 16'h0000;
reg [15:0] ss = 16'h0000;
reg [15:0] ds = 16'h0000;
// fs, gs -- не используются

reg [15:0] ip = 16'h0000;
// ------------------------------------


/*
  0  CF    Флаг переноса
  1   1
  2  PF    Флаг чётности
  3   0
  4  AF    Вспомогательный флаг переноса
  5   0
  6  ZF    Флаг нуля
  7  SF    Флаг знака
  8  TF    Флаг трассировки
  9  IF    Флаг разрешения прерываний
  10 DF    Флаг направления
  11 OF    Флаг переполнения
*/
                    // OIDT SZ A  P C
reg [11:0] flags = 12'b0000_0000_0000;

// Текущее состояние
reg [ 7:0] m = 1'b0;

// Кеши. 9 bit на опкод. Расширение опкода 0Fh
reg [ 8:0] opcode;
reg [ 7:0] modrm;
reg [ 7:0] sib;

// Состояние выполнения считывания операндов
reg [ 2:0] mm;

// Префиксы инструкции
reg        flag_override;
reg [15:0] segment;
reg [31:0] ea;                  // Эффективный адрес
reg [31:0] prea;                // Временное хранение ea
reg        osize;
reg        asize;
reg        repnz;
reg        repz;

// Указатели на регистры. На следующем такте будут значения регистров
reg        am        = 1'b0;    // Указатель на память 1=[segment:ea] или код 0=[cs: ip]

reg        bitsize   = 0;       // 0=8, 1=16/32
reg        direction = 0;       // 0=r/m, reg; 1=reg, r/m
reg [2:0]  A         = 0;       // Номер регистра
reg [31:0] R         = 0;       // Результат

reg [ 3:0] rn        = 1'b0;    // Номер регистра на запись
reg [31:0] rc        = 1'b0;    // То, что будет записано
reg        w         = 1'b0;    // Указание на запись в регистр

// Результаты и аргументы для процедур
reg [2:0]  func      = 1'b0;    // ID процедуры
reg [2:0]  phase     = 1'b0;    // Фаза выполнения процедуры
reg [1:0]  immsize   = 1'b0;    // Размер Immediate (0=8, 1=16, 2=24, 3=32)
reg [31:0] immresult = 1'b0;    // Результат прочтенного immediate

// Значения регистров
reg [31:0] Op1;     // Операнд 1 из ModRM
reg [31:0] Op2;     // Операнд 2 из ModRM

// 16-bit modrm
wire [15:0] ModRMDisp8  = ea[15:0] + {{8{immresult[7]}}, immresult[7:0]};
wire [15:0] ModRMDisp16 = ea[15:0] + immresult[15:0];

// 32-bit modrm
wire [31:0] ModRMDisp8E = ea[31:0] + {{24{immresult[7]}}, immresult[7:0]};
wire [31:0] ModRMDisp32 = ea[31:0] + immresult[31:0];

// Требуется вызов функции для displacement
wire NeedDisp16 = (din[7:6] == 2'b01) | (din[7:6] == 2'b10) | (din[7:6] == 2'b00 && din[2:0] == 3'b110);
wire NeedDisp32 = (din[7:6] == 2'b01) | (din[7:6] == 2'b10) | (din[7:6] == 2'b00 && din[2:0] == 3'b101);

always @(posedge clk25) begin

    case (func)

        /* Процедура не выполняется; вместо нее исполняется инструкция */
        `GENERAL: case (m)

            // Инициализация инструкции перед выполнением
            `INIT: begin

                m <= 1'b1;

                // Префиксы
                opcode[8] <= 1'b0;  // Опкод
                segment   <= ds;    // Сегмент по умолчанию
                flag_override <= 1'b0; // Перегружен ли сегмент в этой инструкции
                osize <= 1'b0;      // 0 - 16bit, 1 - 32bit
                asize <= 1'b0;      // 0 - 16bit, 1 - 32bit
                repnz <= 1'b0;
                repz  <= 1'b0;

                // ModRM
                modrm <= 8'h00;
                mm    <= 1'b0;
                am    <= 1'b0;
                ea    <= 1'b0;
                prea  <= 1'b0;
                Op1   <= 1'b0;
                Op2   <= 1'b0;
                phase <= 1'b0;
                immresult <= 1'b0;

                // Регистры
                w     <= 1'b0;
                rc    <= 1'b0;
                rn    <= 1'b0;

            end

            // Чтение и разбор, декодирование префиксов и самого опкода
            `FETCH: begin

                case (din)

                    /* Расширение опкода */
                    8'h0F: begin opcode[8] <= 1'b1; end
                    /* Префиксы для принудительного задания сегмента */
                    8'h26: begin segment <= es; flag_override <= 1'b1; end
                    8'h2E: begin segment <= cs; flag_override <= 1'b1; end
                    8'h36: begin segment <= ss; flag_override <= 1'b1; end
                    8'h3E: begin                flag_override <= 1'b1; end
                    8'h66: begin osize <= osize ^ 1'b1; end /* Переключение 16/32 регистров */
                    8'h67: begin asize <= asize ^ 1'b1; end /* Переключения 16/32 метода адресации */
                    8'hF0, 8'h64, 8'h65: begin /* тут ничего не будет делаться */ end
                    8'hF2: begin repnz <= 1'b1; end
                    8'hF3: begin repz  <= 1'b1; end
                    default: begin

                        opcode[7:0] <= din;

                        // Значения направления (reg, r/m) и размера регистров
                        direction <= din[1];
                        bitsize   <= din[0];

                        // Дополнительный набор
                        if (opcode[8])

                            casex (din)

                                8'b0000_01xx, // 04-07
                                8'b0000_10xx, // 08-0B
                                8'b0010_01x1, // 25,27
                                8'b0011_10x1, // 39,3B
                                8'b0011_0xxx, // 30-37
                                8'b0011_11xx, // 3C-3F
                                8'b1000_xxxx, // 80-8F
                                8'b1010_x00x, // A0-A1, A8-A9
                                8'b1010_x010, // A2,AA
                                8'b1010_011x, // A6,A7
                                8'b1100_1xxx, // C8-CF
                                8'h0C, 8'h0E, 8'hFF,
                                8'h77, 8'h7A, 8'h7B: m <= `EXEC;
                                default: m <= `MODRM;

                            endcase

                        else // Основной набор инструкции

                            casex (din)

                                8'b00xx_x0xx, // АЛУ
                                8'b1000_xxxx, // 80-8F
                                8'b1100_01xx, // C4-C7
                                8'b1101_00xx, // D0-D3
                                8'b1101_1xxx, // D8-DF Сопроцессор
                                8'b1111_x11x, // F6-F7, FE-FF
                                8'h62, 8'h63, 8'h69,
                                8'h6B, 8'hC0, 8'hC1: m <= `MODRM;
                                default: m <= `EXEC;

                            endcase

                    end

                endcase

                ip <= ip + 1'b1;

            end

            // Исполнение ModRM
            `MODRM: begin

                /* 16-bit ModRM. Загрузка операндов */
                if (asize == 1'b0) case (mm)

                    /* Инициализирущий такт */
                    1'b0: begin

                        // Прочитать значения регистров на следующем такте
                        A <= direction ? din[2:0] : din[5:3];

                        // Вычислим предварительный эффективный адрес (указатель в память)
                        // Он может потом и не потребоваться, но вычислить его надо
                        // -----------------------------------------

                        case (din[2:0])

                            3'b000: ea[15:0] <= ebx[15:0] + esi[15:0]; // bx + si
                            3'b001: ea[15:0] <= ebx[15:0] + edi[15:0]; // bx + di
                            3'b010: ea[15:0] <= ebp[15:0] + esi[15:0]; // bp + si
                            3'b011: ea[15:0] <= ebp[15:0] + edi[15:0]; // bp + di
                            3'b100: ea[15:0] <= esi[15:0];             // si
                            3'b101: ea[15:0] <= edi[15:0];             // di
                            3'b110: ea[15:0] <= (din[7:6] == 2'b00) ? 1'b0 : ebp[15:0]; // bp или disp16 (mod=0)
                            3'b111: ea[15:0] <= ebx[15:0];             // bx

                        endcase

                        // При случае, когда нет префикса сегмента, установить сегмент по умолчанию (ss: или ds:)
                        // Нужно для чтения значения операнда из памяти
                        // -----------------------------------------

                        if (flag_override == 1'b0) begin

                            // [bp + si] или [bp + di]
                            if (din[2:1] == 2'b01)
                                segment <= ss;

                            // [bp + d8/16]
                            else if ((din[7:6] == 2'b01 || din[7:6] == 2'b10) && din[2:0] == 3'b110)
                                segment <= ss;

                        end

                        // Прочитать 8 или 16 битный Immediate (mod=1, mod=2) для disp8 / disp16
                        // -----------------------------------------
                        if (NeedDisp16) {func, immsize} <= {`LOADIMM, din[6] ? 2'b00 : 2'b01};                    
                        // -----------------------------------------

                        mm    <= 1'b1;      // К следующему
                        ip    <= ip + 1'b1; // IP++
                        modrm <= din;       // В кеш

                    end

                    /* Чтение значения регистров и установка указателей на память, если нужно */
                    1'b1: begin

                        // В операнд 1 читается r/m, если direction = 0; аналогично, в Op2
                        if (direction)
                             begin A <= modrm[5:3]; Op1 <= R; end
                        else begin A <= modrm[2:0]; Op2 <= R; end

                        // Установка указателя на память
                        case (modrm[7:6])

                            /* Без +disp, но возможен disp16 */
                            2'b00: begin

                                if (modrm[2:0] == 3'b110) begin

                                    ea[15:0]   <= immresult[15:0];
                                    prea[15:0] <= immresult[15:0];

                                end else prea <= ea;

                            end

                            /* Disp8: -128 .. 127 */
                            2'b01: begin

                                ea[15:0]   <= ModRMDisp8;
                                prea[15:0] <= ModRMDisp8;

                            end

                            /* Disp16: -32768 .. 32767 */
                            2'b10: begin

                                ea[15:0]   <= ModRMDisp16;
                                prea[15:0] <= ModRMDisp16;

                            end

                        endcase

                        /* Запуск функции скачивания из [segment:ea], только если r/m указывает в память */
                        if (modrm[7:6] != 2'b11) begin

                            am    <= 1'b1;
                            func  <= `LOADIMM;

                            // 32 bit если bitsize=1 и osize=1, иначе 8/16
                            immsize <= osize & osize ? 2'b11 : bitsize;

                        end

                        mm  <= 2'h2;

                    end

                    /* Записать прочитанный операнд из памяти */
                    2'h2: begin

                        if (direction)
                             Op2 <= modrm[7:6] == 2'b11 ? R : immresult; // reg, r/m
                        else Op1 <= modrm[7:6] == 2'b11 ? R : immresult; // r/m, reg

                        ea <= prea;  // Вернуть ea обратно
                        m  <= `EXEC; // Перейти к исполнению

                    end

                endcase

                /* 32-bit ModRM и SIB */
                else case (mm)

                    /* Инициализирущий такт */
                    1'b0: begin

                        // Прочитать значения регистров на следующем такте
                        A <= direction ? din[2:0] : din[5:3];

                        // Определить 32 битный EA
                        case (din[2:0])

                            3'b000: ea <= eax;
                            3'b001: ea <= ecx;
                            3'b010: ea <= edx;
                            3'b011: ea <= ebx;
                            3'b100: ea <= 1'b0; /* sib */
                            3'b101: ea <= (din[7:6] == 2'b00 ? 1'b0 : ebp);
                            3'b110: ea <= esi;
                            3'b111: ea <= edi;

                        endcase

                        /* Решение о считывании байта SIB */
                        casex (modrm)

                            /* sib */
                            8'b0x_xxx_100,
                            8'b10_xxx_100: mm <= 2'h3;

                            /* modrm */
                            default: begin

                                mm <= 2'h1;

                                /* Если есть displacement, то выполнить запрос load immediate */
                                if (NeedDisp32) {func, immsize} <= {`LOADIMM, din[6] ? 2'b00 : 2'b11};

                            end

                        endcase

                        // EBP заменяет сегмент DS на SS
                        if (flag_override == 1'b0) begin
                            if ((din[7:6] == 2'b01 || din[7:6] == 2'b10) && din[2:0] == 3'b101)
                                segment <= ss;
                        end

                        ip    <= ip + 1'b1; // IP++
                        modrm <= din;       // В кеш

                    end

                    /* Чтение значения регистров */
                    1'b1: begin

                        // В операнд 1 читается r/m, если direction = 0; аналогично, в Op2
                        if (direction)
                             begin A <= modrm[5:3]; Op1 <= R; end
                        else begin A <= modrm[2:0]; Op2 <= R; end

                        /* Установка указателя на память */
                        case (modrm[7:6])

                            2'b00: begin /* Без +disp, но возможен disp32 */

                                if (modrm[2:0] == 3'b101) begin

                                    ea   <= ModRMDisp32;
                                    prea <= ModRMDisp32;

                                end else prea <= ea;

                            end
                            2'b01: begin ea <= ModRMDisp8E; prea <= ModRMDisp8E; end /* 8 bit */
                            2'b10: begin ea <= ModRMDisp32; prea <= ModRMDisp32; end /* 32 bit */

                        endcase

                        /* Запуск функции скачивания из [segment:ea], только если r/m указывает в память */
                        if (modrm[7:6] != 2'b11) begin

                            am      <= 1'b1;
                            func    <= `LOADIMM;
                            immsize <= osize & osize ? 2'b11 : bitsize;

                        end

                        mm <= 2'h2;

                    end

                    /* Записать прочитанный операнд из памяти */
                    2'h2: begin

                        if (direction)
                             Op2 <= modrm[7:6] == 2'b11 ? R : immresult; // reg, r/m
                        else Op1 <= modrm[7:6] == 2'b11 ? R : immresult; // r/m, reg

                        ea <= prea;  // Вернуть EA обратно
                        m  <= `EXEC; // Перейти к исполнению

                    end

                    /* Байт SIB: Scale*Index + Base */
                    2'h3: begin

                        // Определить 32 битный EA
                        case (din[2:0])

                            3'b000: ea <= sibimm + eax;
                            3'b001: ea <= sibimm + ecx;
                            3'b010: ea <= sibimm + edx;
                            3'b011: ea <= sibimm + ebx;
                            3'b100: ea <= sibimm + esp;
                            3'b101: ea <= sibimm + (modrm[7:6] == 2'b00 ? 1'b0 : ebp);
                            3'b110: ea <= sibimm + esi;
                            3'b111: ea <= sibimm + edi;

                        endcase

                        /* Загрузить +disp8/32 */
                        if (NeedDisp32) {func, immsize} <= {`LOADIMM, din[6] ? 2'b00 : 2'b11};

                        ip  <= ip + 1'b1;
                        mm  <= 1'b1;
                        sib <= din;

                    end

                endcase

            end

            // Исполнение микрокода
            `EXEC: begin

                // ....

            end

        endcase

        /* Загрузка непосредственного значения из памяти */
        `LOADIMM: begin

            case (phase)

                2'b00: begin immresult        <= din; end
                2'b01: begin immresult[15:8]  <= din; end
                2'b10: begin immresult[23:16] <= din; end
                2'b11: begin immresult[31:24] <= din; end

            endcase

            /* Выход из процедуры при достижений ФАЗА = БИТНОСТЬ */
            if (phase == immsize) begin
                func  <= 1'b0;
                phase <= 1'b0;
            end else begin
                phase <= phase + 1'b1;
            end

            if (am)
                 ea <= ea + 1'b1; /* Если Immediate, считывается из SEGMENT:EA */
            else ip <= ip + 1'b1; /* Либо Immediate, считывается из CS:IP */

        end

    endcase

end


// ---------------------------------------------------------------------
// Расчет значения (Index * Scale) у SIB-байта */
// ---------------------------------------------------------------------

reg [31:0] sibtmp;
reg [31:0] sibimm;

always @* begin

    case (din[5:3])

        3'b000: sibtmp = eax;
        3'b001: sibtmp = ecx;
        3'b010: sibtmp = edx;
        3'b011: sibtmp = ebx;
        3'b100: sibtmp = 0;
        3'b101: sibtmp = ebp;
        3'b110: sibtmp = esi;
        3'b111: sibtmp = edi;

    endcase

    case (din[7:6])

        2'b00: sibimm =  sibtmp[31:0];           /* x1 */
        2'b01: sibimm = {sibtmp[30:0],   1'b0};  /* x2 */
        2'b10: sibimm = {sibtmp[29:0],  2'b00};  /* x4 */
        2'b11: sibimm = {sibtmp[28:0], 3'b000};  /* x8 */

    endcase

end

// Результат не зависит от тактовой частоты и выдается наиболее быстро
always @* begin

    // Таблица соответствий битностей
    // ------------------------------
    // osize   bitsize   Битность
    //     0     0       8
    //     0     1       16
    //     1     0       8
    //     1     1       32
    // ------------------------------

    // Операнд 1: Извлечение значения регистра А из регистрового файла
    case (A)

        //                        32 bit      16 bit       8 bit
        3'h0: R = bitsize ? (osize ? eax[31:0] : eax[15:0]) : eax[7:0];  // eax | ax | al
        3'h1: R = bitsize ? (osize ? ecx[31:0] : ecx[15:0]) : ecx[7:0];  // ecx | cx | cl
        3'h2: R = bitsize ? (osize ? edx[31:0] : edx[15:0]) : edx[7:0];  // edx | dx | dl
        3'h3: R = bitsize ? (osize ? ebx[31:0] : ebx[15:0]) : ebx[7:0];  // ebx | bx | bl
        3'h4: R = bitsize ? (osize ? esp[31:0] : esp[15:0]) : eax[15:8]; // esp | sp | ah
        3'h5: R = bitsize ? (osize ? ebp[31:0] : ebp[15:0]) : ecx[15:8]; // ebp | bp | ch
        3'h6: R = bitsize ? (osize ? esi[31:0] : esi[15:0]) : edx[15:8]; // esi | si | dh
        3'h7: R = bitsize ? (osize ? edi[31:0] : edi[15:0]) : ebx[15:8]; // edi | di | bh

    endcase

end

// Запись в регистры на негативном фронте
// Вход: w - разрешение записи, rc - значение, rn - номер регистра

always @(negedge clk25) begin // 20 нс

    if (w) begin

        case (rn)

            3'h0: if (bitsize & osize) eax <= rc; else if (bitsize) eax[15:0] <= rc[15:0]; else eax[ 7:0] <= rc[7:0];
            3'h1: if (bitsize & osize) ecx <= rc; else if (bitsize) ecx[15:0] <= rc[15:0]; else ecx[ 7:0] <= rc[7:0];
            3'h2: if (bitsize & osize) edx <= rc; else if (bitsize) edx[15:0] <= rc[15:0]; else edx[ 7:0] <= rc[7:0];
            3'h3: if (bitsize & osize) ebx <= rc; else if (bitsize) ebx[15:0] <= rc[15:0]; else ebx[ 7:0] <= rc[7:0];
            3'h4: if (bitsize & osize) esp <= rc; else if (bitsize) esp[15:0] <= rc[15:0]; else eax[15:8] <= rc[7:0];
            3'h5: if (bitsize & osize) ebp <= rc; else if (bitsize) ebp[15:0] <= rc[15:0]; else ecx[15:8] <= rc[7:0];
            3'h6: if (bitsize & osize) esi <= rc; else if (bitsize) esi[15:0] <= rc[15:0]; else edx[15:8] <= rc[7:0];
            3'h7: if (bitsize & osize) edi <= rc; else if (bitsize) edi[15:0] <= rc[15:0]; else ebx[15:8] <= rc[7:0];

        endcase

    end

end

// Запись в сегменты

endmodule
