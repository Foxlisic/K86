// Набор инструкции x8086
module processor(

    input   wire            clock,      // 10 mhz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [19:0]  o_addr,     // Указатель на память
    input   wire    [15:0]  i_data,     // Данные из памяти
    output  reg     [15:0]  o_data,     // Данные за запись
    output  reg             o_wr        // Строб записи в память

);

`define DECODE              3'h0        // Декодирование
`define FETCH_MODRM         3'h1
`define READ_UNALIGNED      3'h2
`define READ_ALIGNED_DISP   3'h3
`define READ_DATA           3'h4
`define READ_DATA_16        3'h5
`define EXECUTE             3'h6
`define WRITE               3'h7
`define WRITE_16            4'h8
`define WRITE_16E           4'h9
`define END_OPCODE          4'hA

`define ALU_ADD             3'h0
`define ALU_OR              3'h1
`define ALU_ADC             3'h2
`define ALU_SBB             3'h3
`define ALU_AND             3'h4
`define ALU_SUB             3'h5
`define ALU_XOR             3'h6
`define ALU_CMP             3'h7

// Выбор адреса. Адрес может указываться либо через READ=1, когда
// в cs:addr находится вычисленный эффективный адрес, либо READ=0,
// когда указатель находится на CS:IP

assign o_addr = read ? {cs[15:0], 4'h0} + addr :
                       {CS[15:0], 4'h0} + IP;

initial o_data = 16'h0000;

// ---------------------------------------------------------------------
// Регистры процессора
// ---------------------------------------------------------------------

// Регистры Общего Назначения
// Регистры в регистровом файле идут именно в этом порядке

reg     [15:0]    AX = 16'h3344; // AH : AL
reg     [15:0]    CX = 16'h2200; // CH : CL
reg     [15:0]    DX = 16'h0000; // DH : DL
reg     [15:0]    BX = 16'h0010; // BH : BL
reg     [15:0]    SP = 16'h0000;
reg     [15:0]    BP = 16'h0000;
reg     [15:0]    SI = 16'h2001;
reg     [15:0]    DI = 16'h0000;

// Сегментные
reg     [15:0]    ES = 16'h0000;
reg     [15:0]    CS = 16'h0000;
reg     [15:0]    SS = 16'h0000;
reg     [15:0]    DS = 16'h0000;

// Специальные
// O D I T | S Z 0 A 0 P 1 C
// B A 9 8 | 7 6 5 4 3 2 1 0
reg     [11:0] FLAGS = 12'h000;
reg     [15:0]    IP = 16'h0000;

// ---------------------------------------------------------------------
// Состояния
// ---------------------------------------------------------------------

reg     [3:0]       state = `DECODE;      // Состояние процессора
reg     [3:0]       next_state;           // Следующий state после операции WRITE
reg     [3:0]       micro;                // Номер микрооперации
reg     [15:0]      cs;                   // CS:ADDR Для чтений из памяти
reg     [15:0]      addr;

reg         read = 1'b0;          // Чтение из памяти
reg         wreg = 1'b0;          // Запись в регистр на след. такте
reg         wreg_bit = 1'b0;      // 0=8, 1=16
reg [2:0]   wreg_num = 3'h0;      // Номер регистра
reg [15:0]  wrdata = 16'h0000;    // Значение для записи в ПАМЯТЬ
reg [15:0]  regdata = 16'h0000;   // Значение для записи в РЕГИСТР

// // ---------------------------------------------------------------------
// Декодер
// ---------------------------------------------------------------------

// Поскольку из памяти читаются данные по словам, то текущий байт
// находится либо в нижнем байте слова (2 байта), либо в верхнем, это
// зависит от младшего бита o_addr

wire    [7:0]   current_byte = o_addr[0] ? i_data[15:8] : i_data[7:0];
wire    [7:0]   next_byte    = o_addr[0] ? i_data[7:0] : i_data[15:8];

wire            state_decode = state == `DECODE;
reg     [15:0]  opcode_cache = 8'h00;
wire    [7:0]   opcode       = state_decode ? current_byte : opcode_cache;

// Индикатор наличия ModRM-байта
reg             opcode_modrm;

// Блок для определения, есть ли у данного опкода [opcode] байт ModRM
// Если есть, будет запущен процесс его считывания.
always @* begin

    /*   Опкоды, у которых есть ModRM
         0 1 2 3  4 5 6 7  8 9 A B  C D E F
     00  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,   00xx_x0xx
     10  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     20  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     30  1,1,1,1, -,-,-,-, 1,1,1,1, -,-,-,-,
     40  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     50  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     60  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     70  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     80  1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,   1000_xxxx
     90  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     A0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     B0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     C0  1,1,-,-, 1,1,1,1, -,-,-,-, -,-,-,-,   1100_01xx 1100_000x
     D0  1,1,1,1, -,-,-,-, 1,1,1,1, 1,1,1,1,   1101_00xx 1101_1xxx
     E0  -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,
     F0  -,-,-,-, -,-,1,1, -,-,-,-, -,-,1,1,   1111_x11x
     */

    // Определить, имеет ли ModRM-байт данный опкод
    casex (opcode)

        8'b00_xxx0xx, //
        8'b10_00xxxx, // 80-8F
        8'b11_00000x, // C0-C1
        8'b11_0001xx, // C4-C7
        8'b11_0100xx, // D0-D3 Сдвиговые
        8'b11_011xxx, // D8-DF Сопроцессор
        8'b11_11x11x: // F6-F7, FE-FF Групповые
            opcode_modrm = 1'b1;
        default:
            opcode_modrm = 1'b0;

    endcase

end

// Основные индексные регистры
// ---------------------------------------------------------------------

reg             seg_overlap;        // Сигнализирует о том, что есть префикс сегмента
reg             seg_overlap_cache;  // .. на сеанс
reg     [1:0]   seg_number = 2'h3;  // Указатель номера 0..3 сегмента
reg     [1:0]   seg_number_cache;   //

reg     [1:0]   disp;               // Количество байт на Displacement
reg     [1:0]   disp_cache;
reg     [7:0]   modrm;              // Кешированное значение
reg     [15:0]  segp;               // Значение сегмента-префикса
reg     [15:0]  sege;               // Вычисленный сегмент с учетом DEFAULT ds:ss: либо PREFIX
reg     [15:0]  addrx;              // Вычисленный эффективный адрес ДО +displacement
reg     [15:0]  op1t;               // Значение регистра из ModRM[2:0]
reg     [15:0]  op1;                // - конечное
reg     [15:0]  op2t;               // Значение регистра из ModRM[5:3]
reg     [15:0]  op2;                // - конечное

wire    [15:0]  si_bx = SI + BX;
wire    [15:0]  di_bx = DI + BX;
wire    [15:0]  si_bp = SI + BP;
wire    [15:0]  di_bp = DI + BP;

// В зависимости от того, какой исполняется сейчас этап
wire            seg_override = (state_decode ? seg_overlap : seg_overlap_cache);
wire    [1:0]   seg_id       = (state_decode ? seg_number  : seg_number_cache);

// Вычисление эффективного адреса ModRM
always @* begin

    // Перегруженный, либо дефолтный сегмент
    case (seg_id)

        3'h0: segp = ES;
        3'h1: segp = CS;
        3'h2: segp = SS;
        3'h3: segp = DS;

    endcase

    // Рассчитанный сегмент по умолчанию
    casex (next_byte)

        8'b00_xxx_11x: sege = seg_override ? segp : DS; // DS: по умолчанию
        8'bxx_xxx_x0x: sege = seg_override ? segp : DS;
        8'bxx_xxx_110: sege = seg_override ? segp : SS; // SS: по умолчанию
        8'bxx_xxx_01x: sege = seg_override ? segp : SS;
        default:       sege = DS;

    endcase

    // Эффективный адрес
    casex (next_byte)

        8'bxx_xxx_000: addrx = si_bx;
        8'bxx_xxx_001: addrx = di_bx;
        8'bxx_xxx_010: addrx = si_bp;
        8'bxx_xxx_011: addrx = di_bp;
        8'bxx_xxx_100: addrx = SI;
        8'bxx_xxx_101: addrx = DI;
        8'b00_xxx_110: addrx = 16'h0000;
        8'bxx_xxx_110: addrx = BP;
        8'bxx_xxx_111: addrx = BX;

    endcase

    // Количество байт 0/1/2 на displacement
    casex (next_byte)

        8'b01_xxx_xxx: disp = 2'b01; // disp-8
        8'b00_xxx_110: disp = 2'b10; // disp-16
        8'b10_xxx_xxx: disp = 2'b10;
        default:       disp = 2'b00; // disp-0

    endcase

    // Операнд 1: reg/m8
    case (opcode[1] ? next_byte[5:3] : next_byte[2:0])

        3'b000: op1t = opcode[0] ? AX : AX[7:0];
        3'b001: op1t = opcode[0] ? CX : CX[7:0];
        3'b010: op1t = opcode[0] ? DX : DX[7:0];
        3'b011: op1t = opcode[0] ? BX : BX[7:0];
        3'b100: op1t = opcode[0] ? SP : AX[15:8];
        3'b101: op1t = opcode[0] ? BP : CX[15:8];
        3'b110: op1t = opcode[0] ? SI : DX[15:8];
        3'b111: op1t = opcode[0] ? DI : BX[15:8];

    endcase

    // Операнд 2: reg
    case (opcode[1] ? next_byte[2:0] : next_byte[5:3])

        3'b000: op2t = opcode[0] ? AX : AX[7:0];
        3'b001: op2t = opcode[0] ? CX : CX[7:0];
        3'b010: op2t = opcode[0] ? DX : DX[7:0];
        3'b011: op2t = opcode[0] ? BX : BX[7:0];
        3'b100: op2t = opcode[0] ? SP : AX[15:8];
        3'b101: op2t = opcode[0] ? BP : CX[15:8];
        3'b110: op2t = opcode[0] ? SI : DX[15:8];
        3'b111: op2t = opcode[0] ? DI : BX[15:8];

    endcase

end

// ---------------------------------------------------------------------
// АРИФМЕТИКО-ЛОГИЧЕСКОЕ УСТРОЙСТВО
// ---------------------------------------------------------------------

reg     [2:0]  alu_mode; // Режим АЛУ (8 режимов)
reg     [16:0] alu_res;
reg     [11:0] alu_flag;
reg            alu_bits; // 0=8, 1=16

wire    alu_parity = alu_res[7] ^ alu_res[6] ^ alu_res[5] ^
                            alu_res[4] ^ alu_res[3] ^ alu_res[2] ^
                            alu_res[1] ^ alu_res[0] ^ 1'b1;

wire    alu_zero8   = alu_res[7:0]  == 8'h00;
wire    alu_zero16  = alu_res[15:0] == 16'h0000;
wire    alu_aux_add = ((op1[3] | op2[3]) & !alu_res[3]) | (op1[3]*op2[3]*alu_res[3]);
wire    alu_aux_sub = ((op2[3] ^ alu_res[3]) & !op1[3]) | (op2[3] & alu_res[3]);
wire    alu_overflow_add8  = (op1[7]  ^ op2[7]   ^ 1'b1) & (op1[7]  ^ alu_res[7]);
wire    alu_overflow_sub8  = (op1[7]  ^ op2[7]         ) & (op1[7]  ^ alu_res[7]);
wire    alu_overflow_add16 = (op1[15] ^ op2[15]  ^ 1'b1) & (op1[15] ^ alu_res[15]);
wire    alu_overflow_sub16 = (op1[15] ^ op2[15]        ) & (op1[15] ^ alu_res[15]);

always @* begin

    // Расчет значений
    case (alu_mode)

        `ALU_ADD: alu_res = op1 + op2;
        `ALU_OR:  alu_res = op1 | op2;
        `ALU_ADC: alu_res = op1 + op2 + FLAGS[0];
        `ALU_SBB: alu_res = op1 - op2 - FLAGS[0];
        `ALU_AND: alu_res = op1 & op2;
        `ALU_SUB, `ALU_CMP: alu_res = op1 - op2;
        `ALU_XOR: alu_res = op1 ^ op2;

    endcase

    // Расчет флагов 8/16 бит
    case (alu_mode)

        `ALU_ADD, `ALU_ADC: alu_flag = {
            /* 11 */ alu_bits ? alu_overflow_add16 : alu_overflow_add8,
            /* .. */ FLAGS[10:8],
            /* 7  */ alu_bits ? alu_res[15] : alu_res[7],
            /* 6  */ alu_bits ? alu_zero16 : alu_zero8,
            /* 5  */ 1'b0,
            /* 4  */ alu_aux_add,
            /* 3  */ 1'b0,
            /* 2  */ alu_parity,
            /* 1  */ 1'b1,
            /* 0  */ alu_bits ? alu_res[16] : alu_res[8]
        };

        `ALU_SBB, `ALU_SUB, `ALU_CMP: alu_flag = {
            /* 11 */ alu_bits ? alu_overflow_sub16 : alu_overflow_sub8,
            /* .. */ FLAGS[10:8],
            /* 7  */ alu_bits ? alu_res[15] : alu_res[7],
            /* 6  */ alu_bits ? alu_zero16 : alu_zero8,
            /* 5  */ 1'b0,
            /* 4  */ alu_aux_sub,
            /* 3  */ 1'b0,
            /* 2  */ alu_parity,
            /* 1  */ 1'b1,
            /* 0  */ alu_bits ? alu_res[16] : alu_res[8]
        };

        `ALU_OR, `ALU_AND, `ALU_XOR: alu_flag = {
            /* 11 */ 1'b0,
            /* .. */ FLAGS[10:8],
            /* 7  */ alu_bits ? alu_res[15] : alu_res[7],
            /* 6  */ alu_bits ? alu_zero16 : alu_zero8,
            /* 5  */ 1'b0,
            /* 4  */ FLAGS[4],
            /* 3  */ 1'b0,
            /* 2  */ alu_parity,
            /* 1  */ 1'b1,
            /* 0  */ 1'b0
        };

    endcase

end

// ---------------------------------------------------------------------
// Модули исполнения инструкции
// ---------------------------------------------------------------------

always @(posedge clock) begin

    case (state)

    // Полный декодер инструкции: ModRM, Imm. После декодинга кеш сдвигается.
    `DECODE: begin

        wreg    <= 1'b0;      // На обратном фронте не писать в регистр
        o_wr    <= 1'b0;      // Выключить запись
        micro   <= 1'b0;      // Номер микрооперации

        casex (opcode)

            8'b001x_x110: /* Префикс сегментов ES: CS: SS: DS: */ begin

                seg_overlap <= 1'b1;
                seg_number  <= current_byte[4:3];
                IP          <= IP + 1'b1;

            end

            // 8'b0110_01xx, // 32-bit 64 FS: 65 GS: 66 Op32 67 Addr32
            // 8'b1001_1011, // WAIT
            // 8'b1111_0000, // LOCK
            // 8'b1001_001x, // REP/REPZ
            // 8'b0000_1111: // Opcode Extension

            default: /* Чтение опкода */ begin

                if /* Опкод имеет ModRM */ (opcode_modrm) begin

                    if /* Байт ModRM ещё не получен */ (IP[0]) begin

                        state <= `FETCH_MODRM;

                    end else begin

                        // Переписать данные с декодера ModRM
                        op1  <= op1t;
                        op2  <= op2t;
                        cs   <= sege;
                        addr <= addrx;
                        disp_cache <= disp;
                        modrm <= next_byte;

                        if /* Сразу выполнить код */ (next_byte[7:6] == 2'b11) begin

                            state <= `EXECUTE;

                        end else /* Читать операнд из памяти (+d8/16) */ case (disp)

                            // Прочитать Disp8/16
                            2'b01, 2'b10: state <= `READ_ALIGNED_DISP;

                            // Иначе к чтению операнда
                            default: begin

                                read    <= 1'b1;
                                state   <= `READ_DATA;

                            end

                        endcase

                    end

                    IP <= IP + 2'h2; // Опкод(1) + ModRm(1)

                // Без ModRM байта, перейти к исполнению кода
                end else begin

                    state   <= `EXECUTE;
                    IP      <= IP + 1'b1;

                end

                // Сохранить опкод
                opcode_cache <= current_byte;

                // Сохранить информацию об overlap / seg_id
                seg_overlap_cache   <= seg_overlap;
                seg_number_cache    <= seg_number;

                // Сброс значений для следующего сеанса
                seg_overlap         <= 1'b0;
                seg_number          <= 2'h3;

                // Распознание режима работы АЛУ
                alu_bits  <= opcode[0];
                alu_mode  <= opcode[5:3]; // Потом может поменяться

            end

        endcase

    end

    // ЧТЕНИЕ DISPLACEMENT 8 ИЛИ 16.
    // Поскольку тут ВЫРОВНЕННЫЕ данные, то читается за 1 раз
    `READ_ALIGNED_DISP: begin

        if /* 8-bit */ (disp_cache[0]) begin

            addr <= addr + {{8{current_byte[7]}}, current_byte};
            IP   <= IP + 1'b1;

        end
        else /* 16-bit */  begin

            addr <= addr + {next_byte, current_byte};
            IP   <= IP + 2'h2;

        end

        read  <= 1'b1;
        state <= `READ_DATA;

    end

    // Чтение НЕВЫРОВНЕННОГО ModRM +d8 если он задан
    `FETCH_MODRM: begin

        // Переписать данные с декодера ModRM
        op1   <= op1t;
        op2   <= op2t;
        cs    <= sege;
        modrm <= next_byte;

        if /* Сразу выполнить код */ (next_byte[7:6] == 2'b11) begin

            state <= `EXECUTE;

        end else /* Читать операнд из памяти (+d8/16) */ begin

            case (disp)

                // Прочитать Disp8 и перейти к чтению опкода
                2'b01: begin

                    addr    <= addrx + {{8{current_byte[7]}}, current_byte};
                    state   <= `READ_DATA;
                    read    <= 1'b1;
                    IP      <= IP + 1'b1;

                end

                // Писать младшую часть Disp16
                2'b10: begin

                    addr    <= addrx + current_byte;
                    state   <= `READ_UNALIGNED;
                    IP      <= IP + 2'h2;

                end

                // Начать чтение сразу же, если нет displacement 8/16
                default: begin

                    read    <= 1'b1;
                    addr    <= addrx;
                    state   <= `READ_DATA;

                end

            endcase

        end
    end

    // Чтение НЕВЫРОВНЕННОГО +d16
    `READ_UNALIGNED: begin

        state       <= `READ_DATA;
        read        <= 1'b1;
        addr[15:8]  <= addr[15:8] + next_byte;

    end

    // Чтение 8 или 16 битных данных (в зависимости от выравнивания)
    `READ_DATA: begin

        if /* WORD: Читать слово */ (opcode[0]) begin

            if /* Не выровнено */ (addr[0]) begin

                if (opcode[1]) op2 <= i_data[15:8];
                          else op1 <= i_data[15:8];

                addr  <= addr + 1'b1;
                state <= `READ_DATA_16;

            end else /* Выровнено */ begin

                if (opcode[1]) op2 <= i_data[15:0];
                          else op1 <= i_data[15:0];

                state <= `EXECUTE;

            end

        end else /* BYTE: Читать байт */ begin

            if (opcode[1]) op2 <= current_byte;
                      else op1 <= current_byte;

            state <= `EXECUTE;

        end

    end

    // Прочитать старший байт слова данных
    `READ_DATA_16: begin

        if (opcode[1]) op2[15:8] <= i_data[7:0];
                  else op1[15:8] <= i_data[7:0];

        addr  <= addr - 1'b1;
        state <= `EXECUTE;

    end

    // Исполнение опкода
    `EXECUTE: begin

        casex(opcode)

            // Базовые АЛУ-операции: 1T либо 3T/5T
            8'b00_xxx0xx: begin

                wreg_bit <= alu_bits;
                wrdata   <= alu_res;
                regdata  <= alu_res;
                FLAGS    <= alu_flag;
                
                if /* операция CMP */ (alu_mode == `ALU_CMP) 
                begin read <= 1'b0; state <= `DECODE; end
                
                else if /* запись результата в регистр 1T */ (opcode[1])
                begin wreg_num <= modrm[5:3]; wreg <= 1'b1; read <= 1'b0; state <= `DECODE; end

                else begin

                    if /* выбрана запись в регистр 1T */ (modrm[7:6] == 2'b11)
                    begin wreg_num <= modrm[2:0]; wreg <= 1'b1; read <= 1'b0; state <= `DECODE; end
                    else /* запись результата в память */ begin state <= `WRITE; next_state <= `DECODE; end

                end

            end
            
            // 80h-83h Арифметика
            8'b10_000_0xx: begin
            
                wreg_bit <= alu_bits;
                alu_mode <= modrm[5:3];
                op1      <= opcode[1] ? op2 : op1;      // Регистр или память (проверить)
                op2      <= current_byte;               // .. читать i8
                read     <= 1'b0;
                // IP       <= IP + 1'b1;
                
                
            
            end

        endcase

    end

    // ---------------------------
    // Запись данных в память
    // ---------------------------
    
    // wreg_bit(8/16) | wrdata(8/16) | cs:addr - адрес для записи
    `WRITE: begin

        o_wr  <= 1'b1;
        wreg  <= 1'b0;

        if /* 16-бит */ (wreg_bit) begin

             if /* не выровнено */ (addr[0])
             begin o_data <= {wrdata[7:0], i_data[7:0]}; state <= `WRITE_16; end
             else /* выровнено */ begin o_data <= wrdata; state <= `END_OPCODE; end

        end
        else begin

            if (addr[0]) /* старший */ o_data <= {wrdata[7:0],  i_data[7:0]};
                    else /* младший */ o_data <= {i_data[15:8], wrdata[7:0]};

            state <= `END_OPCODE;

        end

    end

    // Невыровненный WORD: a) Прочитать следующий WORD, b) Записать младший байт
    `WRITE_16:  begin o_wr <= 1'b0; addr <= addr + 1'b1; state <= `WRITE_16E; end
    `WRITE_16E: begin o_wr <= 1'b1; o_data <= {i_data[15:8], wrdata[15:8]}; state <= `END_OPCODE; end    
    `END_OPCODE: begin o_wr <= 1'b0; read = 1'b0; state <= next_state; end

    endcase
end

// ---------------------------------------------------------------------
// Блок для записи значений регистров
// >> НА ОБРАТНОМ ФРОНТЕ <<

// wreg      Активация
// wreg_bit  0=8, 1=16
// wreg_num  0..7
// regdata   8/16 данные

// ---------------------------------------------------------------------

always @(negedge clock) begin

    if (wreg) begin

        if (wreg_bit)

            case (wreg_num)

                3'b000: AX <= regdata;
                3'b001: CX <= regdata;
                3'b010: DX <= regdata;
                3'b011: BX <= regdata;
                3'b100: SP <= regdata;
                3'b101: BP <= regdata;
                3'b110: SI <= regdata;
                3'b111: DI <= regdata;

            endcase

        else

            case (wreg_num)

                3'b000: AX[7:0] <= regdata[7:0];
                3'b001: CX[7:0] <= regdata[7:0];
                3'b010: DX[7:0] <= regdata[7:0];
                3'b011: BX[7:0] <= regdata[7:0];
                3'b100: AX[15:8] <= regdata[7:0];
                3'b101: CX[15:8] <= regdata[7:0];
                3'b110: DX[15:8] <= regdata[7:0];
                3'b111: BX[15:8] <= regdata[7:0];

            endcase

    end

end

endmodule
