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
