module vidac
(
    input               clock,
    input               reset_n,
    output  reg [15:0]  address,
    input       [ 7:0]  in,
    output  reg [ 7:0]  out,
    output  reg         we,
    output  reg         bsy
);

endmodule
