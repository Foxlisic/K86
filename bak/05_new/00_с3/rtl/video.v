module video
(
    input               clock,
    output  reg         r,
    output  reg         g,
    output  reg         b,
    output              hs,
    output              vs,
    // ---
    output reg  [11:0]  ram_a,
    output reg  [11:0]  rom_a,
    input       [ 7:0]  ram_i,
    input       [ 7:0]  rom_i,
    input       [10:0]  cursor
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной и вертикальной развертки
parameter
//  Visible     Back        Sync        Front       Whole
    hzv =  640, hzb =   48, hzs =   96, hzf =   16, hzw =  800,
    vtv =  400, vtb =   35, vts =    2, vtf =   12, vtw =  449;
// ---------------------------------------------------------------------
assign hs = x < (hzb + hzv + hzf);
assign vs = y < (vtb + vtv + vtf);
// ---------------------------------------------------------------------
reg  [ 9:0] x = 0;
reg  [ 9:0] y = 0;
wire [ 9:0] rx = x - hzb + 8;
wire [ 9:0] ry = y - vtb;
// ---------------------------------------------------------------------
wire xmax = (x == hzw - 1);
wire ymax = (y == vtw - 1);
wire show = (x >= hzb && x < hzb + hzv) && (y >= vtb && y < vtb + vtv);
// ---------------------------------------------------------------------
reg         flash;
reg  [ 7:0] mask, attr;
reg  [22:0] incr;
wire [10:0] curr  = rx[9:3] + ry[9:4]*80;
wire        cbit  = mask[ ~rx[2:0] ];
wire        cur   = flash && (curr == cursor+1 && ry[3:0] >= 14);
wire        blink = (flash & attr[7]) || (attr[7] == 1'b0);

always @(posedge clock) begin

    // Черный цвет по краям
    {r, b, g} <= 3'b000;

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Чтение следующего символа
    case (rx[2:0])
    5: begin ram_a <= 2*curr; end
    6: begin rom_a <= {ram_i, ry[3:0]};
             ram_a <= ram_a + 1; end
    7: begin {mask, attr} <= {rom_i, ram_i}; end
    endcase

    // Вывод окна видеоадаптера
    if (show) begin {r,g,b} <= ((cbit && blink) || cur ? attr[2:0] : attr[6:4]); end

    // Мерцающий курсор
    incr  <= (incr == 6250000) ? 0 : incr+1;
    flash <= !incr ? ~flash : flash;

end

endmodule
