module sd
(
    input               clock,                  // 25 MHZ
    input               reset_n,
    // Физический доступ
    output  reg         sclk,                   // Тактовая частота
    output  reg         cs,                     // =0 Chipselect =1 Disabled
    input               miso,                   // Из SD
    output  reg         mosi,                   // На SD
    // Управление устройством
    input               command,                // =1 Сигнал запуска
    input               rw,                     // =0 Чтение =1 Запись
    input       [31:0]  lba,                    // Запрошенный номер сектора с 0
    output  reg         busy,                   // =1 Устройство занято
    output  reg         done,                   // Строб-сигнал DONE (1 такт)
    output  reg [ 3:0]  error,                  // =1 Ошибка доступа к SD
    output  reg [ 1:0]  card,                   // Тип карты 0,1,2,3=SDHC
    // Чтение или запись в память данных
    output  reg [ 8:0]  a,
    output      [ 7:0]  i,
    output  reg [ 7:0]  o,
    output  reg         w,
    output      [ 7:0]  sdbg                    // Отладка
);

assign sdbg = c0;

// ----------------------------------
localparam
    WAIT  = 0, ENSPI    = 1,
    INIT  = 2, COMMAND  = 3,
    FETCH = 4, READ     = 5,
    WRITE = 6;

// ----------------------------------

reg [ 4:0] t, r1, r2;
reg [ 7:0] c0, c1;
reg [ 1:0] c2;              // Делитель 4 тактов на передачу
reg [ 2:0] c3;              // Счетчик 8 тактов при передаче данных на SPI
reg [11:0] c4, c5;          // Для отсчета таймаутов
reg [17:0] timeout;
reg [31:0] arg;
reg [ 5:0] cmd;
reg [ 7:0] dw;

always @(posedge clock)
if (reset_n == 0) begin

    t       <= 0;
    busy    <= 0;
`ifdef ICARUS
    timeout <= 1;
`else
    timeout <= 0;
`endif

end else begin

    w    <= 0;
    done <= 0;

    case (t)

    // Ожидание получения команды
    WAIT: begin

        cs   <= 1;
        mosi <= 0;
        busy <= 0;
        sclk <= 0;
        card <= 0;

        // Сброс счетчиков
        {c0, c1, c2, c3, c4} <= 0;

        // Отчет таймаута простоя чипа
        timeout <= timeout ? timeout - 1 : 0;

        if (command) begin

            busy    <= 1;
            error   <= 0;
            t       <= timeout ? INIT : ENSPI; // READ|WRITE : ENSPI
            timeout <= 250000;

        end

    end

    // Отсчитать 80Т и выйти на процедуру инициализации [100 kHz]
    ENSPI: begin

        if (c0 == (250 >> 1) - 1) begin

            c0   <= 0;
            c1   <= c1 + 1;
            sclk <= ~sclk;

            if (c1 == 2*80-1) begin {c1, sclk} <= 0; t <= INIT; end

        end else c0 <= c0 + 1;

    end

    // Считывание байта DR из SPI и запись/чтение DW и вернуться на метку R2
    // Скорость 6.25 мгц (25:4)
    //      ___      ___         ___
    // ____/ 7 \____/ 6 \_....__/ 0 \__
    FETCH: case (c2)

        // CLK-DN
        0: begin c2 <= 1; sclk <= 0; end
        1: begin c2 <= 2; mosi <= dw[7]; end
        // CLK-UP
        2: begin c2 <= 3; sclk <= 1; end
        3: begin

            c2   <= 0;
            c3   <= c3 + 1;
            dw   <= {dw[6:0], miso};
            mosi <= 0;

            if (c3 == 7) begin t <= r2; sclk <= 0; end

        end

    endcase

    // Выполнение команды к SD, возврат на метку R1
    COMMAND: case (c1)

        // FOR i=0 TO 4095: IF (GET() == 0xFF) BREAK; NEXT i
        // При истечении таймаута выйти на WAIT с ошибкой
        0: begin c1 <= 1; cs <= 0; r2 <= COMMAND; c4 <= 4095; end
        1: begin c1 <= 2; dw <= 8'hFF; t <= FETCH; end
        2: begin

            c1 <= dw == 8'hFF ? 3 : 1;
            c4 <= c4 - 1;

            if (c4 == 0) begin error <= 1; t <= WAIT; end

        end
        // Отослать команду 8 бит
        3: begin t <= FETCH; dw <= {2'b01, cmd}; c1 <= 4; end
        // Отослать аргумент 32 бит
        4, 5, 6, 7: begin t <= FETCH; dw <= arg[31:24]; arg <= {arg[23:0], arg[31:24]}; c1 <= c1 + 1; end
        // Отсылка CRC
        8: begin

            t  <= FETCH;
            c1 <= 9;
            c4 <= 255;

            case (cmd) 0: dw <= 8'h95; 8: dw <= 8'h87; default: dw <= 8'hFF; endcase

        end
        // Ждать 256 проверок принятия команды
        // Тест флага BSY=1: в случае таймаута, ошибка #2
        9:  begin c1 <= 10; dw <= 8'hFF; t <= FETCH; end
        10: begin

            c1 <= dw[7] ? 9 : 0;
            c4 <= c4 - 1;

            if (c4 == 0) begin t <= WAIT; error <= 2; end
            else if (!dw[7]) t <= r1;

        end

    endcase

    // Отсылка команд на SD и вычисление типа карточки
    INIT: case (c0)

        // Отослать CMD0(0)
        0: begin c0 <= 1; r1 <= INIT; t <= COMMAND; {cmd, arg} <= 0; end
        // Проверить на R=01h, если неправильно, то ошибка #3
        1: begin

            c0  <= 2;
            cmd <= 8;
            arg <= 32'h01AA;

            if (dw != 8'h01) begin t <= WAIT; error <= 3; end
            else             begin t <= COMMAND; end

        end
        // Проверка бита 2 в ответе. Если там 1, то CARD1
        2: begin

            r2 <= INIT;
            c5 <= 4095;
            dw <= 8'hFF;

            if (dw[2])
                 begin c0 <= 7; card <= 1; end
            else begin c0 <= 3; t <= FETCH; end

        end
        // Дочитать 3 байта ответа
        3,4,5: begin c0 <= c0 + 1; dw <= 8'hFF; t <= FETCH; end
        // Если не AAh то ошибка карты #4; иначе это карта типа 2
        6: begin if (dw != 8'hAA) begin error <= 4; t <= WAIT; end else c0 <= 7; card <= 2; end
        // ACMD(0x40000000 или 0)
        7: begin c0 <= 8; t <= COMMAND; cmd <= 8'h37; arg <= 32'h0; end
        8: begin c0 <= 9; t <= COMMAND; cmd <= 8'h29; arg <= {card == 2 ? 8'h40 : 8'h00, 24'h0}; end
        // По истечении таймаута ошибка #5
        9: begin c0 <= dw ? 7 : 10; if (c5 == 0) begin error <= 5; t <= WAIT; end else c5 <= c5 - 1; end
        // Запрос SD2 дополнительной информации: CMD58(0)
        10: begin

            if (card == 2) begin c0 <= 11; t <= COMMAND; cmd <= 8'h3A; arg <= 0; end
            else           begin c0 <= 0;  t <= rw ? WRITE : READ; end

        end
        // Прочесть байт, проверить что есть старшие 2 бита и если есть, то это SDHC, и дочитать байты
        11: begin c0 <= 12; dw <= 8'hFF; t <= FETCH; r2 <= INIT; end
        12: begin c0 <= 13; dw <= 8'hFF; t <= FETCH; if (dw[7:6] == 2'b11) card <= 3; end
        13, 14: begin c0 <= c0 + 1; dw <= 8'hFF; t <= FETCH; end
        15: begin c0 <= 0; t <= rw ? WRITE : READ; end

    endcase

    // Чтение сектора
    READ: case (c0)

        // CMD17(LBA)
        0: begin c0 <= 1; r1 <= READ; t <= COMMAND; arg <= lba; cmd <= 17; end
        // Ожидать ответа 0xFE
        1: begin c0 <= 2; r2 <= READ; c4 <= 4095; end
        2: begin c0 <= 3; dw <= 8'hFF; t <= FETCH; end
        // Если FEh - OK, и если не FFh - ошибка #6, таймаут - ошибка #7
        3: begin

            if      (dw == 8'hFE) begin c0 <= 4; c4 <= 0; end
            else if (dw != 8'hFF) begin error <= 6; t <= WAIT; end
            else if (c4 == 8'h00) begin error <= 7; t <= WAIT; end
            else                  begin c0 <= 2; c4 <= c4 - 1; end

        end
        // Считывание 512 байт
        4: begin c0 <= 5; dw <= 8'hFF; t <= FETCH; end
        5: begin

            a   <= c4;
            w   <= 1;
            o   <= dw;
            c0  <= 4;
            c4  <= c4 + 1;

            if (c4 == 511) begin done <= 1; t <= WAIT; end

        end

    endcase

    endcase

end

endmodule
