/*
 * Контроллер памяти только на быструю внутрисхемную память
 * CAS Latency = 2
 */

module mem_cntrl(

    input   wire        clk,
    input   wire [19:0] i_addr,         // Адрес
    output  wire [7:0]  o_data,         // Исходящие данные
    input   wire [7:0]  i_data,         // Входящие данные с CPU
    input   wire        i_write,        // Сигнал записи

    // Внешний интерфейс
    input   wire [7:0]  i_mem_data,     // Входящие данные из памяти
    output  reg  [7:0]  o_mem_data,     // Исходящие данные для записи
    output  reg         o_mem_write,    // Сигнал на запись в память
    output  reg  [19:0] o_mem_addr      // Адрес к внутрисхемной памяти

);

assign o_mem_addr  = i_addr;
assign o_data      = i_mem_data;
assign o_mem_data  = i_data;
assign o_mem_write = i_write;

always @(posedge clk) begin

    

end

endmodule
