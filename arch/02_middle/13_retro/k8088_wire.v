// Текущий опкод
wire [2:0] opc = t == FETCH ? in : opcode;

// R16 :: INC, DEC, PUSH, XCHG
wire [15:0] op20 =
    opc[2:0] == AX ? ax :
    opc[2:0] == CX ? cx :
    opc[2:0] == DX ? dx :
    opc[2:0] == BX ? bx :
    opc[2:0] == SP ? sp :
    opc[2:0] == BP ? bp :
    opc[2:0] == SI ? si : di;

// Условия переходов
wire [7:0] jump = {
   (flags[SF] ^ flags[ZF]) || flags[ZF],
    flags[SF] ^ flags[OF],
    flags[PF],
    flags[SF],
    flags[ZF] || flags[CF],
    flags[ZF],
    flags[CF],
    flags[OF]
};

wire [15:0] signex = {{8{in[7]}}, in};
