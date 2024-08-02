// -----------------------------------------------------------------------------
typedef unsigned char       byte;
typedef unsigned short      word;
typedef unsigned int        dword; // 32 bit
typedef unsigned long long  qword; // 64 bit
// -----------------------------------------------------------------------------

// Память 1Мб в глобальной области видимости
byte memory[1024*1024];

// Прототипы функции
// -----------------------------------------------------------------------------
void update_char(int x, int y, byte ch, byte attr);
