// Набор инструкции x8086
module processor(

    input   wire            clock,      // 10 mhz
    input   wire            locked,     // Если =0, PLL не сконфигурирован
    input   wire            m_ready,    // Готовность данных из памяти (=1 данные готовы)
    output  wire    [19:0]  o_addr,     // Указатель на память
    input   wire    [15:0]  i_data,     // Данные из памяти
    output  wire     [15:0]  o_data,     // REG Данные за запись
    output  reg             o_wr        // Строб записи в память

);

`define I_FETCH             3'h0        // Этап считывания данных
`define I_DECODE            3'h1        // Декодирование
`define I_READ_DATA         3'h2        // Чтение из памяти
`define I_READ_DATA_WIDE    3'h3        // Чтение из памяти
`define I_EXECUTE           3'h4        // Исполнение инструкции

assign o_addr = alt ? {segment[15:0], 4'h0} + address : {r_cs[15:0], 4'h0} + current;
assign o_data = r_ax;


// ---------------------------------------------------------------------
// Состояния
// ---------------------------------------------------------------------

// Кеш инструкции
reg [47:0] icache;

reg             prefix_0F = 1'b0;       // Есть префикс расширения
reg             has_prefixed;           // Префиксированная
reg             has_modrm_byte;         // Инструкция имеет ModRM байт

reg     [2:0]   state = 1'b0;                        // Состояние процессора
reg             alt = 1'b0;                          // =0 CS:IP, =1 segment:address
reg     [15:0]  segment;
reg     [15:0]  address;                             // Адрес для чтения/записи
reg     [15:0]  current = 16'h0;                     // Адрес, откуда загружать кеш
reg             wsize;                               // Чтение BYTE (0) WORD (1)
reg             target;                              // =0 (Прямой порядок операндов), =1 Обратный
reg     [2:0]   icp = 2'h0;                          // Байт, куда догрузить кеш инструкции
reg     [2:0]   length = 1'b0;                       // Длина инструкции (1..6)
reg     [2:0]   modrm_length;
reg             instruction_done = 1'b1;             // Признак только что выполненной инструкции
reg             segment_override = 1'b0;             // Инструкция имеет префикс
reg     [2:0]   segment_override_num = 1'b0;         // Если имеет, то указывается, какой именно
wire    [7:0]   modrm_byte = prefix_0F ? icache[23:16] : icache[15:8];

// Операнды
wire    [15:0]  op1 = target ? _op2 : _op1;
wire    [15:0]  op2 = target ? _op1 : _op2;


// ---------------------------------------------------------------------
// Декодер
// ---------------------------------------------------------------------

always @* begin

    // Определение наличия префикса
    // -----------------------------------------------------------------
    
    casex (icache[7:0])

        8'b001x_x110, // Segment Override 26,2E,36,3E
        8'b0110_01xx, // 32-bit 64 FS: 65 GS: 66 Op32 67 Addr32
        8'b1001_1011, // WAIT
        8'b1111_0000, // LOCK
        8'b1001_001x, // REP/REPZ
        8'b0000_1111: // Opcode Extension
        
            has_prefixed = 1'b1;
            
        default:
        
            has_prefixed = 1'b0;

    endcase

    // ТЕСТ ModRM
    // -----------------------------------------------------------------

    /*   0 1 2 3  4 5 6 7  8 9 A B  C D E F
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
     
0F 00    1,1,1,1, -,-,-,-, -,-,-,-, -,1,-,1,   0000_01xx 0000_10xx 0000_11x0
0F 10    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F 20    1,1,1,1, 1,-,1,-, 1,1,1,1, 1,1,1,1,
0F 30    -,-,-,-, -,-,-,-, 1,-,1,-, -,-,-,-,   0011_0xxx 0011_10x1 0011_11xx
0F 40    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F 50    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F 60    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F 70    1,1,1,1, 1,1,1,-, 1,1,-,-, 1,1,1,1,   0111_0111 0111_100x
0F 80    -,-,-,-, -,-,-,-, -,-,-,-, -,-,-,-,   1000_xxxx
0F 90    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F A0    -,-,-,1, 1,1,-,-, -,-,-,1, 1,1,1,1,   1011_000x 1011_0010 1011_011x 1011_100x 1011_1010
0F B0    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F C0    1,1,1,1, 1,1,1,1, -,-,-,-, -,-,-,-,   1101_1xxx
0F D0    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F E0    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
0F F0    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,0,   1111_1111
    */
    
    // Дополнительные 0F-опкоды -- подумать над этим
    if (icache[7:0] == 8'h0F)

        casex(icache[15:8])
        
            8'b0000_01xx, 8'b0000_10xx, 8'b0000_11x0,
            8'b0011_0xxx, 8'b0011_10x1, 8'b0011_11xx,
            8'b0111_0111, 8'b0111_100x,
            8'b1000_xxxx,
            8'b1011_000x, 8'b1011_0010, 8'b1011_011x, 8'b1011_100x, 8'b1011_1010,
            8'b1101_1xxx,
            8'b1111_1111:
            
                has_modrm_byte = 1'b0;
                
            default:
            
                has_modrm_byte = 1'b1;

        endcase
    
    // Базовые опкоды
    else
    
        // Определить, имеет ли ModRM-байт данный опкод
        casex(icache[7:0]) 
        
            8'b00_xxx0xx, //       Арифметические
            8'b10_00xxxx, // 80-8F Разные арифметические
            8'b11_00000x, // C0-C1
            8'b11_0001xx, // C4-C7
            8'b11_0100xx, // D0-D3 Сдвиговые
            8'b11_011xxx, // D8-DF Сопроцессор 
            8'b11_11x11x: // F6-F7, FE-FF Групповые 
            
                has_modrm_byte = 1'b1;
                
            default:
            
                has_modrm_byte = 1'b0;
        
        endcase
       
end

// ---------------------------------------------------------------------
// Регистры процессора
// ---------------------------------------------------------------------

reg     [15:0]  r_ip = 16'h0000;
reg     [15:0]  n_ip = 16'h0000;        // Следующий IP
reg     [15:0]  r_ax = 16'h0000;
reg     [15:0]  r_bx = 16'h0000;
reg     [15:0]  r_cx = 16'h0000;
reg     [15:0]  r_dx = 16'h0000;
reg     [15:0]  r_sp = 16'h0000;
reg     [15:0]  r_bp = 16'h0000;
reg     [15:0]  r_si = 16'h0000;
reg     [15:0]  r_di = 16'h0000;
reg     [15:0]  r_es = 16'h0000;
reg     [15:0]  r_cs = 16'h0000;
reg     [15:0]  r_ss = 16'h0000;
reg     [15:0]  r_ds = 16'h0000;
reg     [15:0]  r_fs = 16'h0000;
reg     [15:0]  r_gs = 16'h0000;

// ---------------------------------------------------------------------
// Расчёт длины инструкции
// ---------------------------------------------------------------------

always @* begin

    // Это префикс. Его длина всегда = 1
    if (has_prefixed) begin

        length = 3'h1;        
    
    end
    // Имеется ModRM-байт, декодировать длину
    else if (has_modrm_byte) begin
    
        casex (modrm_byte)

            8'b00_xxx_110: modrm_length = 3'h4; // 1+1+2 disp16
            8'b00_xxx_xxx: modrm_length = 3'h2; // 1+1   none
            8'b01_xxx_xxx: modrm_length = 3'h3; // 1+1+1 disp8            
            8'b10_xxx_xxx: modrm_length = 3'h4; // 1+1+2 disp16
            8'b11_xxx_xxx: modrm_length = 3'h2; // 1+1   reg

        endcase
        
        // Определение Immediate 8/16
        // Group Arith, Mov Immediate
        casex (icache[7:0])
        
            8'b1000_00xx, 8'b1100_011x: length = (modrm_length + icache[0]) + 1'b1;
            // F6/F7
            // FF
            default: length = modrm_length;
        
        endcase    

    end
    
    // Пока что +1 
    else length = 3'h1;

end

// Основные индексные регистры
// ---------------------------------------------------------------------

wire    [15:0]  si_bx = r_si + r_bx;
wire    [15:0]  di_bx = r_di + r_bx;
wire    [15:0]  si_bp = r_si + r_bp;
wire    [15:0]  di_bp = r_si + r_bp;
// Предварительно
reg     [15:0]  p_addr;
reg     [15:0]  p_segment;
// Окончательно
reg     [15:0]  e_address;
reg     [15:0]  e_segment;
// Операнд 1 и 2
reg     [15:0]  w_op1; reg [15:0] _op1;
reg     [15:0]  w_op2; reg [15:0] _op2;

reg     alu_enable;
reg     immediate_size;
reg     operand_is_immediate;

// Вычисление эффективного адреса ModRM
always @* begin
    
    // Перегруженный сегмент   
    case (segment_override_num) 

        3'h0: p_segment = r_es;
        3'h1: p_segment = r_cs;
        3'h2: p_segment = r_ss;
        3'h3: p_segment = r_ds;
        3'h4: p_segment = r_fs;
        3'h5: p_segment = r_gs;

    endcase    
    
    // Эффективный сегмент
    casex (modrm_byte[7:0]) 

        // DS: по умолчанию
        8'b00_xxx_11x: e_segment = segment_override ? p_segment : r_ds;
        8'bxx_xxx_x0x: e_segment = segment_override ? p_segment : r_ds;
    
        // SS: по умолчанию
        8'bxx_xxx_110: e_segment = segment_override ? p_segment : r_ss;
        8'bxx_xxx_01x: e_segment = segment_override ? p_segment : r_ss;
    
    endcase

    // Эффективный адрес
    casex (modrm_byte[7:0]) 

        8'bxx_xxx_000: p_addr = si_bx;
        8'bxx_xxx_001: p_addr = di_bx;
        8'bxx_xxx_010: p_addr = si_bp;
        8'bxx_xxx_011: p_addr = di_bp;
        8'bxx_xxx_100: p_addr = r_si;
        8'bxx_xxx_101: p_addr = r_di;
        8'b00_xxx_110: p_addr = icache[31:16]; // disp16
        8'bxx_xxx_110: p_addr = r_bp;
        8'bxx_xxx_111: p_addr = r_bx;
    
    endcase
    
    // Displacement 8/16
    casex (modrm_byte[7:0]) 
    
        // displacement-8
        8'b01_xxx_xxx: e_address = p_addr + {{8{icache[23]}}, icache[23:16]}; 
        // displacement-16
        8'b10_xxx_xxx: e_address = p_addr + icache[31:16];
        default:       e_address = p_addr;

    endcase
    
    // Значения регистров для операндов op1/op2
    
    // opcode[1]:
    // 0 = op1 reg/m, op2 - reg
    // 1 = op1 reg,   op2 - reg/m
    
    // Операнд 1: reg/m8
    case (modrm_byte[2:0])
    
        3'b000: w_op1 = icache[0] ? r_ax : r_ax[7:0];
        3'b001: w_op1 = icache[0] ? r_cx : r_cx[7:0];
        3'b010: w_op1 = icache[0] ? r_dx : r_dx[7:0];
        3'b011: w_op1 = icache[0] ? r_bx : r_bx[7:0];
        3'b100: w_op1 = icache[0] ? r_sp : r_ax[15:8];
        3'b101: w_op1 = icache[0] ? r_bp : r_cx[15:8];
        3'b110: w_op1 = icache[0] ? r_si : r_dx[15:8];
        3'b111: w_op1 = icache[0] ? r_di : r_bx[15:8];
    
    endcase
    
    // Операнд 2: reg
    case (modrm_byte[5:3])
    
        3'b000: w_op2 = icache[0] ? r_ax : r_ax[7:0];
        3'b001: w_op2 = icache[0] ? r_cx : r_cx[7:0];
        3'b010: w_op2 = icache[0] ? r_dx : r_dx[7:0];
        3'b011: w_op2 = icache[0] ? r_bx : r_bx[7:0];
        3'b100: w_op2 = icache[0] ? r_sp : r_ax[15:8];
        3'b101: w_op2 = icache[0] ? r_bp : r_cx[15:8];
        3'b110: w_op2 = icache[0] ? r_si : r_dx[15:8];
        3'b111: w_op2 = icache[0] ? r_di : r_bx[15:8];
    
    endcase

end

// Определение типа инструкции
always @* begin

    n_ip = r_ip + length;
        
end

// ---------------------------------------------------------------------
// Модули исполнения инструкции
// ---------------------------------------------------------------------

always @(posedge clock) begin

    case (state)    
    
    // =================================================================
    // Загрузка данных в кеш-линию инструкции
    // =================================================================
    
    `I_FETCH: begin
    
        // Очистка предыдущих значений только по завершении инструкции    
        if (instruction_done) begin
            
            segment_override     <= 1'b0;
            segment_override_num <= 2'b11; // 3=DS
            prefix_0F            <= 2'b0;
            operand_is_immediate <= 1'b0;
            immediate_size       <= 1'b0;
            alu_enable           <= 1'b0;
        
        end
        
        // Подготавливаем новую инструкцию
        instruction_done <= 1'b0;
        
        // Невыровненные данные. Сначала в один из 6 байт загружается
        // старший байт не выровненных данных. После этого данные 
        // выравниваются (current[0] <-- 0) и происходит загрузка следующих 2 байт
        if (current[0]) begin
        
            case (icp) 
            
                3'h0: begin icache[7:0]   <= i_data[15:8]; end
                3'h1: begin icache[15:8]  <= i_data[15:8]; end
                3'h2: begin icache[23:16] <= i_data[15:8]; end
                3'h3: begin icache[31:24] <= i_data[15:8]; end
                3'h4: begin icache[39:32] <= i_data[15:8]; end
                3'h5: begin icache[47:40] <= i_data[15:8]; state <= `I_DECODE; end
            
            endcase

            current <= current + 1'b1;
            icp     <= icp + 1'b1;
        
        end else begin
        
            case (icp)
            
                3'h0: begin icp <= 3'h2; icache[15:0]  <= i_data[15:0]; end
                3'h1: begin icp <= 3'h3; icache[23:8]  <= i_data[15:0]; end
                3'h2: begin icp <= 3'h4; icache[31:16] <= i_data[15:0]; end
                3'h3: begin icp <= 3'h5; icache[39:24] <= i_data[15:0]; end
                3'h4: begin icp <= 3'h0; icache[47:32] <= i_data[15:0]; state <= `I_DECODE; end
                3'h5: begin icp <= 3'h0; icache[47:40] <= i_data[ 7:0]; state <= `I_DECODE; end    
            
            endcase
                    
            current <= current + 2'h2;
            icp     <= icp + 2'h2;

        end
    
    end
    
    // =================================================================
    // Полный декодер инструкции: ModRM, Imm. После декодинга кеш сдвигается.
    // =================================================================
    
    `I_DECODE: begin
    
        // Сдвиг кеша инструкции в зависимости от длины инструкции
        // При успешном BRANCH, тут будет length = 6

        case (length)
        
            3'h1: begin icp <= 3'h5; icache[39:0] <= icache[47:8];  end
            3'h2: begin icp <= 3'h4; icache[31:0] <= icache[47:16]; end
            3'h3: begin icp <= 3'h3; icache[23:0] <= icache[47:24]; end
            3'h4: begin icp <= 3'h2; icache[15:0] <= icache[47:32]; end
            3'h5: begin icp <= 3'h1; icache[ 7:0] <= icache[47:40]; end
            3'h6: begin icp <= 3'h0; end

        endcase

        // if (branched) // Другой случай, когда происходит перенос по причине Branch

        current <= (r_ip + 3'h6);   // Всегда +6 (размер кеша инструкции) от текущего r_ip
        r_ip    <= n_ip;            // Следующая инструкция
        
        // Определение типа инструкции
        //casex(icache[7:0])
    
            // ADD rm,reg
            // 8'b00xx_x0xx: alu_enable = 1'b1; alu_function = icache[5:3]; operand_is_immediate = 1'b0;
            // 8'b00xx_010x: alu_enable = 1'b1; alu_function = icache[5:3]; operand_is_immediate = 1'b1; immediate_size = icache[0];
            
            // 8'b000x_x110:    
        
        //endcase

        // В первую очередь, префиксы
        if (has_prefixed) begin
        
            state <= `I_FETCH;
            casex (icache[7:0])
            
                8'b0000_1111: prefix_0F <= 1'b1;
            
                // es: cs: ss: ds
                8'b001x_x110: begin segment_override <= 1'b1; segment_override_num <= {1'b0,icache[4:3]}; end
                
                // fs: gs:
                8'b0110_010x: begin segment_override <= 1'b1; segment_override_num <= {1'b1,icache[1:0]}; end
                
                // default: .. other

            endcase        
        
        end    
        // ModRM-инструкции
        else if (has_modrm_byte) begin
        
            // Отметить, что инструкция началась
            instruction_done <= 1'b1;

            // Сохранение полученных операндов из секции разбора ModRM
            // При установке target, op1/op2 будут правильно указывать далее
            _op1    <= w_op1;
            _op2    <= w_op2;
            target  <= icache[1];
            
            // Если в modrm есть эффективный адрес, то читать его
            if (modrm_byte[7:6] != 2'b11) begin
            
                alt     <= 1'b1;
                wsize   <= icache[0];
                segment <= e_segment;
                address <= e_address;
                state   <= `I_READ_DATA;
            
            end else begin

                state  <= `I_EXECUTE;
                
            end
        
        end
        // Все остальные
        else begin

            state <= `I_EXECUTE;
            
        end

    end    

    // =================================================================
    // Читать данные (1 или 2 байт) в Op1/Op2
    // wsize  = 0 Byte, =1 Word
    // =================================================================

    `I_READ_DATA: begin
    
        // WORD
        if (wsize) begin

            if (address[0]) begin       // Не выровнен
            
                state   <= `I_READ_DATA_WIDE;            
                address <= address + 1'h1;             
                _op1    <= i_data[15:8];

            end else begin              // Выровнен

                state   <= `I_EXECUTE;
                _op1    <= i_data[15:0];

            end        

        // BYTE
        end else begin

            state <= `I_EXECUTE;
            _op1  <= address[0] ? i_data[15:8] : i_data[7:0];

        end

    end
    
    // Прочитать невыровненные данные
    `I_READ_DATA_WIDE: begin 
    
        state       <= `I_EXECUTE;
        _op1[15:8]  <= i_data[7:0];
        address     <= address - 1'h1;

    end
    
    `I_EXECUTE: begin
    
        state <= `I_FETCH;
    
    end

    endcase
end

endmodule
