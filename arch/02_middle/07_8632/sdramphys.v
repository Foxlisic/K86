module sdramphys(

    input   wire         clock,

    /* Адрес и данные */
    input   wire [11:0]  sdram_addr, /* Адрес */
    input   wire [1:0]   sdram_bank, /* Банк  */
    inout   wire [15:0]  sdram_dq,   /* Данные */
    
    /* Разрешения */
    input   wire         sdram_ldqm, /* Разрешение на запись в low */
    input   wire         sdram_udqm, /* Разрешение на запись в up */
    
    /* Команды */
    input   wire         sdram_ras,  /* Row Access Signal */
    input   wire         sdram_cas,  /* Column Access Signal */
    input   wire         sdram_we    /* Write Enabled */

);

/* Если идет запись, то на DQ будет Z, при чтении - читаем DQ */
assign sdram_dq = sdram_we ? dq : 16'hZZZZ;

// Режимы работы (команды)       RCW
localparam cmd_loadmode     = 3'b000;   // Загрузка регистра MODE
localparam cmd_refresh      = 3'b001;   // Обновление
localparam cmd_precharge    = 3'b010;   // Перезаряд
localparam cmd_activate     = 3'b011;   // Активация столбца
localparam cmd_write        = 3'b100;   // Запись в память
localparam cmd_read         = 3'b101;   // Чтение из памяти
localparam cmd_burst_term   = 3'b110;   // Завершение Burst
localparam cmd_nop          = 3'b111;   // Нет операции

// ---
reg [11:0] mode_register = 12'h000;

// Текущее положение
reg [ 1:0] bank = 2'b00;
reg [11:0] row  = 12'h000;
reg [15:0] data_read = 16'h0000;
reg [ 1:0] latency = 2'b00;

// 4 Mb памяти
reg [15:0] STORAGE[4194304];

/* Для cmd_read */
wire [25:0] raddr = {bank[1:0], row[11:0], sdram_addr[7:0]};
wire [15:0] rdata = STORAGE[ raddr ];

/* Выходные данные */
reg [15:0]  dq = 16'h0000;

// ---
initial begin 

    STORAGE[ 26'h300000 ] = 16'h115A;
    STORAGE[ 26'h300001 ] = 16'h1123;
    STORAGE[ 26'h300041 ] = 16'h1145;

end
// ---

always @(posedge clock) begin

    /* Эмуляция задержки при чтении */
    dq <= data_read;

    /* Эмулятор задержки сигнала активации или precharge */
    if (latency) latency <= latency - 1'b1;
    else
    case ({sdram_ras, sdram_cas, sdram_we})
    
        /* Загрузка режима работы */
        cmd_loadmode: begin mode_register <= sdram_addr; end
        
        /* Перезаряд требует времени */
        cmd_precharge: latency <= 2'h2;
        
        /* Активация */
        cmd_activate: begin latency <= 2'h2; row <= sdram_addr; bank <= sdram_bank; end
        
        /* Чтение данных */
        cmd_read: begin data_read <= {sdram_udqm ? 8'hZ : rdata[15:8], 
                                      sdram_ldqm ? 8'hZ : rdata[7:0]}; end
                                      
        // .. запись в память
        cmd_write: begin STORAGE[ raddr ] <= sdram_dq; end
        
    endcase
    
end

endmodule
