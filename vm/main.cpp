#include <iostream>
#include <SDL2/SDL.h>

#include "main.h"
#include "disasm.cc"
#include "portable86.cc"

class machine : public portable86
{
protected:

    uint8_t* memory;
    disasm*  dis;

    // SDL2 Окно
    SDL_Surface*        screen_surface;
    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_PixelFormat*    sdl_pixel_format;
    SDL_Texture*        sdl_screen_texture;
    SDL_Event           evt;
    Uint32*             screen_buffer;

    int scale           = 2;
    int config_debugger = 0;
    int key_last        = 0;
    int key_shift       = 0;
    int key_trigger     = 0;
    int flash_cnt       = 0;
    int flash           = 0;
    int cursor_x        = 0;
    int cursor_y        = 0;
    uint8_t millis      = 0;

public:

    machine() : portable86()
    {
        memory      = (uint8_t*) malloc(1024*1024);
        dis         = new disasm(memory);
        config_debugger = 0;
        key_trigger = 0;
        key_last    = 0;
        key_shift   = 0;
    }

    ~machine()
    {
        free(memory);
        free(screen_buffer);

        SDL_DestroyTexture(sdl_screen_texture);
        SDL_FreeFormat(sdl_pixel_format);
        SDL_DestroyRenderer(sdl_renderer);
        SDL_DestroyWindow(sdl_window);
    }

    // Чтение из порта
    uint8_t ioread(uint16_t a)
    {
        switch (a)
        {
            case 0x10: return cursor_x;
            case 0x11: return cursor_y;
            case 0x60: return key_last;
            case 0x62: return millis;
            case 0x64: if (key_trigger) { key_trigger = 0; return 1; } return 0; break;
        }

        return 0xFF;
    };

    // Запись в порт
    void iowrite(uint16_t a, uint8_t b)
    {
        switch (a)
        {
            case 0x10: cursor_x = a; break;
            case 0x11: cursor_y = a; break;
        }
    };

    // Чтение из памяти
    uint8_t readmemb(uint32_t a)
    {
        return memory[a & 0xFFFFF];
    };

    // Запись в память
    void writememb(uint32_t a, uint8_t b)
    {
        memory[a & 0xFFFFF] = b;
    };

    // -------------------------------------------------------------------------

    void load(int argc, char** argv)
    {
        int  i = 1;

        FILE* fp = NULL;

        // Скопировать шрифты по умолчанию
        for (int i = 0; i < 4096; i++) memory[0xB9000 + i] = font[i];

        while (i < argc) {

            if (argv[i][0] == '-') {

                switch (argv[i][1]) {

                    case 'd': config_debugger = 1; break;
                }

            } else {

                if (fp = fopen(argv[i], "rb")) {

                    fseek(fp, 0, SEEK_END);
                    int size = ftell(fp);
                    fseek(fp, 0, SEEK_SET);
                    fread(memory + 0x100000 - size, 1, size, fp);
                    fclose(fp);
                }

            }

            i++;
        }
    }

    void create()
    {
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window            = SDL_CreateWindow("Intel 80386SX: Hyper Threading Technologies AMI BIOS Rev.1253",
                                SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, scale*640, scale*400, SDL_WINDOW_SHOWN);
        sdl_renderer          = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer         = (Uint32*) malloc(640*400*sizeof(Uint32));
        sdl_screen_texture    = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, 640, 400);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);
    }

    int run()
    {
        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = scale*640;
        dstRect.h = scale*400;

        int key;

        for (;;) {

            // Прием событий
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Событие выхода из приложения
                    case SDL_QUIT: return 0;

                    // Нажатие кнопки на клавиатуре записывает новые данные
                    case SDL_KEYDOWN:

                        key = kbd(evt, key_shift);
                        if (key == key_LSHIFT) {
                            key_shift = 1;
                        } else {
                            key_last = key;
                            key_trigger = 1;
                        }

                        break;

                    // Отслеживание SHIFT
                    case SDL_KEYUP:

                        key = kbd(evt);
                        if (key == key_LSHIFT) {
                            key_shift = 0;
                        }

                        break;
                }
            }

            // Эмулятор
            Uint32 ticks = SDL_GetTicks();

            // 60 кадров в секунду, инструкция примерно по 4Т
            for (int i = 0; i < (416666/4); i++) {

                if (config_debugger && inhlt == 0) x86deb();
                if (i % 8680 == 0) millis++;

                x86run(1);
            }

            refresh();

            Uint32 freet = 16 - (SDL_GetTicks() - ticks);

            // После завершения фрейма обновить экран
            SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, 640*sizeof(Uint32));
            SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
            SDL_RenderClear         (sdl_renderer);
            SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
            SDL_RenderPresent       (sdl_renderer);

            // Расчет остатков от времени выполнения
            SDL_Delay(freet < 1 ? 1 : (freet > 16 ? 16 : freet));
        }
    }

    // Отладка
    void x86deb()
    {
        dis->disassemble(seg_cs + ip);
        printf("%04X:%04X %s\n", segs[SEG_CS], ip, dis->dis_row);
    }

    // Установка точки
    void pset(int x, int y, Uint32 cl)
    {
        if (x < 0 || y < 0 || x >= 640 || y >= 400) {
            return;
        } else {
            screen_buffer[640*y + x] = cl;
        }
    }

    // Обновление экранной области [cyclone-3]
    void refresh()
    {
        flash_cnt = (flash_cnt + 1) % 15;
        if (flash_cnt == 0) flash = !flash;

        for (int i = 0; i < 25; i++)
        for (int j = 0; j < 80; j++) {

            int     a = 0xB8000 + 2*j + 160*i;
            uint8_t b = memory[a],
                    c = memory[a + 1];

            for (int y = 0; y < 16; y++) {

                int d = memory[0xB9000 + 16*b + y];
                for (int x = 0; x < 8; x++) {

                    int mask = d & (0x80 >> x);
                    int cl = mask || (cursor_x == j && cursor_y == i && flash && y >= 14) ? c & 15 : c >> 4;

                    pset(j*8 + x, i*16 + y, dac[cl]);
                }
            }
        }
    }

    // Нажатие на клавишу. SH=1 если нажат SHIFT
    uint8_t kbd(SDL_Event event, int sh = 0)
    {
        // Получение ссылки на структуру с данными о нажатой клавише */
        SDL_KeyboardEvent * eventkey = & event.key;

        int xt = 0;
        int k = eventkey->keysym.sym;

        switch (k)
        {
            /* A */   case SDLK_a: xt = sh ? 'A' : 'a'; break;
            /* B */   case SDLK_b: xt = sh ? 'B' : 'b'; break;
            /* C */   case SDLK_c: xt = sh ? 'C' : 'c'; break;
            /* D */   case SDLK_d: xt = sh ? 'D' : 'd'; break;
            /* E */   case SDLK_e: xt = sh ? 'E' : 'e'; break;
            /* F */   case SDLK_f: xt = sh ? 'F' : 'f'; break;
            /* G */   case SDLK_g: xt = sh ? 'G' : 'g'; break;
            /* H */   case SDLK_h: xt = sh ? 'H' : 'h'; break;
            /* I */   case SDLK_i: xt = sh ? 'I' : 'i'; break;
            /* J */   case SDLK_j: xt = sh ? 'J' : 'j'; break;
            /* K */   case SDLK_k: xt = sh ? 'K' : 'k'; break;
            /* L */   case SDLK_l: xt = sh ? 'L' : 'l'; break;
            /* M */   case SDLK_m: xt = sh ? 'M' : 'm'; break;
            /* N */   case SDLK_n: xt = sh ? 'N' : 'n'; break;
            /* O */   case SDLK_o: xt = sh ? 'O' : 'o'; break;
            /* P */   case SDLK_p: xt = sh ? 'P' : 'p'; break;
            /* Q */   case SDLK_q: xt = sh ? 'Q' : 'q'; break;
            /* R */   case SDLK_r: xt = sh ? 'R' : 'r'; break;
            /* S */   case SDLK_s: xt = sh ? 'S' : 's'; break;
            /* T */   case SDLK_t: xt = sh ? 'T' : 't'; break;
            /* U */   case SDLK_u: xt = sh ? 'U' : 'u'; break;
            /* V */   case SDLK_v: xt = sh ? 'V' : 'v'; break;
            /* W */   case SDLK_w: xt = sh ? 'W' : 'w'; break;
            /* X */   case SDLK_x: xt = sh ? 'X' : 'x'; break;
            /* Y */   case SDLK_y: xt = sh ? 'Y' : 'y'; break;
            /* Z */   case SDLK_z: xt = sh ? 'Z' : 'z'; break;
            /* 0 */   case SDLK_0: xt = sh ? ')' : '0'; break;
            /* 1 */   case SDLK_1: xt = sh ? '!' : '1'; break;
            /* 2 */   case SDLK_2: xt = sh ? '@' : '2'; break;
            /* 3 */   case SDLK_3: xt = sh ? '#' : '3'; break;
            /* 4 */   case SDLK_4: xt = sh ? '$' : '4'; break;
            /* 5 */   case SDLK_5: xt = sh ? '%' : '5'; break;
            /* 6 */   case SDLK_6: xt = sh ? '^' : '6'; break;
            /* 7 */   case SDLK_7: xt = sh ? '&' : '7'; break;
            /* 8 */   case SDLK_8: xt = sh ? '*' : '8'; break;
            /* 9 */   case SDLK_9: xt = sh ? '(' : '9'; break;

            // Клавиши отдельные
            /* ` */   case SDLK_BACKQUOTE:      xt = sh ? '~' : '`'; break;
            /* - */   case SDLK_MINUS:          xt = sh ? '_' : '-'; break;
            /* = */   case SDLK_EQUALS:         xt = sh ? '+' : '='; break;
            /* \ */   case SDLK_BACKSLASH:      xt = sh ? '|' : '\\'; break;
            /* [ */   case SDLK_LEFTBRACKET:    xt = sh ? '{' : '['; break;
            /* ] */   case SDLK_RIGHTBRACKET:   xt = sh ? '}' : ']'; break;
            /* ; */   case SDLK_SEMICOLON:      xt = sh ? ':' : ';'; break;
            /* ' */   case SDLK_QUOTE:          xt = sh ? '|' : '\''; break;
            /* , */   case SDLK_COMMA:          xt = sh ? '<' : ','; break;
            /* . */   case SDLK_PERIOD:         xt = sh ? '>' : '.'; break;
            /* / */   case SDLK_SLASH:          xt = sh ? '?' : '/'; break;
            /* F1  */ case SDLK_F1:             xt = key_F1; break;
            /* F2  */ case SDLK_F2:             xt = key_F2; break;
            /* F3  */ case SDLK_F3:             xt = key_F3; break;
            /* F4  */ case SDLK_F4:             xt = key_F4; break;
            /* F5  */ case SDLK_F5:             xt = key_F5; break;
            /* F6  */ case SDLK_F6:             xt = key_F6; break;
            /* F7  */ case SDLK_F7:             xt = key_F7; break;
            /* F8  */ case SDLK_F8:             xt = key_F8; break;
            /* F9  */ case SDLK_F9:             xt = key_F9; break;
            /* F10 */ case SDLK_F10:            xt = key_F10; break;
            /* F11 */ case SDLK_F11:            xt = key_F11; break;
            /* F12 */ case SDLK_F12:            xt = key_F12; break;
            /* bs */  case SDLK_BACKSPACE:      xt = key_BS; break;     // Back Space
            /* sp */  case SDLK_SPACE:          xt = ' '; break;        // Space
            /* tb */  case SDLK_TAB:            xt = key_TAB; break;    // Tab
            /* ls */  case SDLK_LSHIFT:         xt = key_LSHIFT; break; // Left Shift
            /* la */  case SDLK_LALT:           xt = key_LALT;  break;  // Left Ctrl
            /* lc */  case SDLK_LCTRL:          xt = key_LCTRL; break;  // Left Alt
            /* en */  case SDLK_RETURN:         xt = key_ENTER; break;  // Enter
            /* es */  case SDLK_ESCAPE:         xt = key_ESC; break;    // Escape

            /* UP  */  case SDLK_UP:            xt = key_UP; break;
            /* RT  */  case SDLK_RIGHT:         xt = key_RT; break;
            /* DN  */  case SDLK_DOWN:          xt = key_DN; break;
            /* LF  */  case SDLK_LEFT:          xt = key_LF; break;
            /* Home */ case SDLK_HOME:          xt = key_HOME; break;
            /* End  */ case SDLK_END:           xt = key_END; break;
            /* PgUp */ case SDLK_PAGEUP:        xt = key_PGUP; break;
            /* PgDn */ case SDLK_PAGEDOWN:      xt = key_PGDN; break;
            /* Del  */ case SDLK_DELETE:        xt = key_DEL; break;
            /* Ins  */ case SDLK_INSERT:        xt = key_INS; break;

            default: return 0;
        }

        /* Получить скан-код клавиш */
        return xt;
    }

} comp;

int main(int argc, char** argv)
{
    comp.load(argc, argv);
    comp.create();
    comp.run();

    return 0;
}
