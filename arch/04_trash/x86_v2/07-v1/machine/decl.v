initial begin

    o_data = 8'h00;
    we     = 1'b0;

end

// -----------------------------------------------------------------------------
localparam  
    P_INIT          = 0,
    P_OPCODE        = 1,
    // Считывание modrm
    P_MODRM         = 2,
    P_MODRM_DISP    = 3,
    P_MODRM_DISP_HI = 4,
    // Считывание из памяти операнда
    P_GETMEMOP      = 5, 
    P_GETMEMOP2     = 6,
    P_GETMEMOP3     = 7,
    P_GETMEMOP4     = 8,   
    // Исполнение и процедуры
    P_EXEC          = 9;

// -----------------------------------------------------------------------------

// https://ru.wikipedia.org/wiki/Регистр_флагов
reg [31:0]  eip    = 32'h0000_0000;
reg [15:0]  eflags = 16'h0000;

// FE DC BA98 76543210
// 0N IO ODIT SZ0A0P1C
//  T PL

// 8 регистров общего назначения
reg [31:0]  eax = 32'h4433_2211; // 0
reg [31:0]  ecx = 32'h8877_6655; // 1
reg [31:0]  edx = 32'hCCBB_AA99; // 2
reg [31:0]  ebx = 32'h12FF_FF00; // 3
reg [31:0]  esp = 32'h1235_4567; // 4
reg [31:0]  ebp = 32'h8432_2367; // 5
reg [31:0]  esi = 32'h6234_1234; // 6
reg [31:0]  edi = 32'h6234_0003; // 7

// 6 сегментных регистров (селекторы)
reg [15:0]  es = 16'h1234;
reg [15:0]  cs = 16'h0000;
reg [15:0]  ss = 16'h4321;
reg [15:0]  ds = 16'h0000;
reg [15:0]  fs = 16'hAABB;
reg [15:0]  gs = 16'hFABB;

// -----------------------------------------------------------------------------

reg [4:0]   phase       = 1'b0;
reg [7:0]   modrm       = 1'b0;
reg [7:0]   sib         = 1'b0;
reg [8:0]   opcode      = 1'b0;
reg         override    = 1'b0;             // Замещение текущего сегмента DS:
reg [15:0]  segment     = 16'h0000;
reg [31:0]  ea          = 32'h00000000;
reg [ 1:0]  rep         = 2'b00;            // 0-ничего, 2-repnz, 3-repz
reg         opsize      = 1'b0;
reg         adsize      = 1'b0;
reg         dir         = 1'b0;             // Направление операндов 0=r/m,r; 1=r,r/m
reg         size        = 1'b0;             // =0 8 бит; =1 16/32 бита
reg [ 3:0]  alu         = 4'h0;             // Номер функции АЛУ
reg [31:0]  op1         = 32'h0;
reg [31:0]  op2         = 32'h0;
reg         sel         = 1'b0;             // =0 cs:eip; =1 segment:ea
