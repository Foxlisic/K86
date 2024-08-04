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
wire of = ((op1[top] ^ op2[top] ^ alu_add) & (op1[top] ^ alu_r[top])) & alu_arith;

// Итоговые флаги
wire [11:0] alu_f = {of, flags[10:8], sf, zf, 1'b0, af, 1'b0, pf, 1'b1, cf};
