i386::i386(int argc, char** argv)
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

    ram = (uint8_t*) malloc(1024*1024 + 65536);

    // Инициализация памяти и данных
    for (int i = 0; i < 4096; i++) ram[0xC0000 + i] = charmap[i];

    // Инициализация процессора
    byte d, c = 0;
    FILE* fp;

    cpu = new Vcore;
    cpu->ce = 1;
    cpu->reset_n = 0;

    debug_on = 0;
    max_memory = 0xFFFF;

    // Разбор входящих параметров
    d = 1;

    while (d < argc) {

        if (argv[d][0] == '-') {

            switch (argv[d][1])
            {
                case 'd': debug_on = 1; break;
            }

        } else {

            fp = fopen(argv[d], "rb");
            if (fp) {
                printf("LOADED %li\n", fread(ram + 0x100, 1, 65536, fp));
                fclose(fp);
            } else {
                printf("File not found\n"); exit(1);
            }
        }

        d++;
    }

    // Сброс процессора
    cpu->clock = 0; cpu->eval();
    cpu->clock = 1; cpu->eval();
    cpu->reset_n = 1;
}

// Основной цикл работы
int i386::main()
{
    SDL_Rect dstRect;

    dstRect.x = 0;
    dstRect.y = 0;
    dstRect.w = scale*640;
    dstRect.h = scale*400;

    for (;;) {

        // Прием событий
        while (SDL_PollEvent(& evt)) {

            // Событие выхода
            switch (evt.type) {

                case SDL_QUIT:

                    free(screen_buffer);
                    SDL_DestroyTexture(sdl_screen_texture);
                    SDL_FreeFormat(sdl_pixel_format);
                    SDL_DestroyRenderer(sdl_renderer);
                    SDL_DestroyWindow(sdl_window);
                    return 0;
            }
        }

        // Эмулятор
        Uint32 ticks = SDL_GetTicks();

        cycles();
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

void i386::cycles()
{
    // 60 FPS - 25 Mhz
    for (int i = 0; i < 416666; i++) {

        if (debug_on && cpu->m0) {

            disassemble(cpu->a);
            printf("#%04X [%c%c%c%c%c%c%c%c%c] %s\n",
                cpu->a,
                (cpu->flags & 0x800 ? 'O' : '.'),
                (cpu->flags & 0x400 ? 'D' : '.'),
                (cpu->flags & 0x200 ? 'I' : '.'),
                (cpu->flags & 0x100 ? 'T' : '.'),
                (cpu->flags & 0x080 ? 'S' : '.'),
                (cpu->flags & 0x040 ? 'Z' : '.'),
                (cpu->flags & 0x010 ? 'A' : '.'),
                (cpu->flags & 0x004 ? 'P' : '.'),
                (cpu->flags & 0x001 ? 'C' : '.'),
                dis_row
            );
        }

        // Взаимодействие с памятью
        if (cpu->w) ram[cpu->a] = cpu->o; cpu->i = ram[cpu->a];

        if (cpu->port_w) {

            switch (cpu->port_a) {

                case 0x0020: irq_pend = 0; break;
                case 0x03D4: vga_reg  = cpu->port_o; break;
                case 0x03D5:

                    switch (vga_reg) {

                        case 0x0A: cursor_start = cpu->port_o & 15; break;
                        case 0x0B: cursor_end   = cpu->port_o & 15; break;
                        case 0x0E: cursor       = (cpu->port_o & 15)*256 + (cursor & 255); break;
                        case 0x0F: cursor       = (cursor & 0xF00) + cpu->port_o; break;

                    }

                    break;

                case 0x03D8: videomode = cpu->port_o; break;
            }
        }

        // Остановка процессора
        if (cpu->i == 0xF4 && cpu->m0) {
            debug_on = 0;
        } else {
            cpu->clock = 0; cpu->eval();
            cpu->clock = 1; cpu->eval();
        }

        if (cpu->ud) {

            cpu->a--;
            printf("Undefined instruction %02X #%06X\n", ram[cpu->a], cpu->a);
            exit(0);
        }
    }
}

// Установка точки
void i386::pset(int x, int y, Uint32 cl)
{
    if (x < 0 || y < 0 || x >= 640 || y >= 400) {
        return;
    } else {
        screen_buffer[640*y + x] = cl;
    }
}

// Обновление экранной области
void i386::refresh()
{
    switch (videomode)
    {
        // 80x25
        case 0:

            for (int i = 0; i < 25; i++)
            for (int j = 0; j < 80; j++) {

                int     a = 0xB8000 + 2*j + 160*i;
                uint8_t b = ram[a], c = ram[a + 1];

                for (int y = 0; y < 16; y++) {

                    int d = ram[0xC0000 + 16*b + y];
                    for (int x = 0; x < 8; x++) {
                        pset(j*8 + x, i*16 + y, dac[d & (0x80 >> x) ? c & 15 : c >> 4]);
                    }
                }
            }

            break;

        // 320x200
        case 2: // Страница 0
        case 3: // Страница 1

            for (int y = 0; y < 400; y++)
            for (int x = 0; x < 640; x++) {
                pset(x, y, dac[ram[(0xA0000 + (videomode == 3 ? 0x10000 : 0)) + (x>>1) + 320*(y>>1)]]);
            }

            break;

        // 640x400
        case 4:

            for (int y = 0; y < 400; y++)
            for (int x = 0; x < 640; x++) {

                int cl = ram[0xA0000 + (x >> 1) + 320*y];

                cl = x & 1 ? cl & 15 : cl >> 4;
                pset(x, y, dac[cl]);
            }

            break;
    }

}

