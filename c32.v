module c32
(
    input               clock,
    input               reset_n,
    input               ce,
    output      [31:0]  a,
    input       [31:0]  i,
    output  reg [31:0]  o,
    output  reg         w
);

// -----------------------------------------------------------------------------
`include "c32_decl.v"
`include "c32_reg.v"
`include "c32_alu.v"
`include "c32_wire.v"
// -----------------------------------------------------------------------------

always @(posedge clock)
if (reset_n == 1'b0) begin

    t   <= 0;
    w   <= 0;
    cp  <= 0;
    eip <= 0;

end else if (ce) begin

    w <= 0;

    case (t)
    // Этап прочтения ИНСТРУКЦИИ из памяти
    T_LOAD: begin end
    endcase

end

endmodule
