module core
(
    input               clock,
    input               ce,
    input               reset_n,
    output      [19:0]  address,
    input       [ 7:0]  in,
    output reg  [ 7:0]  out,
    output reg          we
);

// Вычисление адреса в памяти
assign address = cp ? {seg, 4'h0} + ea : {cs, 4'h0} + ip;

// РЕГИСТРЫ
// ---------------------------------------------------------------------
reg [15:0]  ax, bx, cx, dx, sp, bp, si, di;
reg [15:0]  es, cs, ss, ds;
reg [15:0]  ip;
reg [11:0]  flag = 12'b0000_0000_0010;
//                    ODIT SZ A  P C

// СИСТЕМНЫЕ РЕГИСТРЫ
// ---------------------------------------------------------------------
reg         cp;
reg [15:0]  ea, seg;

// ЛОГИКА РАБОТЫ ПРОЦЕССОРА
// ---------------------------------------------------------------------

always @(posedge clock)
// Процесс сброса
if (reset_n == 1'b0) begin

    cp <= 0;
    cs <= 16'hF000;
    ip <= 16'hFFF0;

// Процессор должен быть активирован
end else if (ce) begin



end

endmodule
