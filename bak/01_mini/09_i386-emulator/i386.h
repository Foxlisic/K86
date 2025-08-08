#include <SDL2/SDL.h>

// 8,16,32 бита
typedef unsigned char       byte;
typedef unsigned int        word;
typedef unsigned long       dword;
typedef unsigned long long  qword;

#define AX_ regs[0]
#define CX_ regs[1]
#define DX_ regs[2]
#define BX_ regs[3]
#define SP_ regs[4]
#define BP_ regs[5]
#define SI_ regs[6]
#define DI_ regs[7]
#define AL_ (regs[0]&255)
#define CL_ (regs[1]&255)
#define DL_ (regs[2]&255)
#define BL_ (regs[3]&255)
#define AH_ (regs[0]>>8)
#define CH_ (regs[1]>>8)
#define DH_ (regs[2]>>8)
#define BH_ (regs[3]>>8)

#define REPINC(a,b) {if (flags & D_FLAG) a-=b; else a+=b; }
#define REPINIT if (rep && CX_ == 0) break;

static const uint32_t dac[16] =
{
    0x000000, 0x000088, 0x008800, 0x008888,
    0x880000, 0x880088, 0x885500, 0xaaaaaa,
    0x555555, 0x5555ff, 0x55ff55, 0x55ffff,
    0xff5555, 0xff55ff, 0xffff55, 0xffffff
};

enum FlagBit
{
    C_FLAG = 0x001, P_FLAG = 0x004, A_FLAG = 0x010, Z_FLAG = 0x040,
    N_FLAG = 0x080, T_FLAG = 0x100, I_FLAG = 0x200, D_FLAG = 0x400,
    V_FLAG = 0x800
};

enum RegsALL
{
    REG_AX = 0, REG_AL = 0, REG_CX = 1, REG_CL = 1,
    REG_DX = 2, REG_DL = 2, REG_BX = 3, REG_BL = 3,
    REG_SP = 4, REG_AH = 4, REG_BP = 5, REG_CH = 5,
    REG_SI = 6, REG_DH = 6, REG_DI = 7, REG_BH = 7,
};

enum SegID    { SEG_ES = 0, SEG_CS = 1, SEG_SS = 2, SEG_DS = 3, SEG_FS = 4, SEG_GS = 5 };
enum Prefixes { REPNZ  = 1, REPZ   = 2 };


// Список мнемоник, используютcя в ops
const char* mnemonics[] = {

    /* 00 */ "add",     /* 01 */ "or",      /* 02 */ "adc",     /* 03 */ "sbb",
    /* 04 */ "and",     /* 05 */ "sub",     /* 06 */ "xor",     /* 07 */ "cmp",
    /* 08 */ "es:",     /* 09 */ "cs:",     /* 0A */ "ss:",     /* 0B */ "ds:",
    /* 0C */ "fs:",     /* 0D */ "gs:",     /* 0E */ "push",    /* 0F */ "pop",

    /* 10 */ "daa",     /* 11 */ "das",     /* 12 */ "aaa",     /* 13 */ "aas",
    /* 14 */ "inc",     /* 15 */ "dec",     /* 16 */ "pusha",   /* 17 */ "popa",
    /* 18 */ "bound",   /* 19 */ "arpl",    /* 1A */ "imul",    /* 1B */ "ins",
    /* 1C */ "outs",    /* 1D */ "test",    /* 1E */ "xchg",    /* 1F */ "lea",

    /* 20 */ "jo",      /* 21 */ "jno",     /* 22 */ "jb",      /* 23 */ "jnb",
    /* 24 */ "jz",      /* 25 */ "jnz",     /* 26 */ "jbe",     /* 27 */ "jnbe",
    /* 28 */ "js",      /* 29 */ "jns",     /* 2A */ "jp",      /* 2B */ "jnp",
    /* 2C */ "jl",      /* 2D */ "jnl",     /* 2E */ "jle",     /* 2F */ "jnle",

    /* 30 */ "mov",     /* 31 */ "nop",     /* 32 */ "cbw",     /* 33 */ "cwd",
    /* 34 */ "cwde",    /* 35 */ "cdq",     /* 36 */ "callf",   /* 37 */ "fwait",
    /* 38 */ "pushf",   /* 39 */ "popf",    /* 3A */ "sahf",    /* 3B */ "lahf",
    /* 3C */ "movs",    /* 3D */ "cmps",    /* 3E */ "stos",    /* 3F */ "lods",

    /* 40 */ "scas",    /* 41 */ "ret",     /* 42 */ "retf",    /* 43 */ "les",
    /* 44 */ "lds",     /* 45 */ "lfs",     /* 46 */ "lgs",     /* 47 */ "enter",
    /* 48 */ "leave",   /* 49 */ "int",     /* 4A */ "int1",    /* 4B */ "int3",
    /* 4C */ "into",    /* 4D */ "iret",    /* 4E */ "aam",     /* 4F */ "aad",

    /* 50 */ "salc",    /* 51 */ "xlatb",   /* 52 */ "loopnz",  /* 53 */ "loopz",
    /* 54 */ "loop",    /* 55 */ "jcxz",    /* 56 */ "in",      /* 57 */ "out",
    /* 58 */ "call",    /* 59 */ "jmp",     /* 5A */ "jmpf",    /* 5B */ "lock:",
    /* 5C */ "repnz:",  /* 5D */ "repz:",   /* 5E */ "hlt",     /* 5F */ "cmc",

    /* 60 */ "clc",     /* 61 */ "stc",     /* 62 */ "cli",     /* 63 */ "sti",
    /* 64 */ "cld",     /* 65 */ "std",     /* 66 */ "rol",     /* 67 */ "ror",
    /* 68 */ "rcl",     /* 69 */ "rcr",     /* 6A */ "shl",     /* 6B */ "shr",
    /* 6C */ "sal",     /* 6D */ "sar",     /* 6E */ "not",     /* 6F */ "neg",

    /* 70 */ "mul",     /* 71 */ "div",     /* 72 */ "idiv",    /* 73 */ "rep:",
    /* 74 */ "",        /* 75 */ "",        /* 76 */ "",        /* 77 */ "",
    /* 78 */ "",        /* 79 */ "",        /* 7A */ "",        /* 7B */ "",
    /* 7C */ "",        /* 7D */ "",        /* 7E */ "",        /* 7F */ "",
};

const int ops[256] = {

    /* Основной набор */
    /* 00 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0E, 0x0F,
    /* 08 */ 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x0E, 0xFF,
    /* 10 */ 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E, 0x0F,
    /* 18 */ 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x0E, 0x0F,
    /* 20 */ 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x10,
    /* 28 */ 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x09, 0x11,
    /* 30 */ 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x0A, 0x12,
    /* 38 */ 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x0B, 0x13,
    /* 40 */ 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
    /* 48 */ 0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x15,
    /* 50 */ 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E,
    /* 58 */ 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    /* 60 */ 0x16, 0x17, 0x18, 0x19, 0x0C, 0x0D, 0xFF, 0xFF,
    /* 68 */ 0x0E, 0x1A, 0x0E, 0x1A, 0x1B, 0x1B, 0x1C, 0x1C,
    /* 70 */ 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
    /* 78 */ 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    /* 80 */ 0xFF, 0xFF, 0xFF, 0xFF, 0x1D, 0x1D, 0x1E, 0x1E,
    /* 88 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x1F, 0x30, 0x0F,
    /* 90 */ 0x31, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E,
    /* 98 */ 0x32, 0x33, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B,
    /* A0 */ 0x30, 0x30, 0x30, 0x30, 0x3C, 0x3C, 0x3D, 0x3D,
    /* A8 */ 0x1D, 0x1D, 0x3E, 0x3E, 0x3F, 0x3F, 0x40, 0x40,
    /* B0 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
    /* B8 */ 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
    /* C0 */ 0xFF, 0xFF, 0x41, 0x41, 0x43, 0x44, 0x30, 0x30,
    /* C8 */ 0x47, 0x48, 0x42, 0x42, 0x4B, 0x49, 0x4C, 0x4D,
    /* D0 */ 0xFF, 0xFF, 0xFF, 0xFF, 0x4E, 0x4F, 0x50, 0x51,
    /* D8 */ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    /* E0 */ 0x52, 0x53, 0x54, 0x55, 0x56, 0x56, 0x57, 0x57,
    /* E8 */ 0x58, 0x59, 0x5A, 0x59, 0x56, 0x56, 0x57, 0x57,
    /* F0 */ 0x5B, 0x4A, 0x5C, 0x5D, 0x5E, 0x5F, 0xFF, 0xFF,
    /* F8 */ 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0xFF, 0xFF
};

const int modrm_lookup[512] = {

    /*       0 1 2 3 4 5 6 7 8 9 A B C D E F */
    /* 00 */ 1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,
    /* 10 */ 1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,
    /* 20 */ 1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,
    /* 30 */ 1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,
    /* 40 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 50 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 60 */ 0,0,1,1,0,0,0,0,0,1,0,1,0,0,0,0,
    /* 70 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 80 */ 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    /* 90 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* A0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* B0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* C0 */ 1,1,0,0,1,1,1,1,0,0,0,0,0,0,0,0,
    /* D0 */ 1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,
    /* E0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* F0 */ 0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1
};

const char* regnames[] = {

    /* 00 */ "al",  "cl",  "dl",  "bl",  "ah",  "ch",  "dh",  "bh",
    /* 08 */ "ax",  "cx",  "dx",  "bx",  "sp",  "bp",  "si",  "di",
    /* 10 */ "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi",
    /* 18 */ "es",  "cs",  "ss",  "ds",  "fs",  "gs",  "",    ""

};

const char* rm16names[] = {"bx+si","bx+di","bp+si","bp+di","si","di","bp","bx"};
const char* grp2[]      = {"test","test","not","neg","mul","imul","div","idiv"};
const char* grp3[]      = {"inc","dec","call","callf","jmp","jmpf","push","(unk)"};

class i386
{
protected:

    // SDL2 Окно
    SDL_Surface*        screen_surface;
    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_PixelFormat*    sdl_pixel_format;
    SDL_Texture*        sdl_screen_texture;
    SDL_Event           evt;
    Uint32*             screen_buffer;

    // Подключение памяти
    uint8_t             ram[64*1024];

    // Регистры общего назначения
    // 0 eAX=AH:AL | 4 eSP
    // 1 eCX=CH:CL | 5 eBP
    // 2 eDX=DH:DL | 6 eSI
    // 3 eBX=BH:BL | 7 eDI
    dword   regs[8];
    word    segs[8];

    // Сегментные регистры
    // 0=es; 1=cs; 2=ss; 3=ds; 4=fs; 5=gs; 6,7=<unknown>
    word    seg_es, seg_cs, seg_ss, seg_ds, seg_fs, seg_gs;

    // Таблица ZNP для 8 бит
    byte    znptable8[256];

    // Главные регистры
    word    ip, ip_start;
    word    flags;

    // Режим работы
    word    tstates, rdtsc;

    // Блок исполнения инструкции
    byte    opcode, rmdat, cpu_reg, cpu_mod, cpu_rm, inhlt;
    byte    sel_seg, rep;
    byte    cont, tempc, noint;
    byte    tempb, tempb2;
    byte    p66, p67, trap;
    word    eaaddr;
    word    tempws;
    word    tempw, tempw2;
    dword   templ, templs;
    dword   segment;

    // Декодер
    int     eip;
    int     reg, mod, rm;
    char    tmps[256];
    char    dis_rg[32]; // Rm-часть Modrm
    char    dis_rm[64]; // Rm-часть Modrm
    char    dis_px[32]; // Префикс
    int     max_memory;
    // Итоговая строка
    char    dis_row[512];
    int     debug_on;

public:

    i386(int argc, char** argv);

    int     main();
    void    pset(int x, int y, Uint32 cl);
    void    refresh();

    byte    fetch_byte();
    word    fetch_word();

    // Исполнение инструкции
    word    x86run(word instr_cnt);
    void    extended_instr();
    void    autorep(byte flag_test);
    void    ud(byte code);

    // Чтение и запись в память
    byte    read        (dword seg, word offset);
    word    read_word   (dword seg, word offset);
    byte    io_read     (word address);
    void    io_write    (word address, byte data);
    void    write       (dword seg, word offset, byte data);
    void    write_word  (dword seg, word offset, word data);

    // Стек
    void    push(word v);
    word    pop();
    void    interrupt(byte int_id);
    void    callfar(word _cs, word _ip);

    // Извлечение и сохранение данных в память или регистр
    byte    getr8(byte id);
    void    setr8(byte id, byte v);
    word    getr16(byte id);
    void    setr16(byte id, word v);
    void    fetchea();
    byte    geteab();
    word    geteaw();
    void    seteab(byte v);
    void    seteaw(word v);

    // Загрузка нового значения CS
    void    loadcs(word s) { segs[SEG_CS] = s; seg_cs = (dword)s << 4; }
    void    loadss(word s) { segs[SEG_SS] = s; seg_ss = (dword)s << 4; }
    void    loades(word s) { segs[SEG_ES] = s; seg_es = (dword)s << 4; }
    void    loadds(word s) { segs[SEG_DS] = s; seg_ds = (dword)s << 4; }
    void    loadfs(word s) { segs[SEG_FS] = s; seg_fs = (dword)s << 4; }
    void    loadgs(word s) { segs[SEG_GS] = s; seg_gs = (dword)s << 4; }

    void    setznp8   (byte val);
    void    setznp16  (word val);

    // Арифметические и логические операции
    byte    setadd8   (byte a, byte b);
    byte    setadd8nc (byte a, byte b);
    byte    setadc8   (byte a, byte b, byte tempc);
    byte    setsub8   (byte a, byte b);
    byte    setsub8nc (byte a, byte b);
    byte    setsbc8   (byte a, byte b, byte tempc);
    byte    setor8    (byte a, byte b);
    byte    setand8   (byte a, byte b);
    byte    setxor8   (byte a, byte b);

    word    setadd16  (word a, word b);
    word    setadd16nc(word a, word b);
    word    setadc16  (word a, word b, byte tempc);
    word    setsub16  (word a, word b);
    word    setsub16nc(word a, word b);
    word    setsbc16  (word a, word b, byte tempc);
    word    setor16   (word a, word b);
    word    setand16  (word a, word b);
    word    setxor16  (word a, word b);

    // Десятичная коррекция
    void    daa();
    void    das();
    void    aaa();
    void    aas();
    void    aam();
    void    aad();

    // Групповые АЛУ операции
    byte    groupalu8   (byte mode, byte a, byte b);
    word    groupalu16  (byte mode, word a, word b);
    word    groupshift  (byte mode, byte bit, word temp, byte n);

    // Дизассемблер
    int     readb(int address);
    int     fetchb();
    int     fetchw();
    int     fetchd();
    int     disas_modrm(int reg32, int mem32);
    int     disassemble(int address);
};
