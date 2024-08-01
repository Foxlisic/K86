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
