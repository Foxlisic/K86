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
                if (^kin[9:1]) begin kb_data <= kin[8:1]; kdone <= 1; end

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
