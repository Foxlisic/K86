module cga
(
    // Опорная частота
    input   wire        clock_25,

    // Выходные данные
    output  reg  [3:0]  R,       // 4 бит на красный
    output  reg  [3:0]  G,       // 4 бит на зеленый
    output  reg  [3:0]  B,       // 4 бит на синий
    output  wire        HS,      // горизонтальная развертка
    output  wire        VS,      // вертикальная развертка

    // Доступ к памяти
    output  reg  [12:0] address, // 4k Видеоданные + 4k Шрифты 8x16
    input   wire [ 7:0] data,    // data = videoram[ address ]
    output  reg  [17:0] vga_address,
    input   wire [ 7:0] vga_data,
    output  reg  [ 7:0] vga_dac_address,
    input   wire [31:0] vga_dac_data,

    // Внешний интерфейс
    input   wire [10:0] cursor,          // Положение курсора от 0 до 2047
    input   wire [ 5:0] cursor_shape_lo, // Начало курсора
    input   wire [ 4:0] cursor_shape_hi,  // Конец

    // Видеорежи
    input   wire [ 1:0] videomode
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------

parameter
    hz_visible = 640, vt_visible = 480,
    hz_front   = 16,  vt_front   = 10,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 33,
    hz_whole   = 800, vt_whole   = 525;

assign HS = x  < (hz_back + hz_visible + hz_front); // NEG.
assign VS = y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
wire [10:0] X    = x - hz_back + 8; // X=[0..639]
wire [10:0] Xv   = x - hz_back + 4;
wire [ 9:0] Y    = y - vt_back;     // Y=[0..399]
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
// Текстовый видеоадаптер
// ---------------------------------------------------------------------
reg  [ 7:0] char;  reg [7:0] tchar; // Битовая маска
reg  [ 7:0] attr;  reg [7:0] tattr; // Атрибут
reg  [23:0] timer; // Мерцание курсора
reg         flash;

// Графический адаптер
// ---------------------------------------------------------------------
reg  [31:0] vga_color;

// ---------------------------------------------------------------------

// Текущая позиция курсора
wire [10:0] id = X[9:3] + (Y[8:4] * 80);

// Если появляется курсор [1..4000], то он использует нижние [cursor_shape_lo..cursor_shape_hi] строки у линии
wire shapec  = Y[3:0] >= cursor_shape_lo && Y[3:0] <= cursor_shape_hi;
wire maskbit = (char[ 3'h7 ^ X[2:0] ]) | (flash && (id == cursor+1) && shapec);

// Разбираем цветовую компоненту (нижние 4 бита отвечают за цвет символа)
wire [15:0] frcolor =

    attr[3:0] == 4'h0 ? 12'h111 : // 0 Черный (почти)
    attr[3:0] == 4'h1 ? 12'h008 : // 1 Синий (темный)
    attr[3:0] == 4'h2 ? 12'h080 : // 2 Зеленый (темный)
    attr[3:0] == 4'h3 ? 12'h088 : // 3 Бирюзовый (темный)
    attr[3:0] == 4'h4 ? 12'h800 : // 4 Красный (темный)
    attr[3:0] == 4'h5 ? 12'h808 : // 5 Фиолетовый (темный)
    attr[3:0] == 4'h6 ? 12'h880 : // 6 Коричневый
    attr[3:0] == 4'h7 ? 12'hccc : // 7 Серый -- тут что-то не то
    attr[3:0] == 4'h8 ? 12'h888 : // 8 Темно-серый
    attr[3:0] == 4'h9 ? 12'h00f : // 9 Синий (темный)
    attr[3:0] == 4'hA ? 12'h0f0 : // 10 Зеленый
    attr[3:0] == 4'hB ? 12'h0ff : // 11 Бирюзовый
    attr[3:0] == 4'hC ? 12'hf00 : // 12 Красный
    attr[3:0] == 4'hD ? 12'hfff : // 13 Фиолетовый
    attr[3:0] == 4'hE ? 12'hff0 : // 14 Желтый
                        12'hfff;  // 15 Белый

// Цветовая компонента фона (только 8 цветов)
wire [15:0] bgcolor =

    attr[6:4] == 3'd0 ? 12'h111 : // 0 Черный (почти)
    attr[6:4] == 3'd1 ? 12'h008 : // 1 Синий (темный)
    attr[6:4] == 3'd2 ? 12'h080 : // 2 Зеленый (темный)
    attr[6:4] == 3'd3 ? 12'h088 : // 3 Бирюзовый (темный)
    attr[6:4] == 3'd4 ? 12'h800 : // 4 Красный (темный)
    attr[6:4] == 3'd5 ? 12'h888 : // 5 Фиолетовый (темный)
    attr[6:4] == 3'd6 ? 12'h880 : // 6 Коричневый
                        12'hccc;  // 7 Серый

// Вывод видеосигнала
always @(posedge clock_25) begin

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (x >= hz_back && x < hz_visible + hz_back &&
        y >= vt_back && y < vt_visible + vt_back)
    begin
        case (videomode)
        // 80x25x16
        0: {R, G, B} <= maskbit ? (attr[7] & flash ? bgcolor : frcolor) : bgcolor;
        // 320x200x256
        2: {R, G, B} <= {vga_color[23:20], vga_color[15:12], vga_color[7:4]};
        endcase
    end
    else {R, G, B} <= 12'h000;

end

// Извлечение битовой маски и атрибутов для генерации шрифта
always @(posedge clock_25) begin

    // Видеорежимы
    case (videomode)

        0: // Текстовый режим
        case (X[2:0])

            // Запрос на ASCII-символ
            0: begin address <= {id, 1'b0}; end

            // Сохранить ASCII -> tchar, запрос на атрибут
            1: begin tchar <= data; address[0] <= 1'b1; end

            // Сохранить атрибут, запрос на знакогенератор
            2: begin tattr <= data; address <= {1'b1, tchar, Y[3:0]}; end

            // Сохранить значение битовой маски
            3: begin tchar <= data; end

            // Обновить данные для рисования символа
            7: begin attr  <= tattr; char <= tchar; end

        endcase

        2: // 320x200x256
        case (Xv[0])

            // Запрос адреса (последние 64 кб памяти)
            0: begin
                vga_address <= Xv[10:1] + Y[9:1]*320 + (256-64)*1024;
            end

            // Запрос цвета
            1: begin

                vga_dac_address <= vga_data;
                vga_color <= vga_dac_data;

            end

        endcase

    endcase

end


// Каждые 0,5 секунды перебрасывается регистр flash
always @(posedge clock_25) begin

    if (timer == 12500000) begin
        flash <= ~flash;
        timer <= 0;
    end else
        timer <= timer + 1;
end

endmodule
