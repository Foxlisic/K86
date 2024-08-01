/*
 * Дизассемблер
 */

#define OPCODE_PADLEN   8

// Список мнемоник, используюстя в ops
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

const int ops[512] = {

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
    /* F8 */ 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0xFF, 0xFF,

    /* Дополнительный набор */
    /* 00 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 08 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 10 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 18 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 20 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 28 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 30 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 38 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 40 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 48 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 50 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 58 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 60 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 68 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 70 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 78 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 80 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 88 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 90 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* 98 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* A0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* A8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* B0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* B8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* C0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* C8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* D0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* D8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* E0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* E8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* F0 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    /* F8 */ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

};

const char* regnames[] = {

    /* 00 */ "al",  "cl",  "dl",  "bl",  "ah",  "ch",  "dh",  "bh",
    /* 08 */ "ax",  "cx",  "dx",  "bx",  "sp",  "bp",  "si",  "di",
    /* 10 */ "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi",
    /* 18 */ "es",  "cs",  "ds",  "ss",  "fs",  "gs",  "",    ""

};

const char* rm16names[] = {

    /* 0 */ "bx+si",
    /* 1 */ "bx+di",
    /* 2 */ "bp+si",
    /* 3 */ "bp+di",
    /* 4 */ "si",
    /* 5 */ "di",
    /* 6 */ "bp",
    /* 7 */ "bx"

};

const char* grp2[] = {

    /* 0 */ "test",
    /* 1 */ "test",
    /* 2 */ "not",
    /* 3 */ "neg",
    /* 4 */ "mul",
    /* 5 */ "imul",
    /* 6 */ "div",
    /* 7 */ "idiv",

};

const char* grp3[] = {

    /* 0 */ "inc",
    /* 1 */ "dec",
    /* 2 */ "call",
    /* 3 */ "callf",
    /* 4 */ "jmp",
    /* 5 */ "jmpf",
    /* 6 */ "push",
    /* 7 */ "(unk)",

};

/* Из байта modrm */
int reg, mod, rm;

char tmps[256];
char dis_row[256];
int  dis_visline;

char dis_rg[32];        /* Rm-часть Modrm */
char dis_rm[32];        /* Rm-часть Modrm */
char dis_px[32];        /* Префикс */

void init_disas() {
    
    addr_start = 0;
    dump_start = 0;
    dis_visline = 0;    
}

void dis_save_state() {
    
    dis_eax = eax;
    dis_ebx = ebx;
    dis_ecx = ecx;
    dis_edx = edx;
    dis_esp = esp;
    dis_ebp = ebp;
    dis_esi = esi;
    dis_edi = edi;
    dis_eip = eip;
    
    dis_es  = es;
    dis_cs  = cs;
    dis_ds  = ds;
    dis_ss  = ss;
    dis_fs  = fs;
    dis_gs  = gs;
        
}

/* Дизассемблирование одной инструкции */
// ---------------------------------------------------------------------

// reg32 - расширение регистра, mem32 - метода адресации
// reg32 = 0x08 8 бит           mem32 = 0x00 16 бит
//       = 0x10 16 бит                = 0x20 32 бит
//       = 0x20 32 бит

int disas_modrm(int reg32, int mem32) {

    int n = 0, b, w;

    /* Очистка */
    dis_rg[0] = 0;
    dis_rm[0] = 0;

    b = fetchb(); n++;

    rm  = (b & 0x07);
    reg = (b & 0x38) >> 3;
    mod = (b & 0xc0);

    /* Печать регистра 8/16/32 */
    switch (reg32) {
        case 0x08: sprintf(dis_rg, "%s", regnames[ reg ]); break;
        case 0x10: sprintf(dis_rg, "%s", regnames[ reg + 0x08 ]); break;
        case 0x20: sprintf(dis_rg, "%s", regnames[ reg + 0x10 ]); break;
        default:   sprintf(dis_rg, "<unknown>"); break;
    }
        
    // 16 бит
    if (mem32 == 0) {        

        /* Rm-часть */
        switch (mod) {

            /* Индекс без disp или disp16 */
            case 0x00:

                if (rm == 6) {
                    w = fetchw(); n += 2;
                    sprintf(dis_rm, "[%s%04x]", dis_px, w);
                } else {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                }

                break;

            /* + disp8 */
            case 0x40:

                b = fetchb(); n++;
                if (b & 0x80) {
                    sprintf(dis_rm, "[%s%s-%02x]", dis_px, rm16names[ rm ], (0xff ^ b) + 1);
                } else if (b == 0) {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                } else {
                    sprintf(dis_rm, "[%s%s+%02x]", dis_px, rm16names[ rm ], b);
                }

                break;

            /* + disp16 */
            case 0x80:

                w = fetchw(); n += 2;
                if (w & 0x8000) {
                    sprintf(dis_rm, "[%s%s-%04x]", dis_px, rm16names[ rm ], (0xFFFF ^ w) + 1);
                } else if (w == 0) {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                } else {
                    sprintf(dis_rm, "[%s%s+%04x]", dis_px, rm16names[ rm ], w);
                }

                break;

            /* Регистровая часть */
            case 0xc0:

                switch (reg32) {
                    case 0x08: sprintf(dis_rm, "%s", regnames[ rm ]); break;
                    case 0x10: sprintf(dis_rm, "%s", regnames[ rm + 0x08 ]); break;
                    case 0x20: sprintf(dis_rm, "%s", regnames[ rm + 0x10 ]); break;
                }

                break;
        }
    }
    
    // 32 бит
    else {
        
        int sib = 0, sibhas = 0;

        switch (mod) {
            
            case 0x00: 
            
                if (rm == 5) {
                    
                    w = fetchd(); n += 4;
                    sprintf(dis_rm, "[%s%08x]", dis_px, w);
                    
                } else if (rm == 4) { /* SIB */
                    
                    sib = fetchb(); n++;
                    sibhas = 1;
                    
                } else {
                    sprintf(dis_rm, "[%s%s]", dis_px, regnames[0x10 + rm]);
                }
                
                break;
                
            /* + disp8 */    
            case 0x40: 

            
                if (rm == 4) { 

                    sib = fetchb(); n++;
                    sibhas = 1;
                    
                } else {

                    b = fetchb(); n++;
                    
                    if (b & 0x80) {
                        sprintf(dis_rm, "[%s%s-%02x]", dis_px, regnames[ 0x10 + rm ], (0xff ^ b) + 1);
                    } else if (b == 0) {
                        sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + rm ]);
                    } else {
                        sprintf(dis_rm, "[%s%s+%02x]", dis_px, regnames[ 0x10 + rm ], b);
                    }
                }
                
                break;
            
            /* + disp32 */    
            case 0x80:
        
                
                if (rm == 4) {
                    
                    sib = fetchb(); n++;
                    sibhas = 1;
                    
                } else {

                    w = fetchd(); n += 4;
                    
                    if (w & 0x80000000) {
                    sprintf(dis_rm, "[%s%s-%04x]", dis_px, regnames[ 0x10 + rm ], (0xFFFFFFFF ^ w) + 1);
                    } else if (w == 0) {
                        sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + rm ]);
                    } else {
                        sprintf(dis_rm, "[%s%s+%04x]", dis_px, regnames[ 0x10 + rm ], w);
                    }
                }

                break;
                
            /* Регистровая часть */
            case 0xc0:

                switch (reg32) {
                    case 0x08: sprintf(dis_rm, "%s", regnames[ rm ]); break;
                    case 0x10: sprintf(dis_rm, "%s", regnames[ rm + 0x08 ]); break;
                    case 0x20: sprintf(dis_rm, "%s", regnames[ rm + 0x10 ]); break;
                }

                break;            
        }
        
        /* Имеется байт SIB */
        if (sibhas) {            
            
            char cdisp32[16]; cdisp32[0] = 0;
            
            int disp = 0;
            int sib_ss = (sib & 0xc0);
            int sib_ix = (sib & 0x38) >> 3;
            int sib_bs = (sib & 0x07);                        
            
            /* Декодирование Displacement */
            switch (mod) {
                
                case 0x40: 
                    
                    disp = fetchb(); n += 1;
                    
                    if (disp & 0x80) {
                        sprintf(cdisp32, "-%02X", (disp ^ 0xff) + 1);
                    } else {
                        sprintf(cdisp32, "+%02X", disp);
                    }
                    
                    break;
                    
               case 0x80: 
               case 0xc0: 
                    
                    disp = fetchd(); n += 4;
                    if (disp & 0x80000000) {
                        sprintf(cdisp32, "-%08X", (disp ^ 0xffffffff) + 1);
                    } else {
                        sprintf(cdisp32, "+%08X", disp);
                    }
                    break;
            }
            
            /* Декодирование Index */
            if (sib_ix == 4) {
                
                sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + sib_bs ]);
                
            } else {
                
                switch (sib_ss) {
                
                    case 0x00: 
                    
                        sprintf(dis_rm, "[%s%s+%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ]); 
                        break;
                        
                    case 0x40: 
                    
                        sprintf(dis_rm, "[%s%s+2*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32); 
                        break;
                        
                    case 0x80: 
                    
                        sprintf(dis_rm, "[%s%s+4*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32); 
                        break;
                        
                    case 0xc0: 
                    
                        sprintf(dis_rm, "[%s%s+8*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32); 
                        break;
                }                
            }            
        }
    }

    return n;
}

/* Дизассемблер полной строки */
int disas(Uint32 address) {

    int bk_eip = eip; /* Чтобы восстановить его в конце */
        eip    = address;
    
    int ereg = default_reg, /* 16 bit */
        emem = default_reg,
        stop = 0,
        elock = 0;

    char dis_pf[8];
    char dis_cmd[32];
    char dis_ops[64];
    char dis_dmp[64];
    char dis_sfx[8];

    int n = 0, i, j, d, opcode = 0;

    // Очистить префикс
    dis_px[0]  = 0; // Сегментный префикс
    dis_pf[0]  = 0; // Префикс
    dis_ops[0] = 0; // Операнды
    dis_dmp[0] = 0; // Минидамп
    dis_sfx[0] = 0; // Суффикс

    /* Декодирование префиксов (до 6 штук) */
    for (i = 0; i < 6; i++) {

        d = fetchb();
        n++;

        switch (d) {
            case 0x0F: opcode |= 0x100; break;
            case 0x26: sprintf(dis_px, "%s", "es:"); break;
            case 0x2E: sprintf(dis_px, "%s", "cs:"); break;
            case 0x36: sprintf(dis_px, "%s", "ss:"); break;
            case 0x3E: sprintf(dis_px, "%s", "ss:"); break;
            case 0x64: sprintf(dis_px, "%s", "fs:"); break;
            case 0x65: sprintf(dis_px, "%s", "gs:"); break;
            case 0x66: ereg = ereg ^ 1; break;
            case 0x67: emem = emem ^ 1; break;
            case 0xf0: elock = 1; break;
            case 0xf2: sprintf(dis_pf, "%s", "repnz "); break;
            case 0xf3: sprintf(dis_pf, "%s", "rep "); break;
            default:   opcode |= d; stop = 1; break;
        }

        if (stop) break;
    }

    int opdec    = ops[ opcode ];
    int hasmodrm = modrm_lookup[ opcode ];

    // Типичная мнемоника
    if (opdec != 0xff) {
        sprintf(dis_cmd, "%s", mnemonics[ opdec ] );
    }

    // Байт имеет modrm
    if (hasmodrm) {

        // Размер по умолчанию 8 бит, если opcode[0] = 1, то либо 16, либо 32
        int regsize = opcode & 1 ? (ereg ? 32 : 16) : 8;
        int swmod   = opcode & 2; // Обмен местами dis_rm и dis_rg

        if (opcode == /* BOUND */ 0x62) regsize = (ereg ? 32 : 16);

        // SWmod
        if (opcode == /* ARPL */ 0x63) swmod = 0;
        if (opcode == /* LEA */ 0x8D || opcode == 0xC4 /* LES */ || opcode == 0xC5) swmod = 1;

        // Regsize
        if (opcode == /* SREG */ 0x8C || opcode == 0x8E ||
            opcode == /* LES */ 0xC4) regsize = (ereg ? 32 : 16);

        // Получить данные из modrm
        n += disas_modrm(regsize, emem ? 0x20 : 0x00);

        // GRP-1 8
        if (opcode == 0x80 || opcode == 0x82) {

            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }

        // GRP-1 16/32
        else if (opcode == 0x81) {

            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );

            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, fetchw()); n += 2;
            }
        }

        // GRP-1 16/32: Расширение 8 бит до 16/32
        else if (opcode == 0x83) {

            int b8 = fetchb(); n++;
            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );

            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, b8 | (b8 & 0x80 ? 0xFFFFFF00 : 0));
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, b8 | (b8 & 0x80 ? 0xFF00 : 0));
            }
        }

        // IMUL imm16
        else if (opcode == 0x69) {

            if (ereg) {
                sprintf(dis_ops, "%s, %s, %08X", dis_rg, dis_rm, fetchd() ); n += 4;
            } else {
                sprintf(dis_ops, "%s, %s, %04X", dis_rg, dis_rm, fetchw() ); n += 2;
            }
        }
        // Групповые инструкции #2: Byte
        else if (opcode == 0xF6) {

            sprintf(dis_cmd, "%s", grp2[ reg ]  );
            if (reg < 2) { /* TEST */
                sprintf(dis_ops, "%s, %02X", dis_rm, fetchb() ); n++;
            } else {
                sprintf(dis_ops, "%s", dis_rm);
            }
        }

        // Групповые инструкции #2: Word/Dword
        else if (opcode == 0xF7) {

            sprintf(dis_cmd, "%s", grp2[ reg ]  );

            if (reg < 2) { /* TEST */
                if (ereg) {
                    sprintf(dis_ops, "%s, %08X", dis_rm, fetchd() ); n += 4;
                } else {
                    sprintf(dis_ops, "%s, %04X", dis_rm, fetchw() ); n += 2;
                }
            } else {
                sprintf(dis_ops, "%s", dis_rm);
            }
        }

        // Групповые инструкции #3: Byte
        else if (opcode == 0xFE) {

            if (reg < 2) {
                sprintf(dis_cmd, "%s", grp3[ reg ]  );
                sprintf(dis_ops, "byte %s", dis_rm );
            } else {
                sprintf(dis_cmd, "(unk)");
            }
        }
        // Групповые инструкции #3: Word / Dword
        else if (opcode == 0xFF) {

            sprintf(dis_cmd, "%s", grp3[ reg ]  );
            sprintf(dis_ops, "%s %s", ereg ? "dword" : "word", dis_rm );

        }

        // Сегментные и POP r/m
        else if (opcode == 0x8C) { sprintf(dis_ops, "%s, %s", dis_rm, regnames[ 0x18 + reg ] ); }
        else if (opcode == 0x8E) { sprintf(dis_ops, "%s, %s", regnames[ 0x18 + reg ], dis_rm ); }
        else if (opcode == 0x8F) { sprintf(dis_ops, "%s %s", ereg ? "dword" : "word", dis_rm ); }

        // GRP-2: imm
        else if (opcode == 0xC0 || opcode == 0xC1) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }
        // 1
        else if (opcode == 0xD0 || opcode == 0xD1) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, 1", dis_rm);
        }
        // cl
        else if (opcode == 0xD2 || opcode == 0xD3) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, cl", dis_rm);
        }
        // mov r/m, i8/16/32
        else if (opcode == 0xC6) {
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }
        else if (opcode == 0xC7) {
            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, fetchw()); n += 2;
            }
        }
        // Обычные
        else {
            sprintf(dis_ops, "%s, %s", swmod ? dis_rg : dis_rm, swmod ? dis_rm : dis_rg);
        }

    } else {

        // [00xx_x10x] АЛУ AL/AX/EAX, i8/16/32
        if ((opcode & 0b11000110) == 0b00000100) {

            if ((opcode & 1) == 0) { // 8 bit
                sprintf(dis_ops, "al, %02X", fetchb()); n++;
            } else if (ereg == 0) { // 16 bit
                sprintf(dis_ops, "ax, %04X", fetchw()); n += 2;
            } else {
                sprintf(dis_ops, "eax, %08X", fetchd()); n += 4;
            }
        }

        // [000x x11x] PUSH/POP
        else if ((opcode & 0b11100110) == 0b00000110) {
            sprintf(dis_ops, "%s", regnames[0x18 + ((opcode >> 3) & 3)] );
        }

        // [0100_xxxx] INC/DEC/PUSH/POP
        else if ((opcode & 0b11100000) == 0b01000000) {
            sprintf(dis_ops, "%s", regnames[ (ereg ? 0x10 : 0x08) + (opcode & 7)] );
        }
        else if (opcode == 0x60 && ereg) { sprintf(dis_cmd, "pushad"); }
        else if (opcode == 0x61 && ereg) { sprintf(dis_cmd, "popad"); }

        // PUSH imm16/32
        else if (opcode == 0x68) {

            if (ereg) {
                sprintf(dis_ops, "%08X", fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%04X", fetchw()); n += 2;
            }
        }
        // PUSH imm8
        else if (opcode == 0x6A) { int t = fetchb(); sprintf(dis_ops, "%04X", t | ((t & 0x80) ? 0xFF00 : 0)); n++; }
        // Jccc rel8
        else if (((opcode & 0b11110000) == 0b01110000) || (opcode >= 0xE0 && opcode <= 0xE3) || (opcode == 0xEB)) {
            int br = fetchb(); n++;
            sprintf(dis_ops, "%08X", (br & 0x80 ? (eip + br - 256) : eip + br ));
        }
        else if (opcode == 0x6c) sprintf(dis_cmd, "insb");
        else if (opcode == 0x6d) sprintf(dis_cmd, ereg ? "insd" : "insw");
        else if (opcode == 0x6e) sprintf(dis_cmd, "outsb");
        else if (opcode == 0x6f) sprintf(dis_cmd, ereg ? "outsd" : "outsw");
        // XCHG ax, r16/32
        else if (opcode > 0x90 && opcode <= 0x97) {
            if (ereg) {
                sprintf(dis_ops, "eax, %s", regnames[ 0x10 + (opcode & 7) ] );
            } else {
                sprintf(dis_ops, "ax, %s", regnames[ 0x8 + (opcode & 7) ] );
            }
        }
        else if (opcode == 0x98 && ereg) sprintf(dis_cmd, "cwde");
        else if (opcode == 0x99 && ereg) sprintf(dis_cmd, "cdq");

        // CALLF/JMPF
        else if (opcode == 0x9A || opcode == 0xEA) {

            int dw = ereg ? fetchd() : fetchw();
            n += (ereg ? 4 : 2);

            int sg = fetchw();
            n += 2;

            if (ereg) sprintf(dis_ops, "%04X:%08X", sg, dw);
                else  sprintf(dis_ops, "%04X:%04X", sg, dw);
        }
        // MOV
        else if (opcode == 0xA0) { sprintf(dis_ops, "al, [%04X]", fetchw()); n += 2; }
        else if (opcode == 0xA1) { sprintf(dis_ops, "ax, [%04X]", fetchw()); n += 2; }
        else if (opcode == 0xA2) { sprintf(dis_ops, "[%04X], al", fetchw()); n += 2; }
        else if (opcode == 0xA3) { sprintf(dis_ops, "[%04X], ax", fetchw()); n += 2; }
        else if (opcode == 0xA8) { sprintf(dis_ops, "al, %02X", fetchb()); n++; }
        // TEST
        else if (opcode == 0xA9) {
            if (ereg) {
                sprintf(dis_ops, "eax, %08X", fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "ax, %04X", fetchw()); n += 2;
            }
        }
        else if ((opcode >= 0xA4 && opcode <= 0xA7) || (opcode >= 0xAA && opcode <= 0xAF)) {
            sprintf(dis_sfx, opcode&1 ? (ereg ? "d" : "w") : "b");
        }
        else if (opcode >= 0xB0 && opcode <= 0xB7) {
            sprintf(dis_ops, "%s, %02x", regnames[ opcode & 7 ], fetchb()); n++;
        }
        else if (opcode >= 0xB8 && opcode <= 0xBF) {
            if (ereg) {
                sprintf(dis_ops, "%s, %08x", regnames[ 0x10 + (opcode & 7) ], fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04x", regnames[ 0x08 + (opcode & 7) ], fetchw()); n += 2;
            }
        }
        // RET / RETF
        else if (opcode == 0xc2 || opcode == 0xca) {
            sprintf(dis_ops, "%04X", fetchw()); n += 2;
        }
        // ENTER
        else if (opcode == 0xC8) {

            int aa = fetchw();
            int ab = fetchb();
            sprintf(dis_ops, "%04x, %02X", aa, ab); n += 3;
        }
        // INT
        else if (opcode == 0xCD) { sprintf(dis_ops, "%02X", fetchb()); n++; }
        // IO/OUT
        else if (opcode == 0xE4) { sprintf(dis_ops, "al, %02X", fetchb()); n++; }
        else if (opcode == 0xE5) { sprintf(dis_ops, "%s, %02X", ereg ? "eax" : "ax", fetchb()); n++; }
        else if (opcode == 0xE6) { sprintf(dis_ops, "%02X, al", fetchb()); n++; }
        else if (opcode == 0xE7) { sprintf(dis_ops, "%02X, %s", fetchb(), ereg ? "eax" : "ax"); n++; }
        else if (opcode == 0xEC) { sprintf(dis_ops, "al, dx"); }
        else if (opcode == 0xED) { sprintf(dis_ops, "%s, dx", ereg ? "eax" : "ax"); }
        else if (opcode == 0xEE) { sprintf(dis_ops, "dx, al"); }
        else if (opcode == 0xEF) { sprintf(dis_ops, "dx, %s", ereg ? "eax" : "ax"); }
        // CALL / JMP rel16
        else if (opcode == 0xE8 || opcode == 0xE9) {
            if (ereg) {

                int m = fetchd(); n += 4;
                    m = (m & 0x80000000) ? m - 0x100000000 : m;
                sprintf(dis_ops, "%08X", m);

            } else {
                int m = fetchw(); n += 2;
                    m = (m & 0x8000) ? m - 0x10000 : m;
                sprintf(dis_ops, "%04X", m + (eip & 0xffff));
            }
        }

    }

    // Максимальное кол-во байт должно быть не более 6
    for (i = 0; i < 6; i++) {
        if (i == 5 && n > 5) {
            sprintf(dis_dmp + 2*i, "..");
        } else if (i < n) {
            sprintf(dis_dmp + 2*i, "%02X", readb(address + i));
        } else {
            sprintf(dis_dmp + 2*i, "  ");
        }
    }

    // Суффикс команды
    sprintf(dis_cmd, "%s%s", dis_cmd, dis_sfx);

    // Дополнить пробелами мнемонику
    for (i = 0; i < OPCODE_PADLEN; i++) {
        if (dis_cmd[i] == 0) {
            for (j = i; j < OPCODE_PADLEN; j++) {
                dis_cmd[j] = ' ';
            }
            dis_cmd[OPCODE_PADLEN - 1] = 0;
            break;
        }
    }

    // Формирование строки вывода
    // EIP, дамп инструкции, команда, операнды
    sprintf(dis_row, "%08X %s %s%s%s %s", address, dis_dmp, elock ? "lock " : "", dis_pf, dis_cmd, dis_ops);

    eip = bk_eip;
    return n;
}
// ---------------------------------------------------------------------

/* Вывод общего дизассемблера */
void update() {

    int i, j, bkeip = eip;
    u64 ea = -1;
    
    // Взять указатель адреса
    int opcode = get_opcode();
    if (modrm_lookup[ opcode ]) {
        get_modrm();                
        ea = cpu_segment * 16 + effective; /* realmode */
    }
    eip = bkeip;
    
    
    linebf(0, 16,  1280, 783, dac[3]); // Общий фон

    linebf(0, 0,   1280, 15,  dac[7]); // Верхняя строка
    print(0, 0, "  \xF0  File  Edit  View  Run  Breakpoints  Data  Options  Window  Help", 0);
    print(0, 0, "  \xF0  F     E     V     R    B            D     O        W       H   ", dac[4]);

    linebf(0, 784, 1280, 799, dac[7]); // Нижняя строка
    print(0, 784, "F1-Help F2-Bkpt F3-Mod F4-Here F5-Zoom F6-Next F7-Trace F8-Step F9-Run F10-Menu", 0);
    print(0, 784, "F1      F2      F3     F4      F5      F6      F7       F8      F9     F10", dac[4]);

    // Обрамления
    // ------------------------------
    print_char(0, 16, 0xc9, dac[15] );    print_char(0,    16*48, 0xc8, dac[15] );
    print_char(8*62, 16, 0xd1, dac[15] ); print_char(8*62, 16*48, 0xcf, dac[15] );
    print_char(8*75, 16, 0xd1, dac[15] ); 
    print_char(8*79, 16, 0xcb, dac[15] );  print_char(8*79, 16*48, 0xca, dac[15] );
    print_char(8*159, 16, 0xbb, dac[15] ); print_char(8*159, 16*48, 0xbc, dac[15] );    
    
    for (i = 1; i < 159; i++) {

        if (i == 62 || i == 79) continue;

        print_char(8*i, 16, 0xcd, dac[15] );
        print_char(8*i, 16*48, 0xcd, dac[15] );
    }

    // Вертикальные линии
    for (i = 2; i < 48; i++) {

        print_char(0,    16*i, 0xba, dac[15] );
        print_char(62*8, 16*i, 0xb3, dac[15] );
        if (i < 18) print_char(75*8, 16*i, 0xb3, dac[15] );
        print_char(79*8, 16*i, 0xba, dac[15] );
        print_char(159*8, 16*i, 0xba, dac[15] );
    }
    
    print(62*8, 18*16, "\xC3\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC4\xC1\xC4\xC4\xC4\xB6", 0xFFFFFF);

    // Сделать строку перемотки
    //if (i > 2 && i < 47)
    //print_char(62*8, 16*i, 0xb1, dac[1] );
    // ------------------------------

    /* Вывод флагов */
    print(76*8, 16*2, eflags & 0x001 ? "c=1" : "c=0", dac[0]);
    print(76*8, 16*3, eflags & 0x040 ? "z=1" : "z=0", dac[0]);
    print(76*8, 16*4, eflags & 0x080 ? "s=1" : "s=0", dac[0]);
    print(76*8, 16*5, eflags & 0x800 ? "o=1" : "o=0", dac[0]);
    print(76*8, 16*6, eflags & 0x004 ? "p=1" : "p=0", dac[0]);
    print(76*8, 16*7, eflags & 0x010 ? "a=1" : "a=0", dac[0]);
    print(76*8, 16*8, eflags & 0x200 ? "i=1" : "i=0", dac[0]);
    print(76*8, 16*9, eflags & 0x400 ? "d=1" : "d=0", dac[0]);
    print(76*8, 16*10, eflags & 0x100 ? "t=1" : "t=0", dac[0]);

    /* Вывод регистров */
    sprintf(tmps, "eax %08x", eax); print(63*8, 16*2, tmps, dac[ dis_eax == eax ? 0 : 15 ]);
    sprintf(tmps, "ebx %08x", ebx); print(63*8, 16*3, tmps, dac[ dis_ebx == ebx ? 0 : 15 ]);
    sprintf(tmps, "ecx %08x", ecx); print(63*8, 16*4, tmps, dac[ dis_ecx == ecx ? 0 : 15 ]);
    sprintf(tmps, "edx %08x", edx); print(63*8, 16*5, tmps, dac[ dis_edx == edx ? 0 : 15 ]);
    sprintf(tmps, "esp %08x", esp); print(63*8, 16*6, tmps, dac[ dis_esp == esp ? 0 : 15 ]);
    sprintf(tmps, "ebp %08x", ebp); print(63*8, 16*7, tmps, dac[ dis_ebp == ebp ? 0 : 15 ]);
    sprintf(tmps, "esi %08x", esi); print(63*8, 16*8, tmps, dac[ dis_esi == esi ? 0 : 15 ]);
    sprintf(tmps, "edi %08x", edi); print(63*8, 16*9, tmps, dac[ dis_edi == edi ? 0 : 15 ]);
    sprintf(tmps, "eip %08x", eip); print(63*8, 16*10, tmps, dac[ dis_eip == eip ? 0 : 15 ]);

    /* Сегментные */
    sprintf(tmps, " es %04x", es); print(63*8, 16*12, tmps, dac[0]);
    sprintf(tmps, " cs %04x", cs); print(63*8, 16*13, tmps, dac[0]);
    sprintf(tmps, " ds %04x", ds); print(63*8, 16*14, tmps, dac[0]);
    sprintf(tmps, " ss %04x", ss); print(63*8, 16*15, tmps, dac[0]);
    sprintf(tmps, " fs %04x", fs); print(63*8, 16*16, tmps, dac[0]);
    sprintf(tmps, " gs %04x", gs); print(63*8, 16*17, tmps, dac[0]);

    int current = addr_start;

    print(8*91, 16*2, "0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F", dac[0]);
    
    for (i = 0; i < 16; i++) {
        
        sprintf(dis_row, "%08X", dump_start + i*16 );
        print(8*81, 16*(3 + i), dis_row, dac[0]);
        
        for (j = 0; j < 16; j++) {
            
            int addr = dump_start + i*16 + j ;
            int ch = RAM[ addr ];
            sprintf(dis_row, "%02X", ch );
                        
            print(8*(90 + 3*j), 16*(3 + i), dis_row, dac[ addr == ea ? 14 : 0 ]);
            print_char(8*(138 + j), 16*(3 + i), ch, dac[ 0] );
            
        }
    }

    /* Вывод отладчика */
    for (i = 0; i < 46; i++) {

        int yc = 16*(i + 2);
        int dis_color = dac[0];

        /* Текущая линия выбрана */
        if (cursor_at == current) {

            linebf(8*1, yc, 8*62 - 1, 16*(i + 2) + 15, dac[1]);
            dis_color = dac[15];
        }

        if (eip == current) {
            print(8*10, yc, "\x10", cursor_at == current ? 0xFFFFFF : 0);
        } 
        
        int n = disas(current);
        current += n;

        print(16, 16*(i + 2), dis_row, dis_color);                   
    }

    SDL_Flip(sdl_screen);
}
