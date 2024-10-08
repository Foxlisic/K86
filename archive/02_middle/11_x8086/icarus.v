`timescale 10ns / 1ns

module main;

// Частота процессора 25 Мгц
// ---------------------------------------------------------------------

reg         clk;
always #0.5 clk         = ~clk;

initial begin clk = 0; #2000 $finish; end
initial begin $dumpfile("result.vcd"); $dumpvars(0, main); end

// Декларация шины
// ---------------------------------------------------------------------

wire [19:0] o_addr;
wire [19:0] o_ip;
wire [19:0] o_mem_addr;
wire [ 7:0] i_data;
wire [ 7:0] o_data;
wire        o_write;
reg  [ 7:0] i_mem_data;
reg  [ 7:0] o_mem_data;
wire        o_mem_write;

reg [1:0] mhz = 2'b00;
always @(negedge clk) mhz <= mhz + 1'b1;

// Контроллер SDRAM
// ---------------------------------------------------------------------

// FC000-FFFFF Память BIOS ROM (16K) 
// 00000-01FFF Память BIOS RAM (8K)  
// ---------------------------------------------------------------------

mem_cntrl InternalMemoryController(

    clk,
    o_addr,
    i_data,
    o_data,
    o_write,
    
    // К внутрисхемной памяти
    i_mem_data,
    o_mem_data,
    o_mem_write,
    o_mem_addr
        
);

// 1 Мб общей памяти
reg [7:0] allmemory[1048575:0];
reg [7:0] casl2;

initial begin $readmemh("rom.hex", allmemory, 20'hFC000); end
initial begin $readmemh("ram.hex", allmemory, 20'h00000); end

// Интерфейс памяти 
always @(posedge clk) begin

    // BIOS RAM; ROM BIOS; TEXTMODE VIDEO
    if ((o_mem_addr < 20'h02000) || (o_mem_addr >= 20'hFC000) || (o_mem_addr >= 20'hB8000 && o_mem_addr <= 20'hB92C0))
    begin
    
        /* ТАКТ 1 */ i_mem_data  <= casl2;
        /* ТАКТ 2 */      casl2  <= allmemory[ o_mem_addr[19:0] ];
        
        if (o_mem_write) begin
        
            allmemory[ o_mem_addr[19:0] ] <= o_mem_data;
        
        end
    
    end else begin
        i_mem_data <= 16'hFFFF;
    end

end

// Процессор 
// ---------------------------------------------------------------------

cpu CPUx8086(

    mhz[1],
    1'b0,
    o_addr,
    i_data,
    o_data,
    o_write
    
);

// Видеоадаптер 80x30 (4800 байт) + шрифты 8x16 (4096 байт)
// ---------------------------------------------------------------------

// Загрузчик UART (Input)
// ---------------------------------------------------------------------

endmodule
