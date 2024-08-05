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
