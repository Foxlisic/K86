const static int dac[16] =
{
    0x000000, 0x0000aa, 0x00aa00, 0x00aaaa, 0xaa0000, 0xaa00aa, 0xaa5500, 0xaaaaaa, // 0
    0x555555, 0x5555ff, 0x55ff55, 0x55ffff, 0xff5555, 0xff55ff, 0xffff55, 0xffffff, // 8
};


enum KBASCII
{
    key_UP          = 0x01,
    key_DN          = 0x02,
    key_LF          = 0x03,
    key_RT          = 0x04,
    key_HOME        = 0x05,
    key_END         = 0x06,
    key_PGUP        = 0x07,
    key_BS          = 0x08,
    key_TAB         = 0x09,
    key_PGDN        = 0x0A,
    key_DEL         = 0x0B,
    key_INS         = 0x0C,
    key_ENTER       = 0x0D,
    key_NL          = 0x0E,
    key_CAP         = 0x0F,     // Caps Shift
    key_LSHIFT      = 0x10,
    key_LCTRL       = 0x11,
    key_LALT        = 0x12,
    key_LWIN        = 0x13,
    key_RSHIFT      = 0x14,
    key_RWIN        = 0x15,
    key_MENU        = 0x16,     // Кнопка Меню
    key_SCL         = 0x17,     // Scroll Lock
    key_NUM         = 0x18,     // Num Pad
    key_ESC         = 0x1B,     // Escape

    key_F1          = 0x80,
    key_F2          = 0x81,
    key_F3          = 0x82,
    key_F4          = 0x83,
    key_F5          = 0x84,
    key_F6          = 0x85,
    key_F7          = 0x86,
    key_F8          = 0x87,
    key_F9          = 0x88,
    key_F10         = 0x89,
    key_F11         = 0x8A,
    key_F12         = 0x8B,
};

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
            case 0x60: return key_last;
            case 0x64: if (key_trigger) { key_trigger = 0; return 1; } return 0; break;
        }

        return 0xFF;
    };

    // Запись в порт
    void iowrite(uint16_t a, uint8_t b)
    {
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
        for (int i = 0; i < 4096; i++) memory[0xC800 + i] = font[i];

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

            for (int i = 0; i < 3500000; i++) {

                if (config_debugger && inhlt == 0) x86deb();
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
        for (int i = 0; i < 25; i++)
        for (int j = 0; j < 80; j++) {

            int     a = 0xB800 + 2*j + 160*i;
            uint8_t b = memory[a],
                    c = memory[a + 1];

            for (int y = 0; y < 16; y++) {

                int d = memory[0xC800 + 16*b + y];
                for (int x = 0; x < 8; x++) {
                    pset(j*8 + x, i*16 + y, dac[d & (0x80 >> x) ? c & 15 : c >> 4]);
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

//            /* ` */   case 0x31: xt = sh ? '~' : '`'; break;
            /* - */   case 0x14: xt = sh ? '_' : '-'; break;
            /* = */   case 0x15: xt = sh ? '+' : '='; break;
//            /* \ */   case 0x33: xt = sh ? '|' : '\\'; break;
            /* [ */   case 0x22: xt = sh ? '{' : '['; break;
            /* ] */   case 0x23: xt = sh ? '}' : ']'; break;
            /* ; */   case 0x2f: xt = sh ? ':' : ';'; break;
//            /* ' */   case 0x30: xt = sh ? '|' : '\''; break;
            /* , */   case 0x3b: xt = sh ? '<' : ','; break;
            /* . */   case 0x3c: xt = sh ? '>' : '.'; break;
            /* / */   case 0x3d: xt = sh ? '?' : '/'; break;

            /* F1  */ case 67: xt = key_F1; break;
            /* F2  */ case 68: xt = key_F2; break;
            /* F3  */ case 69: xt = key_F3; break;
            /* F4  */ case 70: xt = key_F4; break;
            /* F5  */ case 71: xt = key_F5; break;
            /* F6  */ case 72: xt = key_F6; break;
            /* F7  */ case 73: xt = key_F7; break;
            /* F8  */ case 74: xt = key_F8; break;
            /* F9  */ case 75: xt = key_F9; break;
            /* F10 */ case 76: xt = key_F10; break;
            /* F11 */ case 95: xt = key_F11; break;
            /* F12 */ case 96: xt = key_F12; break;

            /* bs */  case 0x16: xt = key_BS; break;     // Back Space
            /* sp */  case 0x41: xt = 0x20; break;       // Space
            /* tb */  case 0x17: xt = key_TAB; break;    // Tab
       //     /* ls */  case 0x32: xt = key_LSHIFT; break; // Left Shift
            /* lc */  case 0x25: xt = key_LALT;  break;  // Left Ctrl
            /* la */  case 0x40: xt = key_LCTRL; break;  // Left Alt
            /* en */  case 0x24: xt = key_ENTER; break;  // Enter
            /* es */  case 0x09: xt = key_ESC; break;    // Escape
            /* es */  case 0x08: xt = key_ESC; break;

            // ---------------------------------------------
            // Специальные (не так же как в реальном железе)
            // ---------------------------------------------

       //     /* UP  */  case 0x6F: xt = key_UP; break;
       //     /* RT  */  case 0x72: xt = key_RT; break;
       //     /* DN  */  case 0x74: xt = key_DN; break;
       //     /* LF  */  case 0x71: xt = key_LF; break;
       //     /* Home */ case 0x6E: xt = key_HOME; break;
       //     /* End  */ case 0x73: xt = key_END; break;
       //     /* PgUp */ case 0x70: xt = key_PGUP; break;
       //     /* PgDn */ case 0x75: xt = key_PGDN; break;
       //     /* Del  */ case 0x77: xt = key_DEL; break;
       //     /* Ins  */ case 0x76: xt = key_INS; break;
       //     /* NLock*/ case 0x4D: xt = key_NL; break;

            default: return 0;
        }

        /* Получить скан-код клавиш */
        return xt;
    }


};
