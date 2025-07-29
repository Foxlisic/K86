// 2T HLT :: Опрос внешних прерываний
9'b1111_0100: begin

    t  <= LOAD;
    ip <= ip;

end

// 2T CMC
9'b1111_0101: begin

    t  <= LOAD;
    flags[CF] = ~flags[CF];

end

// 2T Сброс и возведение флагов
8'b1111_10xx,
8'b1111_110x: begin

    t <= LOAD;

    case (in[2:1])
    2'b00: flags[CF] <= in[0]; // CLC, STC
    2'b01: flags[IF] <= in[0]; // CLI, STI
    2'b10: flags[DF] <= in[0]; // CLD, STD
    endcase

end

// 4T PUSH sreg
8'b000x_x110: begin

    t   <= PUSH;
    wb  <= in[4:3] == ES ? es :
           in[4:3] == CS ? cs :
           in[4:3] == SS ? ss : ds;

end

// 4T PUSH r16
8'b0101_0xxx: begin

    t   <= PUSH;
    wb  <= op20;

end

// 4T PUSHF
8'b1001_1100: begin

    t   <= PUSH;
    wb  <= (flags & 12'hFD5) | 2'b10;

end

// 2T CBW
8'b1001_1000: begin

    t <= LOAD;
    ax[15:8] <= {8{ax[7]}};

end

// 2T CWD
8'b1001_1001: begin

    t  <= LOAD;
    dx <= {16{ax[15]}};

end

// 2T SAHF
8'b1001_1110: begin

    t <= LOAD;
    flags[7:0] <= (ax[15:8] & 8'hD5) | 2'b10;

end

// 2T LAHF
8'b1001_1111: begin

    t <= LOAD;
    ax[15:8] <= (flags[7:0] & 8'hD5) | 2'b10;

end

// 2T SALC
8'b1101_0110: begin

    t <= LOAD;
    ax[7:0] <= {8{flags[CF]}};

end
