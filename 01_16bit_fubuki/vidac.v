/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */

module vidac
(
    input               clock,
    input               reset_n,

    // Запрос на выполнение
    input               cmd,
    input               page,       // Номер видеостраницы

    // Подключение к разделяемой видеопамяти различных модулей
    output  reg [17:0]  a,
    input       [ 7:0]  i,
    output  reg [ 7:0]  o,
    output  reg         w,
    output  reg         bsy,
    // Запрос текстуры
    output  reg [ 7:0]  tx,
    output  reg [ 7:0]  ty,
    input       [ 7:0]  td          // Данные о текстуре
);

// Первые 128К буфер; старшие 128К данные
`define ACMD 18'h20000

localparam
    LINE        = 1,
    BLOCK       = 2,
    BLOCK_FILL  = 3,
    POLY        = 4,
    CIRCLE      = 5,
    CIRCLE_FILL = 6,
    BLOCK_TEX   = 7;

// ---------------------------------------------------------------------

reg [ 7:0]  t, tn, comm;
reg [ 3:0]  b;
reg [17:0]  u;
reg [15:0]  dx, dy;
reg [15:0]  x,  y,  err;
reg [15:0]  x1, y1, x2, y2, _x2, _y2;

// Знаковое сравнение чисел
wire [15:0] sub_x = x2 - x1;
wire [15:0] sub_y = y2 - y1;
wire [15:0] abs_x = xlt ? -sub_x : sub_x;

// (A ^ B) & (A ^ C) ^ C :: Если OF != SF
wire        xlt  = (x2[15] ^ x1[15]) & (x2[15] ^ sub_x[15]) ^ sub_x[15];
wire        ylt  = (y2[15] ^ y1[15]) & (y2[15] ^ sub_y[15]) ^ sub_y[15];
wire [15:0] e1   = {err, 1'b0} + dy;
wire [15:0] e2   = {err, 1'b0} - dx;

// AX = 320*Y + X
wire [16:0] ax   = (y << 8) + (y << 6) + x + {page, 16'h0000};
wire        wx   = x < 320 && y < 200;
wire        yof  = (y >= 200 && y[15] == 0);
wire [15:0] cirx = dx + 4*x2 + 6;

// Текстурированный прямоугольник
wire [ 9:0] dxnx = dx + _y2[ 7:0]; // texture.w
wire [ 9:0] dynx = dy + _y2[15:8]; // texture.h
wire [ 3:0] dxrs = ~{xd_0[3], xd_0[2], xd_0[1], xd_0[0]};
wire [ 3:0] dyrs = ~{yd_0[3], yd_0[2], yd_0[1], yd_0[0]};

// Деление dxnx на x2
wire [ 8:0] xd_3 = dxnx - 8*x2; wire [ 7:0] dx_3 = (xd_3[8] ? dxnx : xd_3);
wire [ 8:0] xd_2 = dx_3 - 4*x2; wire [ 7:0] dx_2 = (xd_2[8] ? dx_3 : xd_2);
wire [ 8:0] xd_1 = dx_2 - 2*x2; wire [ 7:0] dx_1 = (xd_1[8] ? dx_2 : xd_1);
wire [ 8:0] xd_0 = dx_1 -   x2; wire [ 7:0] dx_0 = (xd_0[8] ? dx_1 : xd_0);

// Деление dynx на y2
wire [ 8:0] yd_3 = dynx - 8*y2; wire [ 7:0] dy_3 = (yd_3[8] ? dynx : yd_3);
wire [ 8:0] yd_2 = dy_3 - 4*y2; wire [ 7:0] dy_2 = (yd_2[8] ? dy_3 : yd_2);
wire [ 8:0] yd_1 = dy_2 - 2*y2; wire [ 7:0] dy_1 = (yd_1[8] ? dy_2 : yd_1);
wire [ 8:0] yd_0 = dy_1 -   y2; wire [ 7:0] dy_0 = (yd_0[8] ? dy_1 : yd_0);

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
                LINE:
                begin t <= 2; tn <= 3; b <= 9; end
                // BLOCK [x1,y1]-[x2,y2],c :: 2-не закрашенный, 3-закрашенный
                BLOCK,
                BLOCK_FILL:
                begin t <= 2; tn <= 6; b <= 9; end
                // LINE -[x2:word,y2:word],c:byte Дорисовать линию
                POLY:
                begin t <= 8; b <= 5; end
                // 5=CIRCLE (x,y),r,c; 6=CIRCLEFILL
                CIRCLE,
                CIRCLE_FILL:
                begin t <= 9; b <= 7; end
                // 7=BITBLT (x:byte,y:byte,w:byte,h:byte)-(x1:word,y1:word,w:word,h:word)
                BLOCK_TEX: begin t <= 13; b <= 12; end
                // Любой не объявленный код команды сбрасывает в BSY=0
                default: begin t <= 0; bsy <= 0; end

            endcase

            a <= a + 1;
            comm <= i;

        end

        // ---------------------------------------------------------------------
        // Рисование линии
        // ---------------------------------------------------------------------

        // Считывание данных для обработки (LINE, BLOCK)
        2: if (b) begin

            a <= a + 1;
            b <= b - 1;
            {o,y2,x2,y1,x1} <= {i,o,y2,x2,y1,x1[15:8]};

        end else t <= tn;
        // Подготовка данных к рендерингу
        3: begin

            t <= 4;
            u <= a;

            // Сохранить значение точки для линии-полигона
            {_x2, _y2} <= {x2, y2};

            // Поменять точки местами, если Y2 > Y1
            if (ylt) begin {x1, y1, x2, y2} <= {x2, y2, x1, y1}; end

        end
        // Расчет параметров
        4: begin

            t   <= 5;
            dx  <= abs_x;           // dx=|X2-X1|
            dy  <= sub_y;           // dy=|Y2-Y1|
            err <= abs_x - sub_y;   // error = dx - dy
            x   <= x1;
            y   <= y1;

        end
        // Рисование точек линии
        5: begin

            a   <= ax;
            w   <= wx;
            x   <= x + (e1[15] ? 0 : (xlt ? -1 : 1));
            y   <= y + (e2[15] ? 1 : 0);
            err <= err + (e1[15] ? 0 : -dy) + (e2[15] ? dx : 0);

            // Условие выхода из цикла
            if ((x == x2 && y == y2) || yof || (x >= 320 && xlt)) t <= 0;

        end

        // ---------------------------------------------------------------------
        // Рисование блока
        // ---------------------------------------------------------------------

        // Коррекция
        6: begin

            t <= 7;
            u <= a;

            {x, x1, x2} <= xlt ? {x2, x2, x1} : {x1, x1, x2};
            {y, y1, y2} <= ylt ? {y2, x2, y1} : {y1, y1, y2};

        end
        // Если не закрашенный, то рисуется полностью верхний и нижний,
        // Слева и справа только по одной точке
        7: begin

            a <= ax;
            w <= wx;
            x <= x == x2 ? x1 : (comm == 3 || y == y1 || y == y2 ? x + 1 : (x == x1 ? x2 : x1));
            y <= x == x2 ? (y == y2 ? y : y + 1) : y;

            if (x == x2 && y == y2 || yof) t <= 0;

        end

        // -------------------------------------------------------------
        // LINE -[x2,y2],c
        // Дорисовать линию через задание новых x2,y2,cl
        // -------------------------------------------------------------

        8: if (b) begin

            a <= a + 1;
            b <= b - 1;
            {o,y2,x2} <= {i,o,y2,x2[15:8]};

        end else begin

            t <= 3;
            {x1,y1} <= {_x2,_y2};

        end

        // -------------------------------------------------------------
        // CIRCLE (x,y),r,c
        // -------------------------------------------------------------

        9: if (b) begin

            a <= a + 1;
            b <= b - 1;
            {o,y2,y1,x1} <= {i,o,y2,y1,x1[15:8]};

        end else begin

            t  <= 10;
            u  <= a;
            tn <= 0;
            dx <= 3 - 2*y2;
            x2 <= 0;

        end

        // Рисование точек на круге
        10: begin

            t <= 11;

            if (comm == CIRCLE_FILL) begin

                case (tn)
                0: begin tn <= 1; x <= x1 - x2; _x2 <= x1 + x2; y <= y1 + y2; end
                1: begin tn <= 2; x <= x1 - x2; _x2 <= x1 + x2; y <= y1 - y2; end
                2: begin tn <= 3; x <= x1 - y2; _x2 <= x1 + y2; y <= y1 + x2; end
                3: begin tn <= 0; x <= x1 - y2; _x2 <= x1 + y2; y <= y1 - x2; end
                endcase

            end else begin

                case (tn)
                0: begin tn <= 1; x <= x1 - x2; y <= y1 + y2; end
                1: begin tn <= 2; x <= x1 + x2; y <= y1 + y2; end
                2: begin tn <= 3; x <= x1 - x2; y <= y1 - y2; end
                3: begin tn <= 4; x <= x1 + x2; y <= y1 - y2; end
                4: begin tn <= 5; x <= x1 - y2; y <= y1 + x2; end
                5: begin tn <= 6; x <= x1 + y2; y <= y1 + x2; end
                6: begin tn <= 7; x <= x1 - y2; y <= y1 - x2; end
                7: begin tn <= 0; x <= x1 + y2; y <= y1 - x2; end
                endcase

            end

        end

        // Установка точки
        11: begin

            a <= ax;
            w <= wx;
            t <= comm == CIRCLE ? (tn ? 10 : 12) : (x < _x2 ? 11 : (tn ? 10 : 12));
            x <= x + 1;

        end

        // Следующая итерация
        12: if (x2 <= y2) begin

            t  <= 10;
            tn <= (comm == CIRCLE_FILL && cirx[15] ? 2 : 0);
            dx <= cirx[15] ? cirx : (cirx + 4*(1 - y2));
            x2 <= x2 + 1;
            y2 <= y2 - !cirx[15];

        end else t <= 0;

        // -------------------------------------------------------------
        // BITBLT (x,y,w,h)-(x1,y1,w,h)
        // Рисование текстуры на видеостранице
        // _x2[ 7:0] = x
        // _x2[15:8] = y
        // _y2[ 7:0] = w
        // _y2[15:8] = h
        // -------------------------------------------------------------

        // Считывание данных из памяти
        13: if (b) begin

            a <= a + 1;
            b <= b - 1;
            {o,y2,x2,y1,x1,_y2,_x2} <= {i,o,y2,x2,y1,x1,_y2,_x2[15:8]};

        end else begin

            t  <= 14;
            u  <= a;
            dx <= 0;
            dy <= 0;
            x2 <= x2 - 1;           // Ширина блока
            y2 <= y2 - 1;
            tx <= _x2[ 7:0];        // Старт текстуры X
            ty <= _x2[15:8];        // Старт текстуры Y

        end

        // Рисование пикселей в блоке
        14: begin

            a <= ax;
            w <= wx;
            o <= td;
            x <= x + 1;

            // Переход на новую линию
            if (x == x1 + x2) begin

                t  <= y == y1 + y2 ? 0 : 14;
                dx <= 0;
                x  <= x1;
                tx <= _x2[ 7:0];
                ty <= ty   + dyrs;
                dy <= dynx - dyrs*y2;
                y  <= y + 1;

            end else begin

                tx <= tx   + dxrs;
                dx <= dxnx - dxrs*x2;

            end

        end

    endcase

end

endmodule

