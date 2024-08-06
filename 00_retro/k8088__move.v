// 6T+ MOV rm, r
8'b1000_10xx: case (m)

    // Прочесть ModRM
    0: begin

        m    <= 1;
        t    <= MODRM;
        skip <= !dir;

    end

    // Записать результат
    1: begin

        t  <= WB;
        wb <= op2;

    end

endcase

// MOV r, u [4-5T]
8'b1011_xxxx: case (m)

    // LO
    0: begin

        m       <= 1;
        t       <= opcode[3] ? INSTR : WB;
        size    <= opcode[3];
        dir     <= 1;
        wb      <= in;
        ip      <= ip + 1;
        `M53    <= `OPC20;

    end

    // HI
    1: begin

        t   <= WB;
        ip  <= ip + 1;
        wb[15:8] <= in;

    end

endcase

// 4T XCHG ax, r :: 3T NOP
8'b1001_0xxx: begin

    t    <= `OPC20 ? WB : LOAD;
    wb   <= ax;
    ax   <= op20;
    size <= 1;
    dir  <= 1;
    `M53 <= `OPC20;

end

// XCHG rm, r
8'b1000_011x: case (m)

    // op1=rm, op2=r
    0: begin

        t   <= MODRM;
        m   <= 1;
        dir <= 0;

    end

    // Записать op2 -> rm
    1: begin

        t    <= WB;
        m    <= 2;
        wb   <= op2;
        next <= INSTR;

    end

    // Записать op1 -> r
    2: begin

        t    <= WB;
        wb   <= op1;
        dir  <= 1;
        next <= LOAD;

    end


endcase

// MOV rm <=> sreg
8'b1000_11x0: case (m)

    0: begin

        t    <= MODRM;
        m    <= 1;
        size <= 1;
        skip <= !dir;

    end

    1: begin

        t  <= dir ? LOAD : WB;
        wb <= modrm[4:3] == ES ? es :
              modrm[4:3] == CS ? cs :
              modrm[4:3] == SS ? ss : ds;

        if (dir)
        case (modrm[4:3])
        ES: es <= op2;
        SS: ss <= op2;
        DS: ds <= op2;
        endcase

    end

endcase

// LEA r16, rm
8'b1000_1101: case (m)

    0: begin

        t    <= MODRM;
        m    <= 1;
        dir  <= 1;
        skip <= 1;

    end

    1: begin

        t   <= WB;
        wb  <= ea[15:0];

    end

endcase
