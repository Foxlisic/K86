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

    if (jump[ opcode[3:1] ] != opcode[0]) begin
        ip <= ip + 1 + {{8{in[7]}}, in};
    end else begin
        ip <= ip + 2;
    end

end
