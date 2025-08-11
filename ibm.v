/* verilator lint_off WIDTH */
module ibm
(
    // Опорная частота 25 мгц
    input   wire        clock,
    // Выходные данные
    output  reg  [3:0]  r,       // 4 бит на красный
    output  reg  [3:0]  g,       // 4 бит на зеленый
    output  reg  [3:0]  b,       // 4 бит на синий
    output              hs,      // горизонтальная развертка
    output              vs,      // вертикальная развертка
    // Доступ к памяти
    output  reg  [12:0] a,
    input        [ 7:0] i,
    // Внешний интерфейс
    input        [10:0] cursor   // Положение курсора от 0 до 2047
);
// -----------------------------------------------------------------------------
localparam
    hz_visible = 10'd640, vt_visible = 9'd400,
    hz_front   = 10'd16,  vt_front   = 9'd12,
    hz_sync    = 10'd96,  vt_sync    = 9'd2,
    hz_back    = 10'd48,  vt_back    = 9'd35,
    hz_whole   = 10'd800, vt_whole   = 9'd449;
// -----------------------------------------------------------------------------
assign hs = x < (hz_back + hz_visible + hz_front);
assign vs = y < (vt_back + vt_visible + vt_front);
// -----------------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
wire        vh   = x >= hz_back && x < hz_visible + hz_back;
wire        vv   = y >= vt_back && y < vt_visible + vt_back;
// -----------------------------------------------------------------------------
reg  [10:0] x, y;
wire [10:0] X = x - hz_back + 4'h8; // X=[0..639]
wire [10:0] Y = y - vt_back;        // Y=[0..399]
// -----------------------------------------------------------------------------
reg  [23:0] t;
reg  [ 7:0] attr, char, d;
reg         flash;
// -----------------------------------------------------------------------------
wire [10:0] id  = X[9:3] + (Y[8:4] * 8'd80);
wire        hl  = char[~X[2:0]] || (flash && (id == cursor + 1) && Y[3:0] >= 4'd14);
wire [ 3:0] kin = hl ? attr[3:0] : attr[7:4];
// -----------------------------------------------------------------------------
wire [11:0] color =
    kin == 4'h0 ? 12'h111 : kin == 4'h8 ? 12'h888 :
    kin == 4'h1 ? 12'h008 : kin == 4'h9 ? 12'h00F :
    kin == 4'h2 ? 12'h080 : kin == 4'hA ? 12'h0F0 :
    kin == 4'h3 ? 12'h088 : kin == 4'hB ? 12'h0FF :
    kin == 4'h4 ? 12'h800 : kin == 4'hC ? 12'hF00 :
    kin == 4'h5 ? 12'h808 : kin == 4'hD ? 12'hF0F :
    kin == 4'h6 ? 12'h880 : kin == 4'hE ? 12'hFF0 :
    kin == 4'h7 ? 12'hCCC :               12'hFFF;
// -----------------------------------------------------------------------------
always @(posedge clock) begin

    // Кадровая развертка
    x <= xmax ?         1'b0 : x + 1'b1;
    y <= xmax ? (ymax ? 1'b0 : y + 1'b1) : y;

    // Вывод окна видеоадаптера
    {r, g, b} <= (vh && vv) ? color : 12'h000;

    // Извлечение текущей маски
    case (X[2:0])

        0: begin a <= {1'b0, id[10:0], 1'b0}; end
        2: begin a <= {1'b1, i, Y[3:0]}; end
        4: begin a <= {1'b0, id[10:0], 1'b1}; d <= i; end
        7: begin {attr, char} <= {i,d}; end

    endcase

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (t == 24'd12500000) begin t <= 1'b0; flash <= ~flash; end else t <= t + 1'b1;

end

endmodule
