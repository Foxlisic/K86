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

uint16_t flags;
uint32_t rdtsc;

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

uint8_t  opcode, rmdat, cpu_reg, cpu_mod, cpu_rm, inhlt;
uint8_t  sel_seg, rep;
uint16_t eaaddr;
uint32_t segment;

// Специальная таблица с Z,S,P
uint8_t  znptable8[256];

// 0 AX=AH:AL | 4 SP
// 1 CX=CH:CL | 5 BP
// 2 DX=DH:DL | 6 SI
// 3 BX=BH:BL | 7 DI
uint16_t regs[8];
uint16_t segs[6];
uint32_t seg_cs, seg_ss, seg_es, seg_ds, seg_fs, seg_gs;
uint16_t ip, ip_start;
uint32_t tstates;
