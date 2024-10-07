/* verilator lint_off WIDTH */

module gpu
(
    // Опорная частота 25 мгц
    input   wire        clock,

    // Выходные данные
    output  reg  [3:0]  r,       // 4 бит на красный
    output  reg  [3:0]  g,       // 4 бит на зеленый
    output  reg  [3:0]  b,       // 4 бит на синий
    output  wire        hs,      // горизонтальная развертка
    output  wire        vs,      // вертикальная развертка

    // Доступ к памяти
    output  reg  [11:0] char_address,
    output  reg  [11:0] font_address,
    input   wire [ 7:0] char_data,
    input   wire [ 7:0] font_data,

    // Внешний интерфейс
    input   wire [10:0] cursor   // Положение курсора от 0 до 2047
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------

localparam

    hz_visible = 640, vt_visible = 400,
    hz_front   = 16,  vt_front   = 12,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 35,
    hz_whole   = 800, vt_whole   = 449;

assign hs = x  < (hz_back + hz_visible + hz_front); // NEG.
assign vs = y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
wire        cwin = (x >= hz_back && x < hz_visible + hz_back && y >= vt_back && y < vt_visible + vt_back);
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
wire [10:0] X    = x - hz_back + 8; // X=[0..639]
wire [ 9:0] Y    = y - vt_back;     // Y=[0..399]
// ---------------------------------------------------------------------
reg         flash;
reg  [ 7:0] attr;
reg  [ 7:0] char;
reg  [23:0] timer;
// ---------------------------------------------------------------------

wire [10:0] id = X[9:3] + (Y[8:4] * 80);
wire        maskbit = (char[ ~X[2:0] ]) | (!flash && (id == cursor + 1) && Y[3:0] >= 14);
wire [ 3:0] kcolor = maskbit ? (attr[7] & flash ? attr[6:4] : attr[3:0]) : attr[6:4];
wire [15:0] color =

    kcolor == 4'h0 ? 12'h111 : // 0 Черный (почти)
    kcolor == 4'h1 ? 12'h008 : // 1 Синий (темный)
    kcolor == 4'h2 ? 12'h080 : // 2 Зеленый (темный)
    kcolor == 4'h3 ? 12'h088 : // 3 Бирюзовый (темный)
    kcolor == 4'h4 ? 12'h800 : // 4 Красный (темный)
    kcolor == 4'h5 ? 12'h808 : // 5 Фиолетовый (темный)
    kcolor == 4'h6 ? 12'h880 : // 6 Коричневый
    kcolor == 4'h7 ? 12'hCCC : // 7 Серый -- тут что-то не то
    kcolor == 4'h8 ? 12'h888 : // 8 Темно-серый
    kcolor == 4'h9 ? 12'h00F : // 9 Синий (темный)
    kcolor == 4'hA ? 12'h0F0 : // 10 Зеленый
    kcolor == 4'hB ? 12'h0FF : // 11 Бирюзовый
    kcolor == 4'hC ? 12'hF00 : // 12 Красный
    kcolor == 4'hD ? 12'hF0F : // 13 Фиолетовый
    kcolor == 4'hE ? 12'hFF0 : // 14 Желтый
                     12'hFFF;  // 15 Белый

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    {r, g, b} <= cwin ? color : 12'h000;

    // Извлечение текущей маски
    case (X[2:0])

        0: begin char_address <= {id[10:0], 1'b0}; end
        2: begin font_address <= {char_data, Y[3:0]}; end
        4: begin char_address <= {id[10:0], 1'b1}; end
        7: begin {attr, char} <= {char_data, font_data}; end

    endcase

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (timer == 12499999) begin
        timer <= 0;
        flash <= ~flash;
    end else begin
        timer <= timer + 1;
    end

end

endmodule
