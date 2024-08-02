
// Кол-во инструкции за 1/50 секунду : 3 мгц
#define CPU_QUANT   60000 

#define byte        unsigned char
#define word        unsigned short int
#define uint        unsigned int
#define ulong       unsigned long long

#define p(x,y)      printf("%04x (%s)\n", x, y);        // Отладка

// Регистры 8 бит
#define REG_AL  0
#define REG_CL  1
#define REG_DL  2
#define REG_BL  3
#define REG_AH  4
#define REG_CH  5
#define REG_DH  6
#define REG_BH  7

#define REPNZ 1
#define REPZ  2

// Извлечь биты [4:3]
#define OPC43 ((opcode & 0x38)>>3)
#define OPC20 (opcode & 0x07)
#define OPC30 (opcode & 0x0F)

// Макросы для сохращения
#define ALU_GRP(x,y,z,b) mode = OPC43; res = alu_grp(mode, x, y, b); if (mode < 7) z; break;
#define ALU_GEB(x,y,z,b) res = alu_grp(mrm_reg, x, y, b); if (mode < 7) z; break;

// INC/DEC
#define INCDEC(x,y,z) mode = y; put_reg(mode, z, x( get_reg(mode, z), z)); break;

// LES/LDS
#define LOADSEG(x) op1 = read16(SEGDEFAULT, ea); op2 = read16(SEGDEFAULT, ea + 2); put_reg(mrm_reg, 16, op1); x = op2

#define SET_CARRY(x)  f.c = ((x) > 0)
#define SET_PARITY(x) f.p = (parity_lookup[(x) & 0xff])
#define SET_AUX(x)    f.a = ((x) > 0)
#define SET_ZERO(x)   f.z = ((x) == 0)
#define SET_SIGN(x)   f.s = ((x) > 0)
#define SET_OVER(x)   f.o = ((x) > 0)

// Бит знака и маска для отсечения
#define ALUBITMASK    uint sign = (1 << (bit - 1)); uint mask = ((1 << bit) - 1)
#define SINCREMENT    r.si = (r.si + (f.d ? -tmp : tmp)) & 0xffff
#define DINCREMENT    r.di = (r.di + (f.d ? -tmp : tmp)) & 0xffff
#define SEGDEFAULT    (segment < 0 ? r.ds : segment)

struct Tflags {

    char o; // Переполнение
    char d; // Направление
    char i; // Прерывание
    char t; // Отладка
    char s; // Знак
    char z; // Нуль
    char a; // Полуперенос
    char p; // Четность
    char c; // Перенос
};

struct Tregs {

    unsigned int ax, bx, cx, dx;
    unsigned int sp, bp, si, di;
    unsigned int es, cs, ss, ds;
    unsigned int fs, gs;
};

static const char parity_lookup[256] = {
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1
};

static const unsigned char instruction_has_modrm[512] = {
  /*       0 1 2 3 4 5 6 7 8 9 a b c d e f          */
  /*       -------------------------------          */
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
  /* F0 */ 0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,
  /*       0 1 2 3 4 5 6 7 8 9 a b c d e f           */
  /*       -------------------------------           */
           1,1,1,1,0,0,0,0,0,0,0,0,0,1,0,1, /* 0F 00 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F 10 */
           1,1,1,1,1,0,1,0,1,1,1,1,1,1,1,1, /* 0F 20 */
           0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0, /* 0F 30 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F 40 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F 50 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F 60 */
           1,1,1,1,1,1,1,0,1,1,0,0,1,1,1,1, /* 0F 70 */
           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, /* 0F 80 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F 90 */
           0,0,0,1,1,1,0,0,0,0,0,1,1,1,1,1, /* 0F A0 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F B0 */
           1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0, /* 0F C0 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F D0 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, /* 0F E0 */
           1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0  /* 0F F0 */
  /*       -------------------------------           */
  /*       0 1 2 3 4 5 6 7 8 9 a b c d e f           */
};

// Группы исполнителей инструции
enum instr {

    UD,         // Undefined Instruction
    ALU_EbGb,   // АЛУ Eb, Gb
    ALU_EvGv,
    ALU_GbEb,
    ALU_GvEv,
    ALU_ALIb,   // АЛУ AL, Gb/Gv
    ALU_AXIv,
    PUSHss,     // Сохранение сегмент в стек
    POPss,      // Восстановить сегмент из стека
    DAA,
    DAS,
    AAA,
    AAS,
    INCGv,
    DECGv,
    PUSHGv,
    POPGv,
    PUSHIv,
    JCOND8,     // Условный переход
    AGEbIb,     // Арифметика по группам
    AGEbIv,
    AGEvIb,
    TESTEbIb,
    TESTEvIv,
    XCHGEbGb,
    XCHGEvGv,
    MOVEbGb,
    MOVEvGv,
    MOVGbEb,
    MOVGvEv,
    MOVEvS,
    LEAGvM,
    MOVSEv,
    POPEv,
    NOP,
    XCHGRx,
    CBW,
    CWD,
    PUSHF,
    POPF,
    SAHF,
    LAHF,
    CALLFm32,    
    MOVALm16,
    MOVAXm16,
    MOVm16AL,
    MOVm16AX,
    TESTALIb,
    TESTAXIv,
    MOVS,
    CMPS,
    STOS,
    LODS,
    SCAS,
    MOVGbIb,
    MOVGvIv,
    SGRPEbIb,
    SGRPEvIb,    
    RETIv,
    RET,
    RETFIv,
    RETF,    
    LESGvEv,
    LDSGvEv,
    MOVEbIb,
    MOVEvIv,
    ENTER,
    LEAVE,
    INT3,
    INTIb,
    INTO,
    IRET,
    SGRPEb1,
    SGRPEv1,
    SGRPEbCL,
    SGRPEvCL,    
    AAM,
    AAD,
    SALC,
    XLATB,    
    FPU,
    LOOPx,
    LOOP,
    JCXZ,
    
    INbIb,
    INvIb,
    INbDx,
    INvDx,
    OUTbIb,
    OUTvIb,
    OUTbDX,
    OUTvDX,

    CALLIv,
    JMPIv,
    JMPFm32,
    JMPIb,
    INT1,
    HLT,
    CMC,
    CLC,
    STC,
    CLI,
    STI,
    CLD,
    STD,
    
    GRP1b,
    GRP1v,
    GRP2b,
    GRP2v
};

// Таблица инструкции
static const int instructions[512] = {

    // Базовый неполный набор инструкции
    /* 00 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   PUSHss,    POPss,
    /* 08 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   PUSHss,    UD,
    /* 10 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   PUSHss,    POPss,
    /* 18 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   PUSHss,    POPss,
    /* 20 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   UD,        DAA,
    /* 28 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   UD,        DAS,
    /* 30 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   UD,        AAA,
    /* 38 */ ALU_EbGb,   ALU_EvGv,   ALU_GbEb,   ALU_GvEv,   ALU_ALIb,   ALU_AXIv,   UD,        AAS,
    /* 40 */ INCGv,      INCGv,      INCGv,      INCGv,      INCGv,      INCGv,      INCGv,     INCGv,
    /* 48 */ DECGv,      DECGv,      DECGv,      DECGv,      DECGv,      DECGv,      DECGv,     DECGv,
    /* 50 */ PUSHGv,     PUSHGv,     PUSHGv,     PUSHGv,     PUSHGv,     PUSHGv,     PUSHGv,    PUSHGv,
    /* 58 */ POPGv,      POPGv,      POPGv,      POPGv,      POPGv,      POPGv,      POPGv,     POPGv,
    /* 60 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,         // 186+
    /* 68 */ PUSHIv,     UD,         UD,         UD,         UD,         UD,         UD,        UD,         // 186+
    /* 70 */ JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,    JCOND8,
    /* 78 */ JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,     JCOND8,    JCOND8,
    /* 80 */ AGEbIb,     AGEbIv,     AGEbIb,     AGEvIb,     TESTEbIb,   TESTEvIv,   XCHGEbGb,  XCHGEvGv,
    /* 88 */ MOVEbGb,    MOVEvGv,    MOVGbEb,    MOVGvEv,    MOVEvS,     LEAGvM,     MOVSEv,    POPEv,
    /* 90 */ NOP,        XCHGRx,     XCHGRx,     XCHGRx,     XCHGRx,     XCHGRx,     XCHGRx,    XCHGRx,
    /* 98 */ CBW,        CWD,        CALLFm32,   NOP,        PUSHF,      POPF,       SAHF,      LAHF,
    /* A0 */ MOVALm16,   MOVAXm16,   MOVm16AL,   MOVm16AX,   MOVS,       MOVS,       CMPS,      CMPS,
    /* A8 */ TESTALIb,   TESTAXIv,   STOS,       STOS,       LODS,       LODS,       SCAS,      SCAS,
    /* B0 */ MOVGbIb,    MOVGbIb,    MOVGbIb,    MOVGbIb,    MOVGbIb,    MOVGbIb,    MOVGbIb,   MOVGbIb,
    /* B8 */ MOVGvIv,    MOVGvIv,    MOVGvIv,    MOVGvIv,    MOVGvIv,    MOVGvIv,    MOVGvIv,   MOVGvIv,
    /* C0 */ SGRPEbIb,   SGRPEvIb,   RETIv,      RET,        LESGvEv,    LDSGvEv,    MOVEbIb,   MOVEvIv,
    /* C8 */ ENTER,      LEAVE,      RETFIv,     RETF,       INT3,       INTIb,      INTO,      IRET,
    /* D0 */ SGRPEb1,    SGRPEv1,    SGRPEbCL,   SGRPEvCL,   AAM,        AAD,        SALC,      XLATB,
    /* D8 */ FPU,        FPU,        FPU,        FPU,        FPU,        FPU,        FPU,       FPU,
    /* E0 */ LOOPx,      LOOPx,      LOOP,       JCXZ,       INbIb,      INvIb,      OUTbIb,    OUTvIb,
    /* E8 */ CALLIv,     JMPIv,      JMPFm32,    JMPIb,      INbDx,      INvDx,      OUTbDX,    OUTvDX,
    /* F0 */ UD,         INT1,       UD,         UD,         HLT,        CMC,        GRP1b,     GRP1v,
    /* F8 */ CLC,        STC,        CLI,        STI,        CLD,        STD,        GRP2b,     GRP2v,

    // Дополнительный набор инструкции
    /* 00 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 08 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 10 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 18 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 20 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 28 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 30 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 38 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 40 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 48 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 50 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 58 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 60 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 68 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 70 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 78 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 80 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 88 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 90 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* 98 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* A0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* A8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* B0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* B8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* C0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* C8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* D0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* D8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* E0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* E8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* F0 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD,
    /* F8 */ UD,         UD,         UD,         UD,         UD,         UD,         UD,        UD
};
