// ЛИСНЫЙ ПРОЦЕССОР 8088
// ---------------------------------------------------------------------

module fox86
(
    input               clock,      // Тактовая частота 25
    input               reset_n,    // Сброс процессора
    input               ce,         // Разрешение работы процессора
    output      [19:0]  address,    // Адрес 1Мб
    input       [ 7:0]  in,         // Входящие
    output reg  [ 7:0]  out,        // Исходящие
    output reg          we          // Разрешение на запись
);

localparam

    LOAD = 0;

// Большой список всех регистров в процессоре
// ---------------------------------------------------------------------
reg [15:0]  ax = 16'h1234, bx = 16'h0050, cx = 16'hFFFF, dx = 16'h0000,
            sp = 16'h0000, bp = 16'h0001, si = 16'h0003, di = 16'h0001,
            es = 16'h0120, cs = 16'hFFFF, ss = 16'h0001, ds = 16'h0000;
reg [15:0]  ip = 16'h0000;
//                      ODIT SZ A  P C
reg [11:0]  flags = 12'b0000_0000_0011;

// Управляющие регистры
// ---------------------------------------------------------------------
reg [15:0]  cp;
reg [ 7:0]  opcode;
reg [ 4:0]  t, m, fn;

reg [ 15:0] _seg,   seg;
reg         _over,  over;
reg [ 1:0]  _rep,   rep;

// Предвычисления
// ---------------------------------------------------------------------
wire [7:0]  opc = t ? opcode : in;

// Логика исполнения инструкции
// ---------------------------------------------------------------------

always @(posedge clock)
if (reset_n == 1'b0) begin

    t       <= 0;
    m       <= 0;
    ip      <= 0;
    cs      <= 0;
    _seg    <= 0;
    _rep    <= 0;
    _over   <= 0;

end else if (ce) begin

    case (t)

    // Прочесть префиксы и записать опкод
    LOAD: begin

        ip <= ip + 1;

        case (in)
        8'h26: begin _seg <= es; _over <= 1; end
        8'h2E: begin _seg <= cs; _over <= 1; end
        8'h36: begin _seg <= ss; _over <= 1; end
        8'h3E: begin _seg <= ds; _over <= 1; end
        8'hF2, 8'hF3: begin _rep <= in[1:0]; end
        8'h8B, 8'h0F, 8'hF0, 8'h64, 8'h65, 8'h66, 8'h67: begin end
        default: begin

            seg     <= _seg;    _seg    <= ds;
            over    <= _over;   _over   <= 0;
            rep     <= _rep;    _rep    <= 2'b00;
            opcode  <= in;

        end
        endcase

    end
    endcase


end

endmodule
