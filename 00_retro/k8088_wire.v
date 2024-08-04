// R16 :: INC, DEC, PUSH, XCHG
wire [15:0] op20 =
    `OPC20 == AX ? ax : `OPC20 == CX ? cx :
    `OPC20 == DX ? dx : `OPC20 == BX ? bx :
    `OPC20 == SP ? sp : `OPC20 == BP ? bp :
    `OPC20 == SI ? si : di;