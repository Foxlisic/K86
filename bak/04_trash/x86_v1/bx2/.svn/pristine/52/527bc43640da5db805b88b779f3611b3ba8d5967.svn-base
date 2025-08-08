// Объявление типов
// -----------------------------------------------------------------------------
typedef unsigned char       byte;
typedef unsigned short      word;
typedef unsigned int        dword; // 32 bit
typedef unsigned long long  qword; // 64 bit

// Объявление переменных
// -----------------------------------------------------------------------------
byte        memory[1024*1024];
byte        cursor_x, cursor_y, cursor_s, cursor_e, cursor_flash;

// Прототипы функции
// -----------------------------------------------------------------------------
void        update_char(int x, int y, byte ch, byte attr);
void        debugreg();
byte        phy_read(dword address);
void        phy_write(dword address, byte data);
byte        ioread(word port);
void        iowrite(word port, byte data);
void        readbios(const char* filename, dword address);