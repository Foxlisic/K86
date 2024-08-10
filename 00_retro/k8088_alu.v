// ---------------------------------------------------------------------
// Арифметико-логика
// ---------------------------------------------------------------------

// Расчет результата
wire [16:0] alu_r =
    alu == ADD ? op1 + op2 :
    alu == ADC ? op1 + op2 + flags[CF] :
    alu == SBB ? op1 - op2 - flags[CF] :
    alu == OR  ? op1 | op2 :
    alu == AND ? op1 & op2 :
    alu == XOR ? op1 ^ op2 :
                 op1 - op2;  // SUB, CMP

// Старший бит в результате
wire [3:0] top = size ? 15 : 7;

// Тип инструкции
wire alu_add   = (alu == ADD || alu == ADC);
wire alu_arith = (alu == SUB || alu == SBB || alu == CMP || alu_add);

// Вычисление обших флагов
wire sf = alu_r[top];
wire zf = (0 == (size ? alu_r[15:0] : alu_r[7:0]));
wire af = op1[4] ^ op2[4] ^ alu_r[4];
wire pf = ~^alu_r[7:0];
wire cf = alu_r[size ? 16 : 8];
wire of = ((op1[top] ^ op2[top] ^ alu_add) & (op1[top] ^ alu_r[top]));

// Итоговые флаги
wire [11:0] alu_f = {of & alu_arith, flags[10:8], sf, zf, 1'b0, af & alu_arith, 1'b0, pf, 1'b1, cf & alu_arith};

// ---------------------------------------------------------------------
// Сдвиги
// ---------------------------------------------------------------------

// Подготовка сдвигов 8 бит  ===
wire [16:0] r8 =
//                          [15...8]    [7:0]
    alu == ROL ? {op1[7],   op1[7:0],   op1[7:0]           } :
    alu == RCL ? {op1[7],   op1[7:0],   flags[CF], op1[7:1]} :
    alu == SAL ||
    alu == SHL ? {op1[7],   op1[7:0],   8'b0} :
//                                      [8:1]
    alu == ROR ? {          op1[7:0],   op1[7:0],  op1[0]  } :
    alu == RCR ? {op1[6:0], flags[CF],  op1[7:0],  op1[0]  } :
    alu == SHR ? {          8'b0,       op1[7:0],  op1[0]  } :
                 {         {8{op1[7]}}, op1[7:0],  op1[0]  };   // SAR 8

// Подготовка сдвигов 16 бит ===
wire [32:0] r16 =
//                          [31...16]     [15:0]
    alu == ROL ? {op1[15],  op1[15:0],   op1[15:0]           } :
    alu == RCL ? {op1[15],  op1[15:0],   flags[CF], op1[15:1]} :
    alu == SAL ||
    alu == SHL ? {op1[15],  op1[15:0],   16'b0} :
//                                       [8:1]
    alu == ROR ? {          op1[15:0],   op1[15:0],  op1[0]  } :
    alu == RCR ? {op1[14:0],flags[CF],   op1[15:0],  op1[0]  } :
    alu == SHR ? {          8'b0,        op1[15:0],  op1[0]  } :
                 {         {8{op1[15]}}, op1[15:0],  op1[0]  };   // SAR 16

// Сдвиги 8 или 16
wire [ 3:0] rbct = op2 > 7  ? 8  : op2[2:0];
wire [ 4:0] rwct = op2 > 15 ? 16 : op2[3:0];
wire [ 8:0] shrb = r8  >> rbct;
wire [16:0] shlb = r8  << rwct;
wire [16:0] shrw = r16 >> rwct;
wire [32:0] shlw = r16 << rwct;
wire [15:0] wbr  = size ? (alu[0] ? shrw[16:1] : shlw[31:16]) :
                          (alu[0] ? shrb[8:1]  : shlb[15:8]);

