/* verilator lint_off WIDTH */

module video
(
    // --------------------------
    input               clock,
    output  reg [3:0]   r,
    output  reg [3:0]   g,
    output  reg [3:0]   b,
    output              hs,
    output              vs,
    // --------------------------
    input               videomode,
    input       [11:0]  cursor,
    output  reg [15:0]  video_a,
    input       [ 7:0]  video_q,
    output  reg [11:0]  font_a,
    input       [ 7:0]  font_q
);
// ---------------------------------------------------------------------
parameter
    hz_back    = 48,  vt_back    = 33,
    hz_visible = 640, vt_visible = 480,
    hz_front   = 16,  vt_front   = 10,
    hz_sync    = 96,  vt_sync    = 2,
    hz_whole   = 800, vt_whole   = 525;
// ---------------------------------------------------------------------
assign hs = X  < (hz_back + hz_visible + hz_front); // NEG.
assign vs = Y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire xmax = (X == hz_whole - 1);
wire ymax = (Y == vt_whole - 1);
wire disp = (X >= hz_back && X < hz_visible + hz_back) &&
            (Y >= vt_back && Y < vt_visible + vt_back);
// ---------------------------------------------------------------------
reg  [10:0] X  = 0;
reg  [10:0] Y  = 0;
wire [ 9:0] x  = X - hz_back;    // X=[0..639]
wire [ 8:0] y  = Y - vt_back;    // Y=[0..478] Одна линия не видна внизу
wire [ 9:0] xc = x + 8;
// ---------------------------------------------------------------------
reg  [23:0] timer;
reg  [ 7:0] attr, char;
reg         flash;
wire [11:0] at   = xc[9:3] + y[8:4]*80;
wire        mask = char[~x[2:0]] || (y[3:0] >= 14 && at == cursor+1 && flash);
wire [ 3:0] clr  = mask ? attr[3:0] : attr[6:4];
wire [11:0] clrt = clr == 7 ? 12'hCCC : {
    clr[2], {3{clr[3]}},
    clr[1], {3{clr[3]}},
    clr[0], {3{clr[3]}},
};

// ---------------------------------------------------------------------

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;

    // Вывод окна видеоадаптера
    if (disp)
    begin
         // {r, g, b} <= maskbit ? (attr[7] & flash ? bgcolor : frcolor) : bgcolor;
         {r, g, b} <= clrt;
    end
    else {r, g, b} <= 12'h000;

    // ----
    if (videomode == 0) begin

        case (x[2:0])

            5: begin video_a    <= 16'h8000 + {at, 1'b0}; end
            6: begin video_a[0] <= 1'b1;
                     font_a     <= {video_q, y[3:0]}; end
            7: begin attr       <= video_q;
                     char       <= font_q; end

        endcase

    end

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (timer == 12500000) begin flash <= ~flash; timer <= 0; end else timer <= timer + 1;

end

endmodule
