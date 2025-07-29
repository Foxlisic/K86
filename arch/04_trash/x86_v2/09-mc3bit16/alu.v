
// То количество бит, с которым работаем
wire [4:0] topbit = size ? 16 : 8;
wire [3:0] sizbit = size ? 15 : 7;

reg [16:0] r; // Новое значение 
reg [11:0] f; // Новые флаги

// Новый Zero/Sign/Carry Flag
wire zf = size ? r[15:0] == 0 : r[7:0] == 0;
wire sf = r[sizbit];
wire cf = r[topbit];
wire af = op1[4] ^ op2[4] ^ r[4];
wire pf = ~^r[7:0];

// Переполнение при разных операциях
wire ofa = (op1[sizbit] ^ op2[sizbit] ^ 1'b1) & (op1[sizbit] ^ r[sizbit]);
wire ofs = (op1[sizbit] ^ op2[sizbit]       ) & (op1[sizbit] ^ r[sizbit]);

always @(*) 
begin

    // Вычисление результата АЛУ
    case (alu)
    
        ADD: r = op1 + op2; // ADD
        OR:  r = op1 | op2;
        ADC: r = op1 + op2 + flags[CF];
        SBB: r = op1 - op2 - flags[CF];
        AND: r = op1 & op2;
        SUB, CMP: r = op1 - op2;
        XOR: r = op1 ^ op2;

    endcase
   
    case (alu)
    
        ADD, ADC: f = {
        
            /* O */ ofa,
            /* D */ flags[DF],
            /* I */ flags[IF],
            /* T */ flags[TF],
            /* S */ sf,
            /* Z */ zf,
            /* 0 */ 1'b0,
            /* A */ af,
            /* 0 */ 1'b0,
            /* P */ pf,
            /* 1 */ 1'b1,
            /* C */ cf
        };
        
        SUB, SBB, CMP: f = {
        
            /* O */ ofs,
            /* D */ flags[DF],
            /* I */ flags[IF],
            /* T */ flags[TF],
            /* S */ sf,
            /* Z */ zf,
            /* 0 */ 1'b0,
            /* A */ af,
            /* 0 */ 1'b0,
            /* P */ pf,
            /* 1 */ 1'b1,
            /* C */ cf
        };
        
        AND, XOR, OR: f = {
        
            /* O */ 1'b0,
            /* D */ flags[DF],
            /* I */ flags[IF],
            /* T */ flags[TF],
            /* S */ sf,
            /* Z */ zf,
            /* 0 */ 1'b0,
            /* A */ 1'b0,
            /* 0 */ 1'b0,
            /* P */ pf,
            /* 1 */ 1'b1,
            /* C */ 1'b0
        };
    
    endcase

end