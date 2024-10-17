/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */

module vidac
(
    input               clock,
    input               reset_n,

    // Запрос на выполнение
    input               cmd,

    // Подключение к разделяемой видеопамяти различных модулей
    output  reg [16:0]  a,
    input       [ 7:0]  i,
    output  reg [ 7:0]  o,
    output  reg         w,
    output  reg         bsy
);

`define ACMD 17'h10000

// ---------------------------------------------------------------------

reg [ 3:0]  t;
reg [ 3:0]  b;
reg [16:0]  u;
reg [15:0]  dx, dy;
reg [15:0]  x,  y,  err;
reg [15:0]  x1, y1, x2, y2;
reg [ 7:0]  cl;

// Знаковое сравнение чисел
wire [15:0] sub_x = x2 - x1;
wire [15:0] sub_y = y2 - y1;
wire [15:0] abs_x = xlt ? -sub_x : sub_x;

// (A ^ B) & (A ^ C) ^ C :: Если OF != SF
wire        xlt  = (x2[15] ^ x1[15]) & (x2[15] ^ sub_x[15]) ^ sub_x[15];
wire        ylt  = (y2[15] ^ y1[15]) & (y2[15] ^ sub_y[15]) ^ sub_y[15];
wire [15:0] e1   = {err, 1'b0} + dy;
wire [15:0] e2   = {err, 1'b0} - dx;

// ---------------------------------------------------------------------
// Блок распределения команд и наблюдение за их исполнением
// ---------------------------------------------------------------------

always @(posedge clock)
if (reset_n == 0) begin

    bsy <= 0;

// Получена команда от процессора
end else if ({bsy, cmd} == 2'b01) begin

    bsy <= 1;
    t   <= 0;
    u   <= `ACMD;
    w   <= 0;

// Ждать завершения исполнения команды
end else begin

    w <= 0;

    case (t)

        // Считывание кода команды
        0: begin t <= 1; a <= u; end

        // Прочесть очередной код команды
        1: begin

            case (i)

                // LINE [x1:word,y1:word]-[x2:word,y2:word],c:byte
                1: begin t <= 2; b <= 9; end
                // Любой не объявленный код команды сбрасывает в BSY=0
                default: begin t <= 0; bsy <= 0; end

            endcase

            a <= a + 1;

        end

        // ---------------------------------------------------------------------
        // Рисование линии
        // ---------------------------------------------------------------------

        // Считывание данных для обработки
        2: if (b) begin

            a <= a + 1;
            b <= b - 1;

            {cl,y2,x2,y1,x1} <= {i,cl,y2,x2,y1,x1[15:8]};

        end
        // Подготовка данных к рендерингу
        else begin

            t <= 3;
            u <= a;
            o <= cl;

            // Поменять точки местами, если Y2 > Y1
            if (ylt) begin {x1, y1, x2, y2} <= {x2, y2, x1, y1}; end

        end
        // Расчет параметров
        3: begin

            t   <= 4;
            dx  <= abs_x;           // dx=|X2-X1|
            dy  <= sub_y;           // dy=|Y2-Y1|
            err <= abs_x - sub_y;   // error = dx - dy
            x   <= x1;
            y   <= y1;

        end
        // Рисование точек линии
        4: begin

            a   <= (y << 8) + (y << 6) + x;
            w   <= x < 320 && y < 200;
            x   <= x + (e1[15] ? 0 : (xlt ? -1 : 1));
            y   <= y + (e2[15] ? 1 : 0);
            err <= err + (e1[15] ? 0 : -dy) + (e2[15] ? dx : 0);

            // Условие выхода из цикла
            if ((x == x2 && y == y2) || (y >= 200 && y[15] == 0) || (x >= 320 && xlt)) t <= 0;

        end

    endcase

end

endmodule

