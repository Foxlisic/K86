module cpu(

    input wire         clock,
    output wire [19:0] pc,
    input wire  [47:0] instr,
    input wire  [15:0] data,         // input data
    output reg  [19:0] cp,           // address for data
    output reg         store,
    output reg  [15:0] write

);

assign pc = {cs,    4'h0} + ip;
assign cp = {e_seg, 4'h0} + e_adr;

reg [15:0] ip    = 0;
reg [11:0] flags = 0;

// ---------------------------------------------------------------------

wire [15:0] ax; wire [15:0] cx; wire [15:0] dx; wire [15:0] bx;
wire [15:0] sp; wire [15:0] bp; wire [15:0] si; wire [15:0] di;
wire [15:0] es; wire [15:0] cs; wire [15:0] ss; wire [15:0] ds;
wire [15:0] e_seg; wire [15:0] op1;
wire [15:0] e_adr; wire [15:0] op2;

reg       bitsel;               // 8/16 bit
reg       direct;               // {rm, reg} | {reg, rm}
reg [1:0] segment = 2'b11;      // текущий сегмент {es, cs, ss, ds}
reg       segpref = 0;          // есть префикс

regs REGFILE
(
    clock, instr,
    bitsel, direct, segment, segpref,
    ax, cx, dx, bx, sp, bp, si, di, es, cs, ss, ds,
    e_seg, e_adr,
    op1, op2
);

endmodule
