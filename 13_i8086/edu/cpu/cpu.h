#define byte        unsigned char       // 8
#define word        unsigned short      // 16
#define uint        unsigned int        // 32
#define ulong       unsigned long long  // 64

// Флаги процессора
byte flag_over;
byte flag_dir;
byte flag_int;
byte flag_trap;
byte flag_sign;
byte flag_zero;
byte flag_aux;
byte flag_parity;
byte flag_carry;

// Память
byte memory[1024*1024 + 65536 + 256];

// Регистры
word AX, CX, DX, BX, SP, BP, SI, DI;
word ES, CS, SS, DS;
word IP;

// Байт modrm
byte modrm;
byte modrm_mod;
byte modrm_reg;
byte modrm_r_m;
word modrm_ea;
word segment;

// Декодирование опкода
byte opcode;
byte i_rep;
byte i_seg_over;
byte i_seg_val;

// ---------------------------------------------------------------------

void pc_regs();
void pc_dump(int);
