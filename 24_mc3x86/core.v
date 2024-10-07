module core
(
    input               clock,
    input               reset_n,
    input               locked,
    output      [15:0]  address,
    input       [7:0]   in,
    output  reg [7:0]   out,
    output  reg         we
);


initial begin out = 8'h00; we = 1'b0; end

assign address = 16'h0000;

// ---------------------------------------------------------------------
localparam

    init        = 0,
    modrm_fetch = 1,
    modrm_d8    = 2,
    modrm_d16   = 3,
    modrm_d16h  = 4,
    modrm_op    = 5,
    modrm_oph   = 6,
    exec        = 7;

// Регистры
// ---------------------------------------------------------------------
reg [15:0]  ax = 16'h0000; reg [15:0]  sp = 16'h0000;
reg [15:0]  cx = 16'h0000; reg [15:0]  bp = 16'h0000;
reg [15:0]  dx = 16'h0000; reg [15:0]  si = 16'h0000;
reg [15:0]  bx = 16'h0000; reg [15:0]  di = 16'h0000;
reg [15:0]  ip = 16'h0000;
reg [11:0]  flags = 12'b0000_0000_0010;
//                      ODIT SZ A  P C
// ---------------------------------------------------------------------

reg [3:0]   n       = 1'b0;
reg         sw      = 1'b0;
reg [15:0]  ea      = 16'h0000;
reg         size    = 1'b0;
reg         dir     = 1'b0;
reg [2:0]   alu     = 3'b000;
reg [7:0]   opcode  = 8'h00;
reg [7:0]   modrm   = 8'h00;
reg [15:0]  op1     = 16'h0000;
reg [15:0]  op2     = 16'h0000;

// ---------------------------------------------------------------------
always @(posedge clock)
if (locked)
if (reset_n == 1'b0) begin ip <= 16'h0000; n <= 1'b0; sw <= 1'b0; end
else case (n)

    // Считывание опкода
    init: begin

        ip     <= ip + 1'b1;
        size   <= in[0];
        dir    <= in[1];
        opcode <= in;

        casex (in)

        // Никакие префиксы мы не используем
        8'h0F, 8'hF0,
        8'h26, 8'h2E, 8'h36, 8'h3E,
        8'h64, 8'h65, 8'h66, 8'h67: begin /* SKIP */ end

        // ALU 8
        8'b00xxx0xx: begin alu <= in[5:3]; n <= modrm; end

        endcase

    end

    // Считывание байта MODRM
    modrm_fetch: begin

        modrm <= in;
        ip    <= ip + 1'b1;

        // Операнд 1
        case (dir ? in[5:3] : in[2:0])
        3'h0: op1 <= size ? ax : ax[ 7:0];
        3'h1: op1 <= size ? cx : cx[ 7:0];
        3'h2: op1 <= size ? dx : dx[ 7:0];
        3'h3: op1 <= size ? bx : bx[ 7:0];
        3'h4: op1 <= size ? sp : ax[15:8];
        3'h5: op1 <= size ? bp : cx[15:8];
        3'h6: op1 <= size ? si : dx[15:8];
        3'h7: op1 <= size ? di : bx[15:8];
        endcase

        // Операнд 2
        case (dir ? in[2:0] : in[5:3])
        3'h0: op2 <= size ? ax : ax[ 7:0];
        3'h1: op2 <= size ? cx : cx[ 7:0];
        3'h2: op2 <= size ? dx : dx[ 7:0];
        3'h3: op2 <= size ? bx : bx[ 7:0];
        3'h4: op2 <= size ? sp : ax[15:8];
        3'h5: op2 <= size ? bp : cx[15:8];
        3'h6: op2 <= size ? si : dx[15:8];
        3'h7: op2 <= size ? di : bx[15:8];
        endcase

        // Вычисление эффективного адреса
        case (in[2:0])
        3'h0: ea <= bx + si;
        3'h1: ea <= bx + di;
        3'h2: ea <= bp + si;
        3'h3: ea <= bp + di;
        3'h4: ea <= si;
        3'h5: ea <= di;
        3'h6: ea <= ^in[7:6] ? bp : 16'h0000;
        3'h7: ea <= bx;
        endcase

        case (in[7:6])
        2'b00:
            if (in[2:0] == 3'b110) n <= modrm_d16;
            else begin sw <= 1'b1; n <= modrm_op; end
        2'b01:
            n <= modrm_d8;
        2'b10:
            n <= modrm_d16;
        2'b11:
            n <= exec;
        endcase

    end

endcase

endmodule
