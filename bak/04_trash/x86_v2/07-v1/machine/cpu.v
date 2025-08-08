module cpu
(
    input   wire        clock,          // 26 mhz
    input   wire        reset_n,        // =0 то сброс
    input   wire        locked,
    input   wire        halt,
    output  wire [31:0] address,
    input   wire [ 7:0] i_data,         // Входящие данные
    output  reg  [ 7:0] o_data,
    output  reg         we
);

// Real-mode
assign address = sel ? (segment<<4) + ea : (cs<<4) + eip[15:0];

`include "decl.v"

// Реализация эмулятора
always @(posedge clock)
if (reset_n == 1'b0) begin

    cs  <= 0;
    eip <= 0;

end
// Рабочий режим процесса
else if (locked && !halt)
begin

we <= 1'b0;

case (phase)

    // Инициализация
    // -------------------------------------------------------------------------

    P_INIT: begin

        rep         <= 1'b0;
        override    <= 1'b0;
        opcode      <= 1'b0;
        phase       <= 1;
        segment     <= ds;
        opsize      <= 1'b0; // Default=0
        adsize      <= 1'b0;
        sel         <= 1'b0;

        // Проверка на внешнее прерывание

    end

    // Считывание префиксы, опкоды и исполнение их
    // -------------------------------------------------------------------------

    P_OPCODE: begin

        eip <= eip + 1;

        case (i_data)

            // Сегментные префиксы
            8'h26: begin segment <= es; override <= 1'b1; end
            8'h2E: begin segment <= cs; override <= 1'b1; end
            8'h36: begin segment <= ss; override <= 1'b1; end
            8'h3E: begin segment <= ds; override <= 1'b1; end
            8'h64: begin segment <= fs; override <= 1'b1; end
            8'h65: begin segment <= gs; override <= 1'b1; end

            // Дополнительные префиксы
            8'h0F: begin opcode[8] <= 1'b1; end
            8'h66: begin opsize <= ~opsize; end
            8'h67: begin adsize <= ~adsize; end
            8'hF0: begin /* lock: */ end
            8'hF2: begin rep <= 2'b10; end // REPNZ
            8'hF3: begin rep <= 2'b11; end // REPZ

            // Исполнение или передача на modrm/sib
            default: begin

                opcode[7:0] <= i_data;

                casex ({opcode[8], i_data})

                    // АЛУ-инструкции базовые
                    9'b0_00_xxx0xx: begin

                        phase   <= 2;
                        size    <= i_data[0];
                        dir     <= i_data[1];
                        alu     <= i_data[5:3];

                    end

                endcase

            end

        endcase

    end

    // Считывание операндов первичных
    // -------------------------------------------------------------------------

    P_MODRM: begin

        modrm <= i_data;
        eip   <= eip + 1;
        phase <= 3;
        ea    <= 0;

        // Считывание op1 из байта modrm
        case (dir ? i_data[5:3] : i_data[2:0])

            0: op1 <= size ? (opsize ? eax : eax[15:0]) : eax[ 7:0]; // AL
            1: op1 <= size ? (opsize ? ecx : ecx[15:0]) : ecx[ 7:0]; // CL
            2: op1 <= size ? (opsize ? edx : edx[15:0]) : edx[ 7:0]; // DL
            3: op1 <= size ? (opsize ? ebx : ebx[15:0]) : ebx[ 7:0]; // BL
            4: op1 <= size ? (opsize ? esp : esp[15:0]) : eax[15:8]; // AH
            5: op1 <= size ? (opsize ? ebp : ebp[15:0]) : ecx[15:8]; // CH
            6: op1 <= size ? (opsize ? esi : esi[15:0]) : edx[15:8]; // DH
            7: op1 <= size ? (opsize ? edi : edi[15:0]) : ebx[15:8]; // BH

        endcase

        // Считывание op1 из байта modrm
        case (dir ? i_data[2:0] : i_data[5:3])

            0: op2 <= size ? (opsize ? eax : eax[15:0]) : eax[ 7:0]; // AL
            1: op2 <= size ? (opsize ? ecx : ecx[15:0]) : ecx[ 7:0]; // CL
            2: op2 <= size ? (opsize ? edx : edx[15:0]) : edx[ 7:0]; // DL
            3: op2 <= size ? (opsize ? ebx : ebx[15:0]) : ebx[ 7:0]; // BL
            4: op2 <= size ? (opsize ? esp : esp[15:0]) : eax[15:8]; // AH
            5: op2 <= size ? (opsize ? ebp : ebp[15:0]) : ecx[15:8]; // CH
            6: op2 <= size ? (opsize ? esi : esi[15:0]) : edx[15:8]; // DH
            7: op2 <= size ? (opsize ? edi : edi[15:0]) : ebx[15:8]; // BH

        endcase

        // 16-битный modrm
        if (adsize == 1'b0) begin

            casex (i_data)

                8'b00_xxx_110: begin end // Эффективный адрес=0
                8'bxx_xxx_000: ea[15:0] <= ebx[15:0] + esi[15:0];
                8'bxx_xxx_001: ea[15:0] <= ebx[15:0] + edi[15:0];
                8'bxx_xxx_010: ea[15:0] <= ebp[15:0] + esi[15:0];
                8'bxx_xxx_011: ea[15:0] <= ebp[15:0] + edi[15:0];
                8'bxx_xxx_100: ea[15:0] <= esi[15:0];
                8'bxx_xxx_101: ea[15:0] <= edi[15:0];
                8'bxx_xxx_110: ea[15:0] <= ebp[15:0];
                8'bxx_xxx_111: ea[15:0] <= ebx[15:0];

            endcase

            // Замещение текущего сегмента по умолчанию на SS:
            if (override == 0)
            casex (i_data)

                8'bxx_xxx_01x: segment <= ss;
                8'b01_xxx_110,
                8'b10_xxx_110: segment <= ss;

            endcase

            // Случай, когда не требуется прочитать смещение и надо прочитать операнд
            if (i_data[7:6] == 2'b00) begin 
            
                // [disp16]
                if (i_data[2:0] == 3'b110) begin                
                    phase <= P_MODRM_DISP;
                end else begin
                    phase <= P_GETMEMOP; 
                    sel   <= 1; 
                end

            end
            // Операнды готовы
            else if (i_data[7:6] == 2'b11) begin phase <= P_EXEC; end
            // Считывание смещения
            else phase <= P_MODRM_DISP;

        end
        // 32-битный modrm[+sib]
        else begin

            // @TODO ....

        end

    end

    // Считывание смещения 8 бит
    P_MODRM_DISP: begin

        eip <= eip + 1;

        // +disp8 [-128...127]
        if (modrm[7:6] == 2'b01) begin

            ea[15:0] <= ea[15:0] + {{8{i_data[7]}}, i_data};
            phase    <= P_GETMEMOP;
            sel      <= 1;

        end
        // +disp16 [-32768...32767]
        else begin

            ea[15:0] <= ea[15:0] + i_data;
            phase    <= P_MODRM_DISP_HI;

        end

    end

    // Считывание смещения 16 бит
    P_MODRM_DISP_HI: begin

        eip      <= eip + 1;
        ea[15:8] <= ea[15:8] + i_data;
        sel      <= 1;
        phase    <= P_GETMEMOP;

    end

    // Считывание операнда из памяти в op1/op2 8|16|32 
    // -------------------------------------------------------------------------
    
    P_GETMEMOP: begin
        
        // 8..31 обнуление операндов
        if (dir) op2 <= i_data; else op1 <= i_data;
        
        // Если это 16/32-битный операнд
        if (size) begin 
        
            phase <= P_GETMEMOP2;             
            ea    <= ea + 1;
            
        end
        // Завершить считывание из памяти
        else begin phase <= P_EXEC; end

    end
    
    // 2-й байт (старший 16 битного значения)
    P_GETMEMOP2: begin
    
        if (dir) op2[15:8] <= i_data; else op1[15:8] <= i_data;
        
        // =32 битный операнд
        if (opsize) begin
        
            phase <= P_GETMEMOP3;
            ea    <= ea + 1;
        
        // =16 битный операнд
        end else begin
        
            phase <= P_EXEC; 
            ea    <= ea - 1;          

        end
    
    end
    
    // 3-й байт
    P_GETMEMOP3: begin 

        if (dir) op2[23:16] <= i_data; else op1[23:16] <= i_data;

        ea    <= ea + 1; 
        phase <= P_GETMEMOP4;

    end
    
    // 4-й байт
    P_GETMEMOP4: begin

        if (dir) op2[31:24] <= i_data; else op1[31:24] <= i_data;

        ea    <= ea - 3;
        phase <= P_EXEC;

    end
    
    // Исполнение инструкции
    // -------------------------------------------------------------------------
    
    P_EXEC: begin
    
        // .. 

    end

endcase

end

endmodule
