
// В основно для текстового режима
#define SCRWIDTH    640 * 2
#define SCRHEIGHT   400 * 2

/*
 * Видеовывод
 */
 
#include "fonts.h"

/* Текущий видеорежим */
int     param_video_mode = 0;
int     dac[16];

SDL_Surface * sdl_screen;

/* Инициализация */
void init_video() {
    
    SDL_EnableUNICODE(1);
    
    sdl_screen = SDL_SetVideoMode(SCRWIDTH, SCRHEIGHT, 32, 0); 
    SDL_WM_SetCaption( "Упрощенный эмулятор IA32", 0 );      
    
    dac[0]  = 0x000000;
    dac[1]  = 0x0000aa;
    dac[2]  = 0x00aa00;
    dac[3]  = 0x00aaaa;
    dac[4]  = 0xaa0000;
    dac[5]  = 0xaa0088;
    dac[6]  = 0xaaaa00;
    dac[7]  = 0xaaaaaa;
    dac[8]  = 0x888888;
    dac[9]  = 0x0000ff;
    dac[10] = 0x00ff00;
    dac[11] = 0x00ffff;
    dac[12] = 0xff0000;
    dac[13] = 0xff00ff;
    dac[14] = 0xffff00;
    dac[15] = 0xffffff;
    
}

/* Установка точки */
void pset(int x, int y, unsigned int color) {    
    if (x >= 0 && x < SCRWIDTH && y >= 0 && y < SCRHEIGHT)
        ((Uint32*)sdl_screen->pixels)[ SCRWIDTH*y + x ] = color;
}

void print_char(int x, int y, unsigned char sym, int color) {
    
    int i, j, ch;
    for (i = 0; i < 16; i++) {
            
        ch = font[16*sym + i];
        for (j = 0; j < 8; j++) 
            if (ch & (1 << j))
                pset(x + 7 - j, y + i, color);             
    }    
}

/* Пропечатать фонт */
void print(int x, int y, char* source, int color) {
    
    int sym;
    char* s = source;

    while (*s) {
        
        sym = *s; s++;
        
        print_char(x, y, sym, color);
        
        x += 8;
        if (x >= SCRWIDTH) {
            x  = 0;
            y += 16;
        }
    }
    
}

/* Line BF (закрашенная) */
void linebf(int x1, int y1, int x2, int y2, int color) {
    
    int i, j;
    for (i = y1; i <= y2; i++)
    for (j = x1; j <= x2; j++) 
        pset(j, i, color);
    
}

/* Обновить видеофрейм */
void redraw_graphics() {
    
    int i, j, c;
    
    linebf(0, 0, SCRWIDTH, SCRHEIGHT, 0);
    
    // RAM
    for (i = 0; i < 800; i++) {
        for (j = 0; j < 1280; j++) {
            
            c = RAM[ 0x300000 + 320 * (i >> 1) + (j >> 2) ];
            c = (j & 2) ? (c >> 4) : c;
            
            pset(j, i, dac[c & 0x0f]);                                    
        }
    }
        
    SDL_Flip(sdl_screen);    
}

/* Текстовый видеорежим */
void redraw_textmode() {
    
    int i, j, a, b, c, s, k, bit;    
    
    for (i = 0; i < 25; i++) { 
        for (j = 0; j < 80; j++) {        
            for (a = 0; a < 16; a++) {
                
                s = 16 * RAM[ 0xB8000 + i*160 + j*2 + 0 ];
                c = RAM[ 0xB8000 + i*160 + j*2 + 1 ];
                s = font[ s + a ];
                
                for (b = 0; b < 8; b++) {
                    
                    // Определить бит
                    bit = (s & (1 << (7 - b))) ? 1 : 0;
                    
                    // Эмуляция мерцания символов                   
                    if (bit) {
                        bit ^= ((c & 0x80) && fps < 25);
                    } 

                    k = bit ? (c & 0xf) : (c >> 4) & 0x07;
                    k = dac[k];
                    
                    pset(2*(8*j + b)+ 0, 2*(16*i + a) + 0, k);
                    pset(2*(8*j + b)+ 1, 2*(16*i + a) + 0, k);
                    pset(2*(8*j + b)+ 1, 2*(16*i + a) + 1, k);
                    pset(2*(8*j + b)+ 0, 2*(16*i + a) + 1, k);                                    
                }
            }            
        }    
    }    
    
    SDL_Flip(sdl_screen);
}

/* Полное обновление (или нет) экрана в зависимости от выбранного видеорежима */
void redraw() {
    
    // SDL_GetTicks();
    switch (param_video_mode) {
        
        case 1: redraw_textmode(); break;
        case 2: redraw_graphics(); break;
        // EGA/CGA    
    }
}
