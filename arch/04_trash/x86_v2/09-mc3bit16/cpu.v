module cpu
(
    input   wire        clock,
    input   wire        reset_n,
    input   wire        locked,

    // Физический интерфейс ввода-вывода
    output  wire [19:0] address,        // 2^20 = 1MB
    input   wire [ 7:0] i_data,         // Входящие данные
    output  reg  [ 7:0] o_data,         // Данные на запись
    output  reg         we              // Разрешение записи
);

`include "regfile.v"
`include "control.v"
`include "alu.v"

// Выбор памяти
assign address = cursor ? {segment, 4'h0} + ea : {cs, 4'h0} + ip;

always @(posedge clock)
if (reset_n == 1'b0 || locked == 1'b0) begin cs <= 0; ip <= 0; t <= 0; end
else if (locked) begin

    we <= 1'b0;

    case (t)

        // Подготовка инструкции к выполнению
        // Заметка: сюда процессор может приходить с we=1 или cursor=1
        PREPARE: begin

            t           <= MAIN;
            tn          <= RUN;
            m           <= 0;
            s           <= 0;
            opcode      <= 0;
            cursor      <= 0;
            modrm       <= 0;
            segment     <= ds;
            override    <= 0;
            rep         <= 0;

        end

        // Получение опкода и разбор инструкции
        MAIN: begin

            ip      <= ip + 1;
            opcode  <= i_data;
            size    <= i_data[0];
            dir     <= i_data[1];

            casex (i_data)

                // Префиксы ES: CS: SS: DS:
                8'h26: begin override <= 1; segment <= es; end
                8'h2E: begin override <= 1; segment <= cs; end
                8'h36: begin override <= 1; segment <= ss; end
                8'h3E: begin override <= 1; segment <= ds; end                
                8'h0F, 8'h64, 8'h65, 8'h66, 8'h67: t <= ERROR; // 32-х префиксы
                8'hF0, 8'hF2, 8'hF3: begin rep <= i_data[1:0]; end // REP: REPNZ: LOCK:             
                
                // <ALU> modrm 00-3F
                8'b00_xxx_0xx: begin

                    alu <= i_data[5:3];
                    t   <= MODRM;

                end

                // PUSH <es|cs|ss|ds>
                8'b00_0xx_110: begin
                
                    // Выбор сегмента для записи в память
                    case (i_data[4:3])
                    0: wb <= es;
                    1: wb <= cs;
                    2: wb <= ss;
                    3: wb <= ds;
                    endcase
                    
                    t  <= PUSH;
                    tn <= PREPARE;
                
                end

                // POP <es|ss|ds|r16>
                8'b00_0xx_111: begin t <= POP; end
                8'b01_011_xxx: begin 
                
                    t    <= POP; 
                    tn   <= REGMEMWR;
                    size <= 1;
                    dir  <= 1;
                    modrm[5:3] <= i_data[2:0]; 
                    
                end

                // MOV r8/16, imm
                8'b1011_xxxx: begin
                
                    dir  <= 1;
                    size <= i_data[3];
                    t    <= IMMEDIATE;          // Прочитать 8 или 16 бит
                    tn   <= REGMEMWR;           // После чтения перейти к записи
                    
                    modrm[5:3] <= i_data[2:0];  // Выбор регистра       

                end

                // INC|DEC|PUSH r16
                8'b0100_xxxx, 
                8'b0101_0xxx: begin
                                    
                    t    <= RUN;
                    dir  <= 1;
                    size <= 1;
                    modrm[5:3]  <= i_data[2:0];
                    regn        <= i_data[2:0];
                    
                end

                // XCHG ax, r16
                8'b1001_0xxx: begin
                
                    regn <= i_data[2:0];
                    t    <= RUN;
                
                end

                // Все остальные инструкции 
                default: t <= RUN;

            endcase

        end

        // Разбор байта MODRM
        MODRM: case (s)

            // Первоначальная инициализация
            0: begin

                modrm <= i_data;
                ip    <= ip + 1;

                // Формирование первого операнда op1
                case (dir ? i_data[5:3] : i_data[2:0])

                    0: op1 <= size ? ax : ax[ 7:0]; // AL
                    1: op1 <= size ? cx : cx[ 7:0];
                    2: op1 <= size ? dx : dx[ 7:0];
                    3: op1 <= size ? bx : bx[ 7:0];
                    4: op1 <= size ? sp : ax[15:8];
                    5: op1 <= size ? bp : cx[15:8];
                    6: op1 <= size ? si : dx[15:8];
                    7: op1 <= size ? di : bx[15:8]; // BH

                endcase

                // Формирование первого операнда op2
                case (dir ? i_data[2:0] : i_data[5:3])

                    0: op2 <= size ? ax : ax[ 7:0]; // AL
                    1: op2 <= size ? cx : cx[ 7:0];
                    2: op2 <= size ? dx : dx[ 7:0];
                    3: op2 <= size ? bx : bx[ 7:0];
                    4: op2 <= size ? sp : ax[15:8];
                    5: op2 <= size ? bp : cx[15:8];
                    6: op2 <= size ? si : dx[15:8];
                    7: op2 <= size ? di : bx[15:8]; // BH

                endcase

                // Расчет эффективного адреса
                case (i_data[2:0])

                    0: ea <= bx + si;
                    1: ea <= bx + di;
                    2: ea <= bp + si;
                    3: ea <= bp + di;
                    4: ea <= si;
                    5: ea <= di;
                    6: ea <= ^i_data[7:6] ? bp : 0;
                    7: ea <= bx;

                endcase

                // Не используется префикс
                if (override == 0) begin

                    // Но используется BP
                    if (i_data[2:1] == 3'b01 || (^i_data[7:6] && i_data[2:0] == 3'b110))
                        segment <= ss;

                end

                // Решение о том, что делать дальше
                casex (i_data)

                    8'b00_xxx_110: begin s <= 2; end
                    8'b00_xxx_xxx: begin s <= 4; cursor <= 1; end // Считывание операнда
                    8'b01_xxx_xxx: begin s <= 1; end // +8
                    8'b10_xxx_xxx: begin s <= 2; end // +16
                    8'b11_xxx_xxx: begin t <= RUN; end

                endcase

            end

            // Дочитывание +disp8
            1: begin

                s  <= 4;
                ip <= ip + 1;
                ea <= ea + {{8{i_data[7]}}, i_data[7:0]};
                cursor <= 1;

            end

            // Прочесть 8 бит младшие (disp16)
            2: begin

                ip <= ip + 1;
                ea <= ea + i_data;
                s  <= 3;

            end

            // Прочесть 8 старших бит (disp16)
            3: begin

                ip <= ip + 1;
                ea[15:8] <= ea[15:8] + i_data;
                cursor <= 1;
                s <= 4;

            end

            // Прочесть из памяти segment:ea в op1/op2
            4: begin

                if (dir) op2 <= i_data; else op1 <= i_data;

                // Есть что дочитать
                if (size) begin

                    s  <= 5;
                    ea <= ea + 1;

                // Закончить чтению и перейти к выполнению
                end else begin

                    s <= 0;
                    t <= RUN;

                end

            end

            // Прочесть из памяти старший байт
            5: begin

                if (dir) op2[15:8] <= i_data; else op1[15:8] <= i_data;

                ea <= ea - 1;
                s  <= 0;
                t  <= RUN;

            end

        endcase

        // Исполнение инструкии
        RUN: casex (opcode)

            // Стандартное АЛУ
            8'b00_xxx_0xx: begin 
            
                wb    <= r;
                flags <= f;

                t <= (alu == CMP) ? PREPARE : REGMEMWR;
            
            end
            
            // Стандартное АЛУ + imm8/16
            8'b00_xxx_10x: case (m)
            
                // Цикл получения op2 (8 bit)
                0: begin
                
                    m   <= 1;
                    ip  <= ip + 1;
                    op1 <= ax[7:0];
                    op2 <= i_data;
                    alu <= opcode[5:3];
                
                end
                
                // Цикл получения op2 (16 bit) или запись в AL
                1: begin
                    
                    if (size) begin 
                    
                        m  <= 2;
                        ip <= ip + 1;
                        op2[15:8] <= i_data;
                    
                    end
                    else begin
                    
                        flags <= f;
                        if (alu != CMP) ax[7:0] <= r[7:0];
                        t <= PREPARE;

                    end
                
                end
                
                // Запись результата 16 бит
                2: begin
                
                    flags <= f;
                    if (alu != CMP) ax <= r;
                    t <= PREPARE;
                
                end
            
            endcase

            // Запись значения из стека в сегмент
            8'b00_0xx_111: begin

                case (opcode[4:3])
                0: es <= wb;
                2: ss <= wb;
                3: ds <= wb;                               
                endcase
                
                t <= PREPARE;
            
            end

            // INC|DEC r16
            8'b0100_xxxx: case (m)
            
                0: begin // Выбор АЛУ, запись операндов
                    
                    m   <= 1;
                    alu <= opcode[3] ? SUB : ADD;
                    op1 <= regv; 
                    op2 <= 1;
                    
                end
                
                1: begin // Запись результата в регистр
                
                    wb    <= r;
                    flags <= {f[11:1], flags[0]}; // Сохранит CF
                    t     <= REGMEMWR;
                
                end
            
            endcase

            // PUSH r16
            8'b0101_0xxx: begin

                t  <= PUSH;
                tn <= PREPARE;
                wb <= regv;

            end

            // J<ccc> b8
            8'b0111_xxxx: begin
            
                if (cond[ opcode[3:1] ] ^ opcode[0])
                    ip <= ip + 1 + {{8{i_data[7]}}, i_data[7:0]};
                else
                    ip <= ip + 1;
                    
                t <= PREPARE;
            
            end
            
            // XCHG ax, r16
            8'b1001_0xxx: begin
            
                wb   <= ax;
                dir  <= 1;
                size <= 1;
                t    <= REGMEMWR;
                ax   <= regv;
                modrm[5:3] <= opcode[2:0];
            
            end

        endcase
        
        // ---------------------------------------------------------------------
        // ВСПОМОГАТЕЛЬНЫЕ ПРОЦЕДУРЫ
        // ---------------------------------------------------------------------
        
        // Прочитать 8 или 16 бит в wb
        IMMEDIATE: case (s)
        
            0: begin // 8 бит
            
                ip <= ip + 1;
                wb <= i_data;

                if (size) s <= 1; else begin s <= 0; t <= tn; end
                
            end
            
            1: begin // 16 бит
            
                s  <= 0;
                t  <= tn;
                ip <= ip + 1;
                
                wb[15:8] <= i_data;

            end
        
        endcase

        // Запись [wb, dir, size, modrm] в память (segment:ea) или регистр
        REGMEMWR: case (s)

            // Запись в регистры
            0: if (dir || modrm[7:6] == 2'b11) begin

                case (dir ? modrm[5:3] : modrm[2:0])

                    0: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0]; // AL
                    1: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0]; // CL
                    2: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0]; // DL
                    3: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0]; // BL
                    4: if (size) sp <= wb; else ax[15:8] <= wb[7:0]; // AH
                    5: if (size) bp <= wb; else cx[15:8] <= wb[7:0]; // CH
                    6: if (size) si <= wb; else dx[15:8] <= wb[7:0]; // DH
                    7: if (size) di <= wb; else bx[15:8] <= wb[7:0]; // BH

                endcase

                t <= PREPARE;

            end
            // Запись в память
            else begin

            end

        endcase

        // Сохранение в стек
        PUSH: case (s)
        
            0: begin // Запись младшего байта
            
                cursor  <= 1;
                sp      <= sp - 2;
                ea      <= sp - 2;
                segment <= ss;
                we      <= 1;
                o_data  <= wb[7:0];
                s       <= 1;
                
            end
            
            1: begin // Запись старшего байта
            
                ea      <= ea + 1;
                we      <= 1;
                o_data  <= wb[15:8];
                s       <= 0;
                t       <= tn;
            
            end
        
        endcase
        
        // Извлечение из стека
        POP: case (s)
        
            0: begin // Запрос на чтение байта
            
                s       <= 1;
                cursor  <= 1;
                segment <= ss;
                ea      <= sp;
                sp      <= sp + 2;
            
            end
            
            1: begin // Чтение младшего байта
            
                wb <= i_data;
                ea <= ea + 1;
                s  <= 2;
            
            end
            
            2: begin // Чтение старшего байта
            
                wb[15:8] <= i_data;
                s <= 0;
                t <= tn;
                cursor <= 0;
            
            end
          
        
        endcase

    endcase

end

endmodule
