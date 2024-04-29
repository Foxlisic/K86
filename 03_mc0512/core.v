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

// Вычисление адреса в памяти
assign address = cp ? {seg, 4'h0} + ea : {cs, 4'h0} + ip;

// ОБЪЯВЛЕНИЯ
// ---------------------------------------------------------------------
localparam
    LOAD = 0, RUN = 1;

localparam
    ES = 2'b00,  CS = 2'b01,  SS = 2'b10,  DS = 2'b11,
    AX = 3'b000, CX = 3'b001, DX = 3'b010, BX = 3'b011,
    SP = 3'b100, BP = 3'b101, SI = 3'b110, DI = 3'b111;

// РЕГИСТРЫ
// ---------------------------------------------------------------------
reg [15:0]  ax, bx, cx, dx, sp, bp, si, di;
reg [15:0]  es, cs, ss, ds;
reg [15:0]  ip, ips;
reg [11:0]  flag = 12'b0000_0000_0010;
//                    ODIT SZ A  P C

// СИСТЕМНЫЕ РЕГИСТРЫ
// ---------------------------------------------------------------------
reg         cp;
reg [ 3:0]  m;
reg [ 5:0]  ta;
reg [15:0]  ea, seg, op1, op2;
reg [ 7:0]  opcode;
reg [ 2:0]  overs, _overs;      // Over Segment
reg [ 1:0]  rep, _rep;          // Repeat:
reg [ 2:0]  preip;
reg         size, dir;

// ВЫЧИСЛЕНИЯ
// ---------------------------------------------------------------------
wire [15:0] ipn = ip + 1;

// ЗНАЧЕНИЕ РЕГИСТРОВ
// ---------------------------------------------------------------------

// Входящие из 2:0
wire [15:0] r20 =
    in[2:0] == AX ? (size ? ax : ax[ 7:0]):
    in[2:0] == CX ? (size ? cx : cx[ 7:0]) :
    in[2:0] == DX ? (size ? dx : dx[ 7:0]) :
    in[2:0] == BX ? (size ? bx : bx[ 7:0]) :
    in[2:0] == SP ? (size ? sp : ax[15:8]) :
    in[2:0] == BP ? (size ? bp : cx[15:8]) :
    in[2:0] == SI ? (size ? si : dx[15:8]) :
                    (size ? di : bx[15:8]);

// Входящие из 5:3
wire [15:0] r53 =
    in[5:3] == AX ? (size ? ax : ax[ 7:0]):
    in[5:3] == CX ? (size ? cx : cx[ 7:0]) :
    in[5:3] == DX ? (size ? dx : dx[ 7:0]) :
    in[5:3] == BX ? (size ? bx : bx[ 7:0]) :
    in[5:3] == SP ? (size ? sp : ax[15:8]) :
    in[5:3] == BP ? (size ? bp : cx[15:8]) :
    in[5:3] == SI ? (size ? si : dx[15:8]) :
                    (size ? di : bx[15:8]);

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
    ax <= 16'h0000; bx <= 16'h0000;
    cx <= 16'h0000; dx <= 16'h0000;
    sp <= 16'h0000; bp <= 16'h0000;
    si <= 16'h0000; di <= 16'h0000;

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

            // Метка по умолчанию
            ta      <= RUN;
            m       <= 0;

            // Место реального старта инструкции с учетом префиксов
            ips     <= ip - preip;

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

        end
        endcase

    end

    // Исполнение инструкции
    // -----------------------------------------------------------------
    RUN: casex (opcode)

        // 3T JMP b16
        8'b1110_1001: case (m)

            0: begin m <= 1; op1[7:0] <= in; ip <= ip + 1; end
            1: begin m <= 0; ip <= ipn + {in, op1[7:0]}; ta <= LOAD; end

        endcase

        // 5T JMP far
        8'b1110_1010: case (m)

            0: begin m <= 1; ip <= ipn; op1[ 7:0] <= in; ip <= ip + 1; end
            1: begin m <= 2; ip <= ipn; op1[15:8] <= in; ip <= ip + 1; end
            2: begin m <= 3; ip <= ipn; op2[ 7:0] <= in; ip <= ip + 1; end
            3: begin m <= 0; ip <= ipn; cs <= {in, op2[7:0]}; ip <= op1; ta <= LOAD; end

        endcase

    endcase

    endcase
end

endmodule
