// Глобальная память
byte memory[1024*1024];

// Процедуры для работы с запущенной машиной
void machine_start();            
void machine_call_timer_func(int value);   
void machine_update();
void machine_print_char(int x, int y, unsigned char ch);

// Чтение и запись в память и порты на физическом уровне
byte machine_read     (dword address);
void machine_write    (dword address, byte data);

byte io_read (word port);
void io_write(word port, byte data);
