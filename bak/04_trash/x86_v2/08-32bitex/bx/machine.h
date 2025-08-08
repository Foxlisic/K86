#define SDL_MAIN_HANDLED

#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "env.h"
#include "font.h"

#define MAX_MEMORY (64*1024*1024)

enum RegisterNames {

    // 32 bit
    eax = 0, ecx = 1, edx = 2, ebx = 3,
    esp = 4, ebp = 5, esi = 6, edi = 7,

    // 16 bit
    ax = 0, cx = 1, dx = 2, bx = 3,
    sp = 4, bp = 5, si = 6, di = 7,

    // 8 bit
    al = 0, cl = 1, dl = 2, bl = 3,
    ah = 4, ch = 5, dh = 2, bh = 7,

    // segment
    es = 0, cs = 1, ss = 2, ds = 3,
    fs = 4, gs = 5,
};

enum FlagsNames {

    C_FLAG = 0x0001,
    P_FLAG = 0x0004,
    A_FLAG = 0x0010,
    Z_FLAG = 0x0040,
    S_FLAG = 0x0080,
    T_FLAG = 0x0100,
    I_FLAG = 0x0200,
    D_FLAG = 0x0400,
    O_FLAG = 0x0800
};

// ---------------------------------------------------------------------

// Объявляет переменные _s(sign), _c(carry), _m(max)
#define sizing_alu \
    dword _s = size ? (opsize ? 0x80000000 : 0x8000) : 0x80;\
    qword _c = _s << 1;\
    qword _m = _c - 1;

// ---------------------------------------------------------------------

class machine {

protected:

    SDL_Surface*        screen_surface = NULL;
    SDL_Window*         sdl_window = NULL;
    SDL_Renderer*       sdl_renderer;
    SDL_PixelFormat*    sdl_pixel_format;
    SDL_Texture*        sdl_screen_texture;
    SDL_Event           event;

    Uint32* screen_buffer;
    Uint32  width, height;
    Uint32  frame_length;
    Uint32  frame_prev_ticks;

    int     _scale, _width, _height, _frameid;
    int     kb_code, kb_trigger;
    
    // Отладчик
    int     first_regdump;

    // ---------------------
    // Процессор
    // ---------------------

    byte*   memory;
    byte    parity[256];
    dword   regs[8];            // Регистры общего назначения
    word    segs[8];            // Сегменты
    dword   eip;
    word    eflags;
    dword   eipstart;
    byte    halt;
    dword   gdt_offset;

    byte    default_size, stack_size;
    word    opcode;
    word    modrm, modrm_rm, modrm_reg, modrm_mod;
    word    segment;
    dword   ea;
    dword   op1, op2;
    byte    rep, opsize, adsize, overseg;

public:

     machine(int w, int h, int scale, int fps);
    ~machine();

    // -----------------------------------------------------------------
    // Процессор
    // -----------------------------------------------------------------

    void    reset();
    int     halted();
    
    void    set_of(dword x);
    void    set_sf(dword x);
    void    set_zf(dword x);
    void    set_af(dword x);
    void    set_pf(dword x);
    void    set_cf(dword x);
    int     get_cf();
    void    set_szp(qword r, qword c);

    byte    read_byte (dword address);
    word    read_word (dword address);
    dword   read_dword(dword address);

    void    write_byte (dword address, byte data);
    void    write_word (dword address, word data);
    void    write_dword(dword address, dword data);

    byte    fetch_byte();
    word    fetch_word();
    dword   fetch_dword();
    dword   fetch_gv();     
    dword   fetch_modrm();

    dword   phys_addr(word selector, dword address);
    void    load_seg(byte segment_id, word data);
    void    load_eip(dword data);
    void    do_retf(dword imm);
    void    do_enter();
    dword   get_offset();

    byte    get_eb();
    byte    get_rb();
    dword   get_ev();
    dword   get_rv();
    void    put_eb(byte data);
    void    put_rb(byte data);
    void    put_ev(dword data);
    void    put_rv(dword data);

    byte    get_reg8(int reg_id);
    dword   get_regv(int reg_id);
    void    put_reg8(int reg_id, byte data);
    void    put_regv(int reg_id, dword data);
    void    put_reg16(int reg_id, dword data, int size);
    
    void    push(dword v, byte size);
    dword   pop(byte size);
    byte    condition(int num);
    dword   group_alu(int mode, dword a, dword b, int size);
    dword   groupshift(byte mode, byte bit, dword temp, byte n);
    void    do_ret(dword imm);
    void    do_iret();
    void    do_jmp_far(word new_cs, dword new_eip);
    void    do_call_far(word new_cs, dword new_eip);
    void    interrupt(int id);

    void    ud();
    word    get_opcode();
    void    step();

    // АЛУ
    dword   do_add(dword op1, dword op2, byte size);
    dword   do_adc(dword op1, dword op2, byte size);
    dword   do_sub(dword op1, dword op2, byte size);
    dword   do_sbb(dword op1, dword op2, byte size);
    dword   do_and(dword op1, dword op2, byte size);
    dword   do_xor(dword op1, dword op2, byte size);
    dword   do_or (dword op1, dword op2, byte size);
    void    daa();
    void    das();
    void    aaa();
    void    aas();
    void    aam();
    void    aad();
    qword_s get_signed_qword(dword a, int size);
    qword   imul16(dword a, dword b);
    void    iowrite(word address, byte data);
    byte    ioread(word address);

    // -----------------------------------------------------------------
    // Обработка окна
    // -----------------------------------------------------------------

    int     createwin(int w, int h, int scale, const char* name, int fps);
    int     handler ();
    void    update  ();
    void    destroy ();
    int     get_kbcode();

    // -----------------------------------------------------------------
    // Рисование в буфере
    // -----------------------------------------------------------------

    void    pset(int x, int y, Uint32 cl);
    void    print_char(int x, int y, unsigned char ch, int attr);
    void    repaint_text();

    // -----------------------------------------------------------------
    // Машина
    // -----------------------------------------------------------------

    int     init(int argc, char* argv[]);
    void    regdump();
};
