module regs(

    input wire        clock,

    // Управление
    input wire [47:0] instr,
    input wire        bitsel,
    input wire        direct,
    input wire [1:0]  segment,
    input wire        segpref,

    // Регистры
    output reg [15:0] ax,
    output reg [15:0] cx,
    output reg [15:0] bx,
    output reg [15:0] dx,
    output reg [15:0] sp,
    output reg [15:0] bp,
    output reg [15:0] si,
    output reg [15:0] di,

    // Сегменты
    output reg [15:0] es,
    output reg [15:0] cs,
    output reg [15:0] ss,
    output reg [15:0] ds,

    // Эффективный адрес
    output reg [15:0] ea_seg,
    output reg [15:0] ea_adr,

    // Операнды
    output reg [15:0] op1,
    output reg [15:0] op2

);

initial begin

    ax = 16'h0000;
    cx = 16'h0000;
    bx = 16'h0000;
    dx = 16'h0000;
    sp = 16'h0000;
    bp = 16'h0000;
    si = 16'h0000;
    di = 16'h0000;
    es = 16'h0000;
    cs = 16'h0000;
    ss = 16'h0000;
    ds = 16'h0000;

end

reg [15:0] ea;

wire [7:0]  modrm  = instr[15: 8];
wire [2:0]  rm     = instr[10: 8];
wire [2:0]  rg     = instr[13:11];
wire [15:0] disp16 = instr[31:16];

always @* begin

    // Есть Override
    if (segpref)
        case (segment)
            2'b00: ea_seg = es;
            2'b01: ea_seg = cs;
            2'b10: ea_seg = ss;
            2'b11: ea_seg = ds;
        endcase
    else
    // Сегменты по умолчанию
    casex (modrm)
        8'b00_xxx_110: ea_seg = ds;
        8'bxx_xxx_110: ea_seg = ss;
        8'bxx_xxx_01x: ea_seg = ss;
        default:       ea_seg = ds;
    endcase

    // Генератор ea
    case (rm)

        3'b000: ea = bx + si;
        3'b001: ea = bx + di;
        3'b010: ea = bp + si;
        3'b011: ea = bp + di;
        3'b100: ea = si;
        3'b101: ea = di;
        3'b100: ea = bp;
        3'b111: ea = bx;

    endcase

    // Коррекция Displacement
    casex (modrm)

        8'b00_xxx_110: ea_adr = disp16;
        8'b00_xxx_xxx: ea_adr = ea;
        8'b01_xxx_xxx: ea_adr = ea + {{8{instr[23]}},instr[23:16]};
        8'b10_xxx_xxx: ea_adr = ea + disp16;

    endcase

    // Операнд второй как регистр
    case (direct ? rg : rm)

        3'b000: op1 = bitsel ? ax : ax[ 7:0];
        3'b001: op1 = bitsel ? cx : cx[ 7:0];
        3'b010: op1 = bitsel ? dx : dx[ 7:0];
        3'b011: op1 = bitsel ? bx : bx[ 7:0];
        3'b100: op1 = bitsel ? sp : ax[15:8];
        3'b101: op1 = bitsel ? bp : cx[15:8];
        3'b110: op1 = bitsel ? si : dx[15:8];
        3'b111: op1 = bitsel ? di : bx[15:8];

    endcase

    // Операнд первый как регистр
    case (direct ? rm : rg)

        3'b000: op2 = bitsel ? ax : ax[ 7:0];
        3'b001: op2 = bitsel ? cx : cx[ 7:0];
        3'b010: op2 = bitsel ? dx : dx[ 7:0];
        3'b011: op2 = bitsel ? bx : bx[ 7:0];
        3'b100: op2 = bitsel ? sp : ax[15:8];
        3'b101: op2 = bitsel ? bp : cx[15:8];
        3'b110: op2 = bitsel ? si : dx[15:8];
        3'b111: op2 = bitsel ? di : bx[15:8];

    endcase

end

endmodule
