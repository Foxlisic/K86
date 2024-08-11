// JMP FAR xxxx:xxxx [6T]
8'b1110_1010: case (m)

    // LO Offset
    0: begin

        m   <= 1;
        ip  <= ip + 1;
        ea[7:0]  <= in;

    end

    // HI Offset
    1: begin

        m   <= 2;
        ip  <= ip + 1;
        ea[15:8] <= in;

    end

    // LO Segment
    2: begin

        m   <= 3;
        ip  <= ip + 1;
        seg[7:0] <= in;

    end

    // HI Segment
    3: begin

        t  <= LOAD;
        m  <= 0;
        ip <= ea;
        cs <= {in, seg[7:0]};

    end

endcase

// JMP CCC short rel8
8'b0111_xxxx: begin

    t  <= LOAD;
    ip <= ip + 1 + (jump[ opcode[3:1] ] != opcode[0] ? signex : 0);

end

// 3T LOOP<c> b8
8'b1110_000x: begin

    t  <= LOAD;
    ip <= ip + 1 + (cx != 1 && flags[ZF] == opcode[0] ? signex : 0);
    cx <= cx - 1;

end

// 3T LOOP b8
8'b1110_0010: begin

    t  <= LOAD;
    ip <= ip + 1 + (cx != 1 ? signex : 0);
    cx <= cx - 1;

end

// 3T JCXZ b8
8'b1110_0011: begin

    t  <= LOAD;
    ip <= ip + 1 + (cx == 0 ? signex : 0);

end
