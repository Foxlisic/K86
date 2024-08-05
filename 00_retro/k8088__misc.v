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
