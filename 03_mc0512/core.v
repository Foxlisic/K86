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
reg [ 5:0]  ta;
reg [15:0]  ea, seg;
reg [ 7:0]  opcode;
reg [ 3:0]  overs, _overs;      // Over Segment
reg [ 1:0]  rep, _rep;          // Repeat:
reg [ 2:0]  preip;
reg         size, dir;

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
    cs <= 16'hF000;
    ip <= 16'hFFF0;

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
    endcase

end

endmodule
