// ---------------------------------------------------------------------
// Подготовить инструкцию к исполнению
// ---------------------------------------------------------------------

LOAD: begin

    cp      <= 1'b0;
    seg     <= ds;
    ea      <= 16'h0000;
    over    <= 1'b0;
    rep     <= 2'b00;
    rep_ip  <= ip;
    a       <= 0;
    m       <= 0;
    t       <= FETCH;
    next    <= LOAD;

end

// ---------------------------------------------------------------------
// Прочитать опкод
// ---------------------------------------------------------------------

FETCH: begin

    ip <= ip + 1;

    case (in)
    // Прочитать префиксы
    8'h26: seg <= es;
    8'h2E: seg <= cs;
    8'h36: seg <= ss;
    8'h3E: seg <= ds;
    8'hF2, // REPZ: REPNZ:
    8'hF3: rep <= in[1:0];
    8'h0F, // Extend:
    8'hF0, // LOCK:
    8'h64, // FS:
    8'h65, // GS:
    8'h66, // OpSize
    8'h67: begin end // Adsize
    // Записать опкод
    default: begin

        t       <= INSTR;
        opcode  <= in;          // Сохранить опкод для исполнения
        size    <= in[0];       // Размер операнда по умолчанию
        dir     <= in[1];       // Направление операндов по умолчанию

    end
    endcase

end

// ---------------------------------------------------------------------
// Прочитать байт MODRM [1-6T]
// ---------------------------------------------------------------------

MODRM: case (a)

    // Определить регистры или перейти к памяти
    0: begin

        modrm   <= in;
        ip      <= ip + 1;

        // Операнд DST => MEM/REG :: REG
        casex (dir ? in[5:3] : in[2:0])
        AX: op1 <= size ? ax : ax[ 7:0];
        CX: op1 <= size ? cx : cx[ 7:0];
        DX: op1 <= size ? dx : dx[ 7:0];
        BX: op1 <= size ? bx : bx[ 7:0];
        SP: op1 <= size ? sp : ax[15:8];
        BP: op1 <= size ? bp : cx[15:8];
        SI: op1 <= size ? si : dx[15:8];
        DI: op1 <= size ? di : bx[15:8];
        endcase

        // Операнд SRC => REG :: MEM/REG
        casex (dir ? in[2:0] : in[5:3])
        AX: op2 <= size ? ax : ax[ 7:0];
        CX: op2 <= size ? cx : cx[ 7:0];
        DX: op2 <= size ? dx : dx[ 7:0];
        BX: op2 <= size ? bx : bx[ 7:0];
        SP: op2 <= size ? sp : ax[15:8];
        BP: op2 <= size ? bp : cx[15:8];
        SI: op2 <= size ? si : dx[15:8];
        DI: op2 <= size ? di : bx[15:8];
        endcase

        // Эффективный адрес
        case (in[2:0])
        3'b000: ea <= bx + si;
        3'b001: ea <= bx + di;
        3'b010: ea <= bp + si;
        3'b011: ea <= bp + di;
        3'b100: ea <= si;
        3'b101: ea <= di;
        3'b110: ea <= ^in[7:6] ? bp : 0; // 01,10 :: BP + d8,d16
        3'b111: ea <= bx;
        endcase

        // Распределить
        casex (in)
        8'b00_xxx_110,
        8'b10_xxx_xxx: a <= 2;      // +D16
        8'b00_xxx_xxx: a <= 4;      // MEMORY
        8'b01_xxx_xxx: a <= 1;      // +D8
        8'b11_xxx_xxx: t <= INSTR;  // REG
        endcase

        // Автозамещение сегмента на SS: если использован BP регистр
        if (over == 1'b0 && (^in[7:6]) && in[2:0] == 3'b110 || in[2:1] == 2'b01)
            seg <= ss;

    end

    // Читать +D8
    1: begin

        a  <= 5;
        ip <= ip + 1;
        ea <= ea + {{8{in[7]}}, in};

    end

    // Читать +D16 :: LOW
    2: begin

        a  <= 3;
        ip <= ip + 1;
        ea <= ea + {8'h00, in};

    end

    // Читать +D16 :: HIGH
    3: begin

        a  <= 4;
        ip <= ip + 1;
        ea <= ea + {in, 8'h00};

    end

    // Читать LO операнд OP1,2
    4: begin

        if (dir) op2 <= in; else op1 <= in;

        a  <= size ? 5 : 0;
        t  <= size ? INSTR : MODRM;
        ea <= ea + size;

    end

    // Читать HI операнд OP1,2
    5: begin

        if (dir) op2[15:8] <= in; else op1[15:8] <= in;

        a  <= 0;
        t  <= INSTR;
        ea <= ea - 1;

    end

endcase

// ---------------------------------------------------------------------
// Запись в память или регистр [wb,size,dir,modrm] возврат к next
// ---------------------------------------------------------------------

WB: case (a)

    // Регистр | Запись младшего байта
    0: begin

        if (dir || modrm[7:6] == 2'b11) begin

            case (dir ? `MRM53 : `MRM20)
            AX: if (size) ax <= wb; else ax[ 7:0] <= wb[7:0];
            CX: if (size) cx <= wb; else cx[ 7:0] <= wb[7:0];
            DX: if (size) dx <= wb; else dx[ 7:0] <= wb[7:0];
            BX: if (size) bx <= wb; else bx[ 7:0] <= wb[7:0];
            SP: if (size) sp <= wb; else ax[15:8] <= wb[7:0];
            BP: if (size) bp <= wb; else cx[15:8] <= wb[7:0];
            SI: if (size) si <= wb; else dx[15:8] <= wb[7:0];
            DI: if (size) di <= wb; else bx[15:8] <= wb[7:0];
            endcase

            t <= next;

        end
        else begin

            a   <= size ? 1 : 2;
            we  <= 1;
            cp  <= 1;
            out <= wb[7:0];

        end

    end

    // Запись старшего байта
    1: begin

        a   <= 2;
        we  <= 1;
        out <= wb[15:8];
        ea  <= ea + 1;

    end

    // Завершение записи и выход из процедуры
    2: begin

        a  <= 0;
        t  <= next;
        ea <= ea - size;
        we <= 0;
        cp <= 0;

    end

endcase
