#ifndef X86_CPU
#define X86_CPU

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

enum FlagBit
{
    C_FLAG = 0x0001,
    P_FLAG = 0x0004,
    A_FLAG = 0x0010,
    Z_FLAG = 0x0040,
    N_FLAG = 0x0080,
    T_FLAG = 0x0100,
    I_FLAG = 0x0200,
    D_FLAG = 0x0400,
    V_FLAG = 0x0800
};

enum RegsALL {

    REG_AX = 0, REG_AL = 0,
    REG_CX = 1, REG_CL = 1,
    REG_DX = 2, REG_DL = 2,
    REG_BX = 3, REG_BL = 3,
    REG_SP = 4, REG_AH = 4,
    REG_BP = 5, REG_CH = 5,
    REG_SI = 6, REG_DH = 6,
    REG_DI = 7, REG_BH = 7,
};

enum SegID {

    SEG_ES = 0,
    SEG_CS = 1,
    SEG_SS = 2,
    SEG_DS = 3,
    SEG_FS = 4,
    SEG_GS = 5
};

enum Prefixes {

    REPNZ = 1,
    REPZ  = 2

};

class CPU {

protected:

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
    byte    offset;
    byte    cont, tempc, noint;
    byte    tempb, tempb2;
    byte    p66, p67, trap;
    word    eaaddr;
    word    tempws;
    word    tempw, tempw2;
    dword   templ, templs;
    dword   segment;

public:

    CPU();

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
};

#endif
