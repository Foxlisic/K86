void redraw_textmode();
void update();
void step();
void dis_save_state();

// ---------------------------------------------------------------------

#define u64 uint64_t

/* cpu.c */
Uint32 eflags, pflags;      /* pflags для отладчика */

Uint32 eax, esp, ecx, ebp;
Uint32 ebx, esi, edx, edi;
Uint32 eip;

Uint32 dis_eax, dis_ecx, dis_edx, dis_ebx;
Uint32 dis_esp, dis_ebp, dis_esi, dis_edi;
Uint32 dis_eip, dis_es, dis_cs, dis_ds, dis_ss, dis_fs, dis_gs;

Uint16 es, cs, ds, ss, fs, gs;
Uint8  processor_mode;      /* 0 - realmode, 1 - protected mode */
Uint8  default_reg;

int  addr_start;        /* Стартовый адрес дизассемблера */
int  dump_start;        /* Стартовый адрес дампа */
int  cursor_at;         /* Курсор (синяя полоска) */

/* Работа с диском IDE 0:0 */
FILE * disk_file;

// ---------------------------------------------------------------------

const Uint8 modrm_lookup[512] = {
    
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
    /* F0 */ 0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,
    
    // Ext -- todo
    /* 00 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 10 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 20 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 30 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 40 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 50 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 60 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 70 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 80 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* 90 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* A0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* B0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* C0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* D0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* E0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    /* F0 */ 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        
};
