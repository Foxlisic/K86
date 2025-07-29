// Выбор текущего адреса
assign address = bus ? {segment, 4'h0} + cursor : {cs, 4'h0} + ip;

// Инициализация
initial begin dout = 1'b0; we = 1'b0; end

// Регистры общего назначения
reg  [15:0] ax = 16'h0000;
reg  [15:0] cx = 16'h0000;
reg  [15:0] dx = 16'h0000;
reg  [15:0] bx = 16'h0000;
reg  [15:0] sp = 16'h0000;
reg  [15:0] bp = 16'h0000;
reg  [15:0] si = 16'h0000;
reg  [15:0] di = 16'h0000;

// Сегментные регистры
reg  [15:0] es = 16'h0000;
reg  [15:0] cs = 16'h0000;
reg  [15:0] ss = 16'h0000;
reg  [15:0] ds = 16'h0000;

// Состояние процессора
//                            odit sz a p c
reg  [11:0] flags       = 12'b0000_00000010;
reg  [15:0] ip          = 16'h0000;

// Текущее положение микрокода
reg  [ 4:0] col         = 1'b0;     // Процедура
reg  [ 3:0] row         = 1'b0;     // Строка в процедуре
reg  [ 3:0] tick        = 1'b0;     // Строка в M_exec

// Сохраненные данные
reg  [ 7:0] opcode      = 8'h00;
reg  [ 7:0] modrm       = 8'h00;
reg         bitsize     = 1'b0;     // =9 8 bit; =1 16 bit
reg         dirmode     = 1'b0;     // =0 rm/reg; =1 reg/rm
reg  [15:0] wb          = 16'h0;    // Данные для записи в modrm

// Арифметико-логическое устройство
reg  [ 4:0] alumode;
reg  [15:0] op1;
reg  [15:0] op2;

// Выбранная в данный момент шина данных
// =0 cs:ip
// =1 segment:cursor
// Где segment:cursor это эффективный адрес
reg         bus         = 1'b0;
reg         override    = 1'b0;  // Встретился сегментный префикс
reg  [15:0] cursor      = 1'b0;  // Эффективный адрес
reg  [15:0] segment     = 1'b0;  // Сегментный адрес
reg  [ 1:0] rep         = 2'b00; // Если rep[1] то префикс активирован
