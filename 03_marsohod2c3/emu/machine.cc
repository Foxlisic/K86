const static int dac[16] =
{
    0x000000, 0x0000aa, 0x00aa00, 0x00aaaa, 0xaa0000, 0xaa00aa, 0xaa5500, 0xaaaaaa, // 0
    0x555555, 0x5555ff, 0x55ff55, 0x55ffff, 0xff5555, 0xff55ff, 0xffff55, 0xffffff, // 8
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

public:

    machine() : portable86()
    {
        memory      = (uint8_t*) malloc(1024*1024);
        dis         = new disasm(memory);
        config_debugger = 0;
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

        for (;;) {

            // Прием событий
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Событие выхода из приложения
                    case SDL_QUIT: return 0;
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


};
