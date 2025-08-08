// Макросы
// -----------------------------------------------------------------------------

// Общая для всех арифметических и логических инструкции SZMASK
// n - количество бит (size|opsize); s - старший бит; m - маска; u - 1<<n
#define MAKE_SZMASK \
    byte  n = (size? (opsize ? 32 : 16) : 8); \
    dword s = 1 << (n-1); \
    qword u = (1 << n); \
    qword m = u-1;

// Вычисление общих для всех Z,N,P,C,A флагов
#define ARITH_ZNPCA \
    set_znpbw   (c, size); \
    set_carry   (c & u); \
    set_aux     ((a^b^c) & 0x10)

// Флаги после выполнения логической операции
#define ARITH_LOGIC \
    set_znpbw (c, size); \
    eflags &=~ (C_FLAG | V_FLAG | A_FLAG)

// Перенос после выполнения сложения и вычитания
#define ARITH_OVERFLOW_ADD set_over (!!((a^b^s) & (a^c) & s))
#define ARITH_OVERFLOW_SUB set_over (!!((a^b  ) & (a^c) & s))

// Структуры и перечисления
// -----------------------------------------------------------------------------

// Структура сегмента
struct Tsegment 
{
    dword   base;       // Базовый адрес сегмента
    dword   limit;      // Размер сегмента
    byte    defsize;    // 0-16 bit; 1-32 bit
    byte    cpl;        // Current Privilege Mode
    word    selector;   // Сохраненный селектор
};

// Имена регистров
enum RegNames 
{
    // 32 битные
    REG_EAX = 0, REG_ESP = 4, 
    REG_ECX = 1, REG_EBP = 5, 
    REG_EDX = 2, REG_ESI = 6, 
    REG_EBX = 3, REG_EDI = 7, 

    // 16 битные
    REG_AX = 0, REG_SP = 4,
    REG_CX = 1, REG_BP = 5,
    REG_DX = 2, REG_SI = 6,
    REG_BX = 3, REG_DI = 7,

    // 8 битные
    REG_AL = 0, REG_AH = 4,
    REG_CL = 1, REG_CH = 5,
    REG_DL = 2, REG_DH = 6,
    REG_BL = 3, REG_BH = 7,
    
    // Сегментные
    REG_ES = 0, REG_DS = 3,
    REG_CS = 1, REG_FS = 4,
    REG_SS = 2, REG_GS = 5,
    
};

enum Exceptions
{
    EXCEPTION_INVALID_OPCODE    = 0x06,
    EXCEPTION_INVALID_TSS       = 0x0A,
    EXCEPTION_NOT_PRESENT       = 0x0B,
    EXCEPTION_STACK_SEGMENT     = 0x0C,
    EXCEPTION_GENERAL           = 0x0D
};

enum FlagsPosition {
    
    C_FLAG  = 0x0001,
    P_FLAG  = 0x0004,
    A_FLAG  = 0x0010,
    Z_FLAG  = 0x0040,
    N_FLAG  = 0x0080,   // Флаг знака
    T_FLAG  = 0x0100,
    I_FLAG  = 0x0200,
    D_FLAG  = 0x0400,
    V_FLAG  = 0x0800    // Флаг переполнения
};

enum BitsOpcode {
    
    BIT_BYTE    = 0,
    BIT_WORD    = 1
};

// Состояние процессора
// -----------------------------------------------------------------------------
word    opcode;
dword   regs[8];            // 32-х битные регистры
struct  Tsegment segs[8];   // 6 сегментов
dword   eip;                // Указатель текущего адреса выполнения инструкии
dword   eflags;             // 32-х битные флаги
byte    pmode;              // =1 Защищенный режим работы
byte    exception;          // >0 Во время исполнения инструкции возникла ошибка

// Прегенерированные таблицы
byte    znptable8[256];

// Состояние инструкции
Tsegment*   segment;
byte        opsize, adsize;
byte        seg_override;
byte        mod_reg, mod_rm, mod_mm;
dword       mod_ea;

// Прототипы
// -----------------------------------------------------------------------------
void    cpu_reset();
void    load_segment(byte segment_id, word selector);
void    step();

// Чтение и запись в память
dword   read_address(struct segment* seg, dword offset);
byte    read_byte   (Tsegment* seg, dword offset);
word    read_word   (Tsegment* seg, dword offset);
dword   read_dword  (Tsegment* seg, dword offset);
void    write_byte  (Tsegment* seg, dword offset, byte data);
void    write_word  (Tsegment* seg, dword offset, word data);
void    write_dword (Tsegment* seg, dword offset, dword data);

// Считывание immediate
byte    fetch();
word    fetch_word();
dword   fetch_dword();
dword   fetch_iw();

// Считывание modrm
void    fetch_modrm();
void    fetch_modrm16();
void    fetch_modrm32();

// Работа с modrm reg
byte    get_regb(byte reg_id);
void    put_regb(byte reg_id, byte data);
dword   get_regw(byte reg_id);
void    put_regw(byte reg_id, dword data);

// Работа с modrm r/m
byte    get_eb();
dword   get_ew();
byte    get_rb();
dword   get_rw();
void    put_eb(byte  data);
void    put_ew(dword data);
void    put_rb(byte  data);
void    put_rw(dword data);

// Установка и получение флагов
void    set_carry  (byte v);
void    set_over   (byte v);
void    set_zero   (byte v);
void    set_sign   (byte v);
void    set_aux    (byte v);
void    set_parity (byte v);
byte    get_carry();

// Арифметическо-логическое устройство
void    set_znpb(byte c);
void    set_znpw(dword d);
void    set_znpbw(dword d, byte size);
dword   addbw(dword a, dword b, byte size);
dword   adcbw(dword a, dword b, byte size);
dword   subbw(dword a, dword b, byte size);
dword   sbbbw(dword a, dword b, byte size);
dword   andbw(dword a, dword b, byte size);
dword   xorbw(dword a, dword b, byte size);
dword   orbw (dword a, dword b, byte size);
void    daa();
void    das();
void    aaa();
void    aas();
void    aam();
void    aad();