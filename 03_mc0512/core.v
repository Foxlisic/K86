// 8088
module core
(
    input               clock,
    input               ce,
    input               reset_n,
    output      [19:0]  address,
    input       [ 7:0]  in,
    output reg  [ 7:0]  out,
    output reg          we
);

// Вычисление адреса в памяти 1MB
assign address = cp ? {seg, 4'h0} + ea : {cs, 4'h0} + ip;

// ОБЪЯВЛЕНИЯ
// ---------------------------------------------------------------------
localparam
    LOAD = 0, RUN   = 1, WB    = 2,
    PUSH = 3, PUSH2 = 4, PUSH3 = 5,
    POP  = 6, POP2  = 7, POP3  = 8;

localparam
    ES = 2'b00,  CS = 2'b01,  SS = 2'b10,  DS = 2'b11,
    AX = 3'b000, CX = 3'b001, DX = 3'b010, BX = 3'b011,
    SP = 3'b100, BP = 3'b101, SI = 3'b110, DI = 3'b111;

localparam
    CF = 0, PF = 2, AF =  4, ZF =  6, SF = 7,
    TF = 8, IF = 9, DF = 10, OF = 11;

// РЕГИСТРЫ
// ---------------------------------------------------------------------
reg [15:0]  ax, bx, cx, dx, sp, bp, si, di;
reg [15:0]  es, cs, ss, ds;
reg [15:0]  ip, ips;
reg [11:0]  flag = 12'b0000_0000_0010;
//                     ODIT SZ A  P C

// СИСТЕМНЫЕ РЕГИСТРЫ
// ---------------------------------------------------------------------
reg         cp;
reg [ 3:0]  m;
reg [ 5:0]  ta, tb;
reg [15:0]  ea, seg, op1, op2, wb;
reg [ 7:0]  opcode, modrm;
reg [ 2:0]  overs, _overs;      // Over Segment
reg [ 1:0]  rep, _rep;          // Repeat:
reg [ 2:0]  preip;
reg         size, dir;

// ВЫЧИСЛЕНИЯ
// ---------------------------------------------------------------------
wire [15:0] ipn = ip + 1;
wire [15:0] ipx = ip - preip;
wire [15:0] ipsign = ip + 1 + {{8{in[7]}}, in};

// ЗНАЧЕНИЕ РЕГИСТРОВ
// ---------------------------------------------------------------------

// 16-битные операнды на LOAD-секции
wire rsize = (ta == LOAD) | size;

// Входящие из 2:0
wire [15:0] r20 =
    in[2:0] == AX ? (rsize ? ax : ax[ 7:0]) :
    in[2:0] == CX ? (rsize ? cx : cx[ 7:0]) :
    in[2:0] == DX ? (rsize ? dx : dx[ 7:0]) :
    in[2:0] == BX ? (rsize ? bx : bx[ 7:0]) :
    in[2:0] == SP ? (rsize ? sp : ax[15:8]) :
    in[2:0] == BP ? (rsize ? bp : cx[15:8]) :
    in[2:0] == SI ? (rsize ? si : dx[15:8]) :
                    (rsize ? di : bx[15:8]);

// Входящие из 5:3
wire [15:0] r53 =
    in[5:3] == AX ? (rsize ? ax : ax[ 7:0]) :
    in[5:3] == CX ? (rsize ? cx : cx[ 7:0]) :
    in[5:3] == DX ? (rsize ? dx : dx[ 7:0]) :
    in[5:3] == BX ? (rsize ? bx : bx[ 7:0]) :
    in[5:3] == SP ? (rsize ? sp : ax[15:8]) :
    in[5:3] == BP ? (rsize ? bp : cx[15:8]) :
    in[5:3] == SI ? (rsize ? si : dx[15:8]) :
                    (rsize ? di : bx[15:8]);

// ЛОГИКА РАБОТЫ ПРОЦЕССОРА
// ---------------------------------------------------------------------

always @(posedge clock)
// Процесс сброса
if (reset_n == 1'b0) begin

    cp <= 0;
    ta <= 0;

    // F000:FFF0
    ip <= 16'h0000;

    // SG
    es <= 16'h1234; cs <= 16'h0000;
    ss <= 16'hDEAD; ds <= 16'hBEEF;

    // RG
    ax <= 16'h1234;
    bx <= 16'h5678;
    cx <= 16'hABCD;
    dx <= 16'hEF12;
    sp <= 16'hBABE;
    bp <= 16'hDEAD;
    si <= 16'hBEEF;
    di <= 16'hDADD;

    _overs <= {DS, 1'b0};
    _rep   <= 2'b00;
    preip  <= 0;

// Процессор должен быть активирован
end else if (ce) begin

    we <= 0;
    case (ta)

    // Загрузка опкода и выполнение простых инструкции
    // -----------------------------------------------------------------
    LOAD: begin

        ip <= ip + 1;

        casex (in)
        // Разбор префиксов
        8'b001x_x110: begin preip <= preip + 1; _overs <= {in[4:3], 1'b1}; end
        8'b1111_101x: begin preip <= preip + 1; _rep   <= in[1:0]; end
        8'b0000_1111,
        8'b0110_01xx,
        8'b1111_0000: begin preip <= preip + 1; end
        // Выполнить опкод
        default: begin

            // Метки по умолчанию
            ta      <= RUN;
            m       <= 0;

            // Место реального старта инструкции с учетом префиксов
            ips     <= ipx;

            // Защелкнуть регистры для дальнейшего использования
            opcode  <= in;
            overs   <= _overs;
            rep     <= _rep;
            ea      <= 0;
            preip   <= 0;
            _overs  <= {DS, 1'b0};
            _rep    <= 2'b00;
            dir     <= in[1];
            size    <= in[0];

            // Назначить сегмент по умолчанию
            case (_overs[2:1])
            ES: seg <= es; CS: seg <= cs;
            SS: seg <= ss; DS: seg <= ds;
            endcase

            // Обработка и подготовка инструкции
            casex (in)
            // HLT, CMC, CLC, STC, CLI, STI, CLD, STD
            8'b1111_0100: begin ta <= LOAD; ip <= ipx; end
            8'b1111_0101: begin ta <= LOAD; flag[CF] <= ~flag[CF]; end
            8'b1111_100x: begin ta <= LOAD; flag[CF] <= in[0]; end
            8'b1111_101x: begin ta <= LOAD; flag[IF] <= in[0]; end
            8'b1111_110x: begin ta <= LOAD; flag[DF] <= in[0]; end
            // 4T [60..67] PUSH r
            8'b0101_0xxx: begin

                ta <= PUSH;
                tb <= LOAD;
                wb <= r20;

            end
            // 6T [58..5F] POP r
            8'b0101_1xxx: begin

                ta <= POP;
                tb <= RUN;
                {dir, size} <= 2'b11;
                modrm[5:3] <= in[2:0];

            end
            // 2T [90..97] XCHG ax, r
            8'b1001_0xxx: begin

                ta <= WB;       // К записи в регистры
                tb <= LOAD;     // При выходе из процедуры вернуться в LOAD
                wb <= ax;       // Записать предыдущее значение AX
                ax <= r20;      // В r20 всегда 16-битное значение
                {dir, size} <= 2'b11;   // DIR=1, SIZE=1
                modrm[5:3] <= in[2:0];  // Номер регистра для записи

            end

            endcase

            // Прерывание

        end
        endcase

    end

    // Исполнение инструкции
    // -----------------------------------------------------------------
    RUN: casex (opcode)

        // 6T [58..5F] POP r
        8'b0101_1xxx: begin ta <= WB; tb <= LOAD; end

        // 3T [E9 xx xx] JMP b16
        8'b1110_1001: case (m)

            0: begin m <= 1; op1[7:0] <= in; ip <= ip + 1; end
            1: begin m <= 0; ip <= ipn + {in, op1[7:0]}; ta <= LOAD; end

        endcase

        // 5T [EA xx xx xx xx] JMP far
        8'b1110_1010: case (m)

            0: begin m <= 1; ip <= ipn; op1[ 7:0] <= in; ip <= ipn; end
            1: begin m <= 2; ip <= ipn; op1[15:8] <= in; ip <= ipn; end
            2: begin m <= 3; ip <= ipn; op2[ 7:0] <= in; ip <= ipn; end
            3: begin m <= 0; ip <= ipn; cs <= {in, op2[7:0]}; ip <= op1; ta <= LOAD; end

        endcase

        // 2T [EB xx] JMP b8
        8'b1110_1011: begin

            ip <= ipsign;
            ta <= LOAD;

        end

    endcase

    // Запись результата
    // -----------------------------------------------------------------
    WB: begin

        // DIR=1, берем из M[5:3], иначе из M[2:0]
        if (dir || modrm[7:6] == 2'b11) begin

            ta <= tb;

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
        // else write memory

    end

    // Запись в стек
    // -----------------------------------------------------------------
    // Запись младшего байта в память
    PUSH: begin

        ta  <= PUSH2;
        we  <= 1;
        seg <= ss;
        ea  <= sp - 2;
        sp  <= sp - 2;
        out <= wb[7:0];
        cp  <= 1;

    end
    // Запись старшего байта в память
    PUSH2: begin

        ta  <= PUSH3;
        we  <= 1;
        ea  <= ea + 1;
        out <= wb[15:8];

    end
    // Финализация
    PUSH3: begin

        ta <= tb;
        cp <= 0;

    end

    // Чтение из стека
    // -----------------------------------------------------------------
    POP: begin

        ta  <= POP2;
        cp  <= 1;
        seg <= ss;
        ea  <= sp;
        sp  <= sp + 2;

    end
    POP2: begin

        ta <= POP3;
        wb <= in;
        ea <= ea + 1;

    end
    POP3: begin

        ta <= tb;
        cp <= 0;
        wb[15:8] <= in;

    end

    endcase
end

endmodule
