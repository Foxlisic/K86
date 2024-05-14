/* verilator lint_off WIDTH */
module kbd
(
    input clock,
    input ps_clock,
    input ps_data,

    output reg       done,
    output reg [7:0] data
);

reg [1:0]   klatch   = 2'b00;
reg [3:0]   kcount   = 1'b0;
reg [9:0]   kin      = 1'b0;
reg [19:0]  kout     = 1'b0;
reg [7:0]   kb_data;
reg         kbusy, kdone, released, shift, extended;

// Для Icarus Verilog
initial begin

    data        = 8'h00;
    shift       = 1'b0;
    kbusy       = 1'b0;
    kdone       = 1'b0;
    done        = 1'b0;
    shift       = 1'b0;
    released    = 1'b0;
    extended    = 1'b0;

end

// Для повышения точности
always @(negedge clock) begin done <= kdone; data <= kb_data; end

// Основная логика работы контроллера
always @(posedge clock) begin

    kdone <= 1'b0;

    // Процесс приема сигнала
    if (kbusy) begin

        // Позитивный фронт
        if (klatch == 2'b01) begin

            // Завершающий такт
            if (kcount == 4'hA) begin

                kbusy   <= 1'b0;
                kb_data <= 1'b0;

                // Четность данных должна совпасть
                if (^kin[9:1]) begin

                    // Клавиша отпущена
                    if      (kin[8:1] == 8'hF0) begin released <= 1'b1; end
                    else if (kin[8:1] == 8'hE0) begin extended <= 1'b1; end
                    // Декодирование клавиши
                    else begin

                        // Отправка клавиши только при KeyDown
                        kdone <= ~released;

                        // Декодирование клавиши
                        case ({extended, kin[8:1]})

                            // Левый и правый SHIFT равнозначны
                            /* SH */ 8'h12, 8'h59: begin shift <= ~released; kdone <= 1'b0; end

                            // Цифробуквенная клавиатура
                            /* Aa */ 8'h1C: kb_data <= shift ? 8'h41 : 8'h61;
                            /* Bb */ 8'h32: kb_data <= shift ? 8'h42 : 8'h62;
                            /* Cc */ 8'h21: kb_data <= shift ? 8'h43 : 8'h63;
                            /* Dd */ 8'h23: kb_data <= shift ? 8'h44 : 8'h64;
                            /* Ee */ 8'h24: kb_data <= shift ? 8'h45 : 8'h65;
                            /* Ff */ 8'h2B: kb_data <= shift ? 8'h46 : 8'h66;
                            /* Gg */ 8'h34: kb_data <= shift ? 8'h47 : 8'h67;
                            /* Hh */ 8'h33: kb_data <= shift ? 8'h48 : 8'h68;
                            /* Ii */ 8'h43: kb_data <= shift ? 8'h49 : 8'h69;
                            /* Jj */ 8'h3B: kb_data <= shift ? 8'h4A : 8'h6A;
                            /* Kk */ 8'h42: kb_data <= shift ? 8'h4B : 8'h6B;
                            /* Ll */ 8'h4B: kb_data <= shift ? 8'h4C : 8'h6C;
                            /* Mm */ 8'h3A: kb_data <= shift ? 8'h4D : 8'h6D;
                            /* Nn */ 8'h31: kb_data <= shift ? 8'h4E : 8'h6E;
                            /* Oo */ 8'h44: kb_data <= shift ? 8'h4F : 8'h6F;
                            /* Pp */ 8'h4D: kb_data <= shift ? 8'h50 : 8'h70;
                            /* Qq */ 8'h15: kb_data <= shift ? 8'h51 : 8'h71;
                            /* Rr */ 8'h2D: kb_data <= shift ? 8'h52 : 8'h72;
                            /* Ss */ 8'h1B: kb_data <= shift ? 8'h53 : 8'h73;
                            /* Tt */ 8'h2C: kb_data <= shift ? 8'h54 : 8'h74;
                            /* Uu */ 8'h3C: kb_data <= shift ? 8'h55 : 8'h75;
                            /* Vv */ 8'h2A: kb_data <= shift ? 8'h56 : 8'h76;
                            /* Ww */ 8'h1D: kb_data <= shift ? 8'h57 : 8'h77;
                            /* Xx */ 8'h22: kb_data <= shift ? 8'h58 : 8'h78;
                            /* Yy */ 8'h35: kb_data <= shift ? 8'h59 : 8'h79;
                            /* Zz */ 8'h1A: kb_data <= shift ? 8'h5A : 8'h7A;

                            // Цифры
                            /* 0) */ 8'h45: kb_data <= shift ? 8'h29 : 8'h30;
                            /* 1! */ 8'h16: kb_data <= shift ? 8'h21 : 8'h31;
                            /* 2@ */ 8'h1E: kb_data <= shift ? 8'h40 : 8'h32;
                            /* 3# */ 8'h26: kb_data <= shift ? 8'h23 : 8'h33;
                            /* 4$ */ 8'h25: kb_data <= shift ? 8'h24 : 8'h34;
                            /* 5% */ 8'h2E: kb_data <= shift ? 8'h25 : 8'h35;
                            /* 6^ */ 8'h36: kb_data <= shift ? 8'h5E : 8'h36;
                            /* 7& */ 8'h3D: kb_data <= shift ? 8'h26 : 8'h37;
                            /* 8* */ 8'h3E: kb_data <= shift ? 8'h2A : 8'h38;
                            /* 9( */ 8'h46: kb_data <= shift ? 8'h28 : 8'h39;

                            // Спецсимволы
                            /* `~ */ 8'h0E: kb_data <= shift ? 8'h7E : 8'h60;
                            /* -_ */ 8'h4E: kb_data <= shift ? 8'h5F : 8'h2D;
                            /* =+ */ 8'h55: kb_data <= shift ? 8'h2B : 8'h3D;
                            /* \| */ 8'h5D: kb_data <= shift ? 8'h7C : 8'h5C;
                            /* [{ */ 8'h54: kb_data <= shift ? 8'h7B : 8'h5B;
                            /* ]} */ 8'h5B: kb_data <= shift ? 8'h7D : 8'h5D;
                            /* ;: */ 8'h4C: kb_data <= shift ? 8'h3A : 8'h3B;
                            /* '" */ 8'h52: kb_data <= shift ? 8'h22 : 8'h27;
                            /* ,< */ 8'h41: kb_data <= shift ? 8'h3C : 8'h2C;
                            /* .> */ 8'h49: kb_data <= shift ? 8'h3E : 8'h2E;
                            /* /? */ 8'h4A: kb_data <= shift ? 8'h3F : 8'h2F;

                            // Разные клавиши
                            /* BACK */ 8'h66: kb_data <= 8'h08;
                            /* TAB  */ 8'h0D: kb_data <= 8'h09;
                            /* ENT  */ 8'h5A: kb_data <= 8'h0A;
                            /* ESC  */ 8'h76: kb_data <= 8'h1B;
                            /* SPC  */ 8'h29: kb_data <= 8'h20;

                            // Дополненный набор
                            /* PGUP */ 9'h17D: kb_data <= 8'h01;
                            /* PGDN */ 9'h17A: kb_data <= 8'h02;
                            /* UP   */ 9'h175: kb_data <= 8'h03;
                            /* RT   */ 9'h174: kb_data <= 8'h04;
                            /* DN   */ 9'h172: kb_data <= 8'h05;
                            /* LF   */ 9'h16B: kb_data <= 8'h06;
                            /* DEL  */ 9'h171: kb_data <= 8'h07;
                            /* INS  */ 9'h16C: kb_data <= 8'h0B;
                            /* HOME */ 9'h170: kb_data <= 8'h0C;
                            /* END  */ 9'h169: kb_data <= 8'h0D;

                            // Клавиши, которые не играют никакой роли
                            default: kdone <= 1'b0;

                        endcase

                        released <= 1'b0;
                        extended <= 1'b0;

                    end

                end
            end

            kcount  <= kcount + 1'b1;
            kin     <= {ps_data, kin[9:1]};

        end

        // Считать "зависший процесс"
        kout <= ps_clock ? kout + 1 : 1'b0;

        // И если прошло более 20 мс, то перевести в состояние ожидания
        if (kout > 25000*20) kbusy <= 1'b0;

    end else begin

        // Обнаружен негативный фронт \__
        if (klatch == 2'b10) begin

            kbusy   <= 1'b1;    // Активировать прием данных
            kcount  <= 1'b0;
            kout    <= 1'b0;

        end

    end

    klatch <= {klatch[0], ps_clock};

end

endmodule
