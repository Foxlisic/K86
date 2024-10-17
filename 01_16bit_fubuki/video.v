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
    input               page,               // Видеостраница графического режима
    input       [11:0]  cursor,
    output  reg [16:0]  video_a,
    input       [ 7:0]  video_q,
    output  reg [11:0]  font_a,
    input       [ 7:0]  font_q,
    output  reg [ 7:0]  dac_a,
    input       [11:0]  dac_q,
    output              vretrace
);
// ---------------------------------------------------------------------
parameter
    hz_back    = 48,  vt_back    = 35,      // 33
    hz_visible = 640, vt_visible = 400,     // 480
    hz_front   = 16,  vt_front   = 12,      // 10
    hz_sync    = 96,  vt_sync    = 2,       // 2
    hz_whole   = 800, vt_whole   = 449;     // 525
// ---------------------------------------------------------------------
assign hs = X  < (hz_back + hz_visible + hz_front); // NEG.
assign vs = Y >= (vt_back + vt_visible + vt_front); // POS.
assign vretrace = (X == 0) && (Y == vt_back + vt_visible);
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
reg         flash;
reg  [23:0] timer;
reg  [ 7:0] char;
reg  [11:0] fore, back, _fore;
wire [11:0] at   = xc[9:3] + y[8:4]*80;
wire        mask = char[~x[2:0]] || (y[3:0] >= 14 && at == cursor+1 && flash);

// ---------------------------------------------------------------------

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;

    // Вывод окна видеоадаптера
    {r, g, b} <= disp ? (videomode || mask ? fore : back) : 12'h000;

    // 320x200
    if (videomode) begin

        case (x[0])
        0: begin dac_a <= video_q; end
        1: begin fore  <= dac_q; video_a <= 320*y[8:1] + ((X - hz_back + 4) >> 1) + {page, 16'h0000}; end
        endcase

    end
    // 80x25
    else begin

        case (x[2:0])

            3: begin video_a <= 17'h18000 + {at, 1'b0}; end
            4: begin font_a  <= {video_q, y[3:0]}; video_a[0] <= 1'b1; end
            5: begin dac_a   <= video_q[3:0]; end
            6: begin dac_a   <= video_q[7:4]; _fore <= dac_q; end
            7: begin back    <= dac_q;
                     fore    <= _fore;
                     char    <= font_q; end

        endcase

    end

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (timer == 12500000) begin flash <= ~flash; timer <= 0; end else timer <= timer + 1;

end

endmodule
