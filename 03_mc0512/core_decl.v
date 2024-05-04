// Вычисление адреса в памяти 1MB
assign address = cp ? {seg, 4'h0} + ea : {cs, 4'h0} + ip;

// ОБЪЯВЛЕНИЯ
// -----------------------------------------------------------------------------
localparam
    LOAD    = 0,    RUN     = 1,    WB      = 2,
    PUSH    = 3,    PUSH2   = 4,    PUSH3   = 5,
    POP     = 6,    POP2    = 7,    POP3    = 8,
    MODRM   = 9,    WB2     = 10,   WB3     = 11;

localparam
    ES = 2'b00,  CS = 2'b01,  SS = 2'b10,  DS = 2'b11,
    AX = 3'b000, CX = 3'b001, DX = 3'b010, BX = 3'b011,
    SP = 3'b100, BP = 3'b101, SI = 3'b110, DI = 3'b111;

localparam
    CF = 0, PF = 2, AF =  4, ZF =  6, SF = 7,
    TF = 8, IF = 9, DF = 10, OF = 11;

localparam
    ADD = 3'b000, OR  = 3'b001, ADC = 3'b010, SBB = 3'b011,
    AND = 3'b100, SUB = 3'b101, XOR = 3'b110, CMP = 3'b111;

// РЕГИСТРЫ
// -----------------------------------------------------------------------------
reg [15:0]  ax = 16'h120A, bx = 16'h5678, cx = 16'hFFFF, dx = 16'hEF12,
            sp = 16'hBABA, bp = 16'hDEAD, si = 16'hBEEF, di = 16'hDADD,
            es = 16'h1234, cs = 16'h0000, ss = 16'hDEAD, ds = 16'hBEEF;
//                     ODIT SZ A  P C
reg [11:0]  flag = 12'b0000_0000_0010;
reg [15:0]  ip, ips;

// СИСТЕМНЫЕ РЕГИСТРЫ
// -----------------------------------------------------------------------------
reg         cp, cpen;
reg [ 3:0]  m;
reg [ 5:0]  ta, tb, tm;
reg [15:0]  ea, seg, op1, op2, wb;
reg [ 7:0]  opcode, modrm;
reg [ 2:0]  alu;
reg         size, dir;
reg [ 2:0]  preip, overs, _overs;   // Over Segment
reg [ 1:0]  rep, _rep;              // Repeat:

// ВЫЧИСЛЕНИЯ
// -----------------------------------------------------------------------------
wire [15:0] ipn = ip + 1;
wire [15:0] ipx = ip - preip;
wire [15:0] signex = {{8{in[7]}}, in};
wire [15:0] ipsign = ip + 1 + signex;

// УСЛОВНЫЙ ПЕРЕХОД
// -----------------------------------------------------------------------------
wire [7:0] branches =
{
    (flag[SF] ^ flag[OF]) | flag[ZF],  // 7: (ZF=1) OR (SF!=OF)
    (flag[SF] ^ flag[OF]),             // 6: SF!=OF
     flag[PF],
     flag[SF],
     flag[CF] | flag[OF],              // 3: CF != OF
     flag[ZF],
     flag[CF],
     flag[OF]
};

// ЗНАЧЕНИЕ РЕГИСТРОВ
// -----------------------------------------------------------------------------

// 16-битные операнды на LOAD-секции
wire m0    = (ta == LOAD);
wire rsize = m0 | size;

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

// АЛУ БАЗОВОЕ НА 8 ФУНКЦИИ
// -----------------------------------------------------------------------------

// Вычисление результата
wire [16:0] alu_res =
    alu == ADD ? op1 + op2 :
    alu == ADC ? op1 + op2 + flag[CF] :
    alu == SBB ? op1 - op2 - flag[CF] :
    alu == AND ? op1 & op2 :
    alu == OR  ? op1 | op2 :
    alu == XOR ? op1 ^ op2 :
                 op1 - op2;     // SUB, CMP

wire [4:0] top = size ? 15 : 7;

wire is_add = (alu == ADD || alu == ADC);
wire is_lgc = (alu != AND && alu != XOR && alu != OR);

wire sf = size ? alu_res[top] : alu_res[top];
wire zf = (size ? alu_res[15:0] : alu_res[7:0]) == 0;
wire cf = (size ? alu_res[top + 1] : alu_res[top + 1]);
wire af = op1[4] ^ op2[4] ^ alu_res[4];
wire pf = ~^alu_res[7:0];
wire of = (op1[top] ^ op2[top] ^ is_add) & (op1[top] ^ alu_res[top]);

// ВЫчисление флагов
wire [11:0] alu_flag = {of & is_lgc, flag[10:8], sf, zf, 1'b0, af & is_lgc, 1'b0, pf, 1'b1, (cf & is_lgc)};

// ДЕСЯТИЧНАЯ КОРРЕКЦИЯ DAA, DAS, AAA, AAS
// -----------------------------------------------------------------------------
wire        daa_m = flag[AF] || ax[3:0] > 4'h9;
wire [ 8:0] daa_i = daa_m ? (in[3] ? ax[7:0] - 3'h6 : ax[7:0] + 3'h6) : ax[7:0];
wire        daa_c = daa_m ? daa_i[8] : flag[CF];
wire        daa_t = daa_c || daa_i[7:0] > 8'h9F;
wire [ 7:0] daa_r = daa_t ? (in[3] ? daa_i[7:0] - 8'h60 : daa_i[7:0] + 8'h60) : daa_i[7:0];
wire        daa_x = daa_t || daa_c;
wire [11:0] daa_f = {flag[11:8], daa_r[7], ~|daa_r, 1'b0, flag[AF] | daa_m, 1'b0, ~^daa_r, 1'b1, daa_x};
wire [ 8:0] aaa_h = daa_m ? (in[3] ? ax[15:8] - 1'b1 : ax[15:8] + 1'b1) : ax[15:8];
wire [15:0] aaa_r = {aaa_h, 4'h0, daa_i[3:0]};
wire [11:0] aaa_f = {flag[11:5], daa_m, flag[3:1], daa_m};
