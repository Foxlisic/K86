module sdram(

    /* Такты */
    input   wire        init_en,    /* =1 Производить первичную инициализацию памяти */
    input   wire        clock,      /* 100 Mhz */
    output  reg         kcpu,       /* Clock CPU */
    output  wire        kvga,       /* Clock VGA */

    /* Интерфейс */
    input   wire [31:0] A32,
    output  reg  [ 7:0] Do,         /* Do = Memory[A32] */
    input   wire [ 7:0] Di,         /* Запись в память  */
    input   wire        Dw,         /* Сигнал на запись */
    
    /* Адрес и данные */
    output  reg  [11:0] sdram_addr, /* Адрес */
    output  reg  [1:0]  sdram_bank, /* Банк  */
    inout   wire [15:0] sdram_dq,   /* Данные */
    
    /* Разрешения */
    output  reg         sdram_ldqm, /* Разрешение на запись в low */
    output  reg         sdram_udqm, /* Разрешение на запись в up */
    
    /* Команды */
    output  reg         sdram_ras,  /* Row Access Signal */
    output  reg         sdram_cas,  /* Column Access Signal */
    output  reg         sdram_we,   /* Write Enabled */
    
    /* VGA */
    output  wire [9:0]  vgax,       /* X=0..799 */  
    output  wire [9:0]  vgay,       /* X=0..524 */  
    output  reg  [9:0]  vgad,       /* Запись во внутрисхемную память (значения Do по адресу vgad) */
    output  reg         vgaw        /* Разрешение на запись */

);

/* В зависимости о того, есть ли сигнал на запись
   sdram_we = 0 -- sdram_dq доступен на запись
            = 1 -- для чтения  */
            
assign sdram_dq = sdram_we ? 16'hZZZZ : Di;

/* Положение курсора VGA 640x480; x = 0..799; y = 524 */
assign kvga     = x[1]; // 25 Мгц
assign vgax     = x[11:2];
assign vgay     = y;

// ---------------------------------------------------------------------

// Ожидание 100μs перед инициализацией
localparam iwaitc = 1250;

// Режимы работы (команды)       RCW
localparam cmd_loadmode     = 3'b000;   // Загрузка регистра MODE
localparam cmd_refresh      = 3'b001;   // Обновление
localparam cmd_precharge    = 3'b010;   // Перезаряд
localparam cmd_activate     = 3'b011;   // Активация столбца
localparam cmd_write        = 3'b100;   // Запись в память
localparam cmd_read         = 3'b101;   // Чтение из памяти
localparam cmd_burst_term   = 3'b110;   // Завершение Burst
localparam cmd_nop          = 3'b111;   // Нет операции

initial begin {kcpu, sdram_ldqm, sdram_udqm} = 3'b000; end

// ---------------------------------------------------------------------

reg [11:0] init         = 1'b0;
reg [1:0]  div          = 2'b00;
reg        initlock     = 1'b1;
reg [2:0]  cinit        = 3'b111;   // Команды для инициализации
reg [2:0]  command      = 3'b111;   // Команды в нормальном режиме

reg [11:0] x            = 1'b0;     // = [0..3199] 3200T
reg [11:0] y            = 1'b0;     // = [0..524]  525T
reg [11:0] init_addr    = 1'b0;     // Для Init

reg [11:0] address      = 1'b0;     // Операционный режим
reg [ 1:0] bank         = 2'b00; 

/* Распределение для приема команд */
// ---------------------------------------------------------------------
always @* begin

    if (initlock && init_en) 
        {sdram_ras, sdram_cas, sdram_we, sdram_addr, sdram_bank} = {cinit, init_addr, 2'b00};
    else
        {sdram_ras, sdram_cas, sdram_we, sdram_addr, sdram_bank} = {command, address, bank};

    Do = sdram_dq;
    
end
// ---------------------------------------------------------------------

// Текущий адрес видеопамяти
reg        bankoff   = 1'b1;  /* Доступ запрещен к памяти */
reg [17:0] video_adr = 1'b0;  /* 256 Kb */  
reg [ 2:0] repeats   = 1'b0;  /* 64 байта x 5 раз = 320 байт */
reg [ 8:0] inc       = 1'b0;  /* 0..319 */
reg [ 7:0] col       = 1'b0;  /* 0..73 (1 цикл) */

always @(posedge clock) begin

    /* Блок инициализации SDRAM */
    if (initlock && init_en) begin
    
        /* 25 Мгц */
        if (div == 2'b00) begin
        
            case (init)
            
                /* PRECHARGE */ (iwaitc + 1):  {cinit, init_addr} <= {cmd_precharge, 12'b0100_0000_0000};
                /* REFRESH   */ (iwaitc + 4):   cinit             <= cmd_refresh;
                /* LOADMODE  */ (iwaitc + 18): {cinit, init_addr} <= {cmd_loadmode,  12'b0000_0010_0111};
                /* START     */ (iwaitc + 21):  initlock          <= 1'b0;
                /* NOP       */ default: begin  cinit             <= cmd_nop; init_addr <= 1'b0; end
            
            endcase
                        
            init <= init + 1'b1;

        end
        
        div <= div + 1'b1;

    end
    
    /* Один кадр VGA (3200 x 525 -> 800 x 525) x 60 = 100 Mhz */    
    else begin

        x <= (x == 3199 ? 0 : x + 1);    
        y <= (y == 524  ? 0 : (x == 3199 ? y + 1 : y));
        
        /* Перезаряд банков в начале строки */
        if (x == 0) begin
        
            command  <= cmd_precharge;
            address  <= 12'b0100_0000_0000;
            col      <= 1'b0;    
            vgaw     <= 1'b0;
            inc      <= -2;
            repeats  <= 3'h5;
            
        end
        
        /* Видеоадаптер. Два раза Precharge. */
        else if (x >= 3 && (x < 320 + 64) && y < 480) begin
        
            if (repeats) begin
                
                     if (col == 4'h0) begin col <= col + 1'b1; command <= cmd_precharge; address <= 12'b0100_0000_0000; end
                else if (col == 4'h3) begin col <= col + 1'b1; command <= cmd_activate;  address <= video_adr[17:8]; bank <= 3'b11; end
                else if (col  < 4'h7) begin col <= col + 1'b1; command <= cmd_nop; end
                
                // Завершение 64-байтного кадра (всего 5 x 64 = 320)
                else if (col == 7'h49) begin 
                
                    inc         <= inc - 2; 
                    video_adr   <= video_adr - 2;
                    repeats     <= repeats - 1;
                    col         <= 1'b0; 
                    vgaw        <= 1'b0; 
                    
                end

                // Основной цикл
                else if (col >= 4'h7)  begin
                    
                    command   <= cmd_read;      
                    address   <= {4'b0100, video_adr[7:0]}; 

                    vgad      <= {y[0], inc[8:0]};
                    vgaw      <= (col >= 4'h9);

                    col       <= col + 1'b1;
                    inc       <= inc + 1'b1;
                    video_adr <= video_adr + 1'b1;
                    
                end
            
            end
                         
        end
        
        /* Сброс видеоадреса для будущего */
        else if (y == 480) begin video_adr <= 1'b0; end

    end

end

endmodule
