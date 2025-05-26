`define TERM begin term <= 1; m <= 0; end

localparam

    RUN     = 0,
    MODRM   = 1,
    WB      = 2;

localparam CF  = 0, PF = 2, AF  = 4, ZF  = 6, SF  = 7, TF  = 8, IF  = 9, DF  = 10, OF = 11;
localparam ADD = 0, OR = 1, ADC = 2, SBB = 3, AND = 4, SUB = 5, XOR = 6, CMP = 7;

wire [ 7:0] opcode = m ? opcache : i;

// Мультиплексор на выбор регистров из диапазона [2:0]
wire [15:0] i20 =
    i[2:0] == 3'h0 ? (size ? ax : ax[ 7:0]) :
    i[2:0] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[2:0] == 3'h2 ? (size ? dx : dx[ 7:0]) :
    i[2:0] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[2:0] == 3'h4 ? (size ? sp : ax[15:8]) :
    i[2:0] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[2:0] == 3'h6 ? (size ? si : dx[15:8]) :
                     (size ? di : bx[15:8]);

// Мультиплексор на выбор регистров из диапазона [5:3]
wire [15:0] i53 =
    i[5:3] == 3'h0 ? (size ? ax : ax[ 7:0]) :
    i[5:3] == 3'h1 ? (size ? cx : cx[ 7:0]) :
    i[5:3] == 3'h2 ? (size ? dx : dx[ 7:0]) :
    i[5:3] == 3'h3 ? (size ? bx : bx[ 7:0]) :
    i[5:3] == 3'h4 ? (size ? sp : ax[15:8]) :
    i[5:3] == 3'h5 ? (size ? bp : cx[15:8]) :
    i[5:3] == 3'h6 ? (size ? si : dx[15:8]) :
                     (size ? di : bx[15:8]);

wire [15:0] ipn = ip + 1;

// ---------------------------------------------------------------------
// Базовое арифметическо-логическое устройство
// ---------------------------------------------------------------------

wire [16:0] ar =
    alu == ADD ? op1 + op2 :
    alu == ADC ? op1 + op2 + flags[CF] :
    alu == SBB ? op1 - op2 - flags[CF] :
    alu == AND ? op1 & op2 :
    alu == XOR ? op1 ^ op2 :
    alu == OR  ? op1 | op2 :
                 op1 - op2;

wire [3:0]  top = size ? 15 : 7;
wire        isa = alu == ADD || alu == ADC;
wire        isl = alu != AND && alu != OR && alu != XOR;

wire new_o = (op1[top] ^ op2[top] ^ isa) & (op1[top] ^ ar[top]);
wire new_s = ar[top];
wire new_z = 0 == (size ? ar[15:0] : ar[7:0]);
wire new_a = op1[4] ^ op2[4] ^ ar[4];
wire new_p = ~^ar[7:0];
wire new_c = ar[top + 1];

wire [11:0] af = {isl&new_o, flags[10:8], new_s, new_z, 1'b0, isl&new_a, 1'b0, new_p, 1'b1, isl&new_c};
