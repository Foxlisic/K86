#include <SDL2/SDL.h>

class TB {

protected:

    int width, height, scale, frame_length, pticks;
    int debuglog  = 0;
    int savevideo = 0;

    SDL_Surface*        screen_surface;
    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_PixelFormat*    sdl_pixel_format;
    SDL_Texture*        sdl_screen_texture;
    SDL_Event           evt;
    Uint32*             screen_buffer;

    int cursor_blink    = 0;
    int cursor          = 0;
    int irq_mask        = 0;
    int irq_pend        = 0;
    int vmode           = 0;

    // PS2-KEYBOARD
    int     ps_clock = 0, ps_data = 0, kbd_phase = 0, kbd_ticker = 0;
    uint8_t kbd[256], kbd_top = 0, kb_hit_cnt = 0, kb_latch = 0, kb_data = 0, kb_hit = 0;
    int     dac[256], dac_cnt = 0, dac_id = 0;
    int     video_page = 0;

    // SDCARD: sd_status бит 7-timeout, 0-busy
    uint8_t     spi_data, spi_st = 2, spi_status, spi_command, spi_crc, spi_resp, sd_status = 0x80;
    uint32_t    spi_arg, spi_lba;
    uint16_t    spi_phase;
    uint8_t     spi_sector[512];
    FILE*       spi_file;

    // Память
    uint8_t*    memory;

    // Модули
    Vcore*      mod_core;
    Vvidac*     mod_vidac;

    Uint32      tsc = 0;
    Disassemble* dasm;

public:

    TB(int argc, char** argv)
    {
        int     cid = 1;
        FILE*   fp;

        // 1MB alloc
        memory      = (uint8_t*) malloc(1024*1024 + 65536);
        debuglog    = 0;
        savevideo   = 0;

        pticks      = 0;
        mod_core    = new Vcore();
        mod_vidac   = new Vvidac();

        // Удвоение пикселей
        scale        = 2;
        width        = 640;
        height       = 400;
        frame_length = (1000/30);  // 30 FPS

        dasm = new Disassemble(memory);

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window          = SDL_CreateWindow("FUBUKI 8088", SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED, scale*width, scale*height, SDL_WINDOW_SHOWN);
        sdl_renderer        = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer       = (Uint32*) malloc(width * height * sizeof(Uint32));
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32,
                              SDL_TEXTUREACCESS_STREAMING, width, height);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        // Заполнить видеоинформацией
        for (int i = 0; i < 4096; i++) memory[0xB9000 + i] = font16[i];
        for (int i = 0; i < 4096; i += 2) {
            memory[0xB8000 + i    ] = 0x00;
            memory[0xB8000 + i + 1] = 0x07;
        }

        // Цвета по умолчанию
        for (int i = 0; i < 256; i++) {
            dac[i] = dacdef[i];
        }

        // Сброс видака
        mod_vidac->reset_n  = 0;
        mod_vidac->clock    = 0; mod_vidac->eval();
        mod_vidac->clock    = 1; mod_vidac->eval();
        mod_vidac->reset_n  = 1;
        mod_vidac->page     = 0;

        // Сброс процессора
        // Старт в F000:FFF0 по умолчанию
        mod_core->cfg_ip0 = 0;
        mod_core->reset_n = 0;

        /* Генерация MIF-файла
        for (int i = 0; i < 256; i++) {
            printf("  %02X: %04X;\n", i, ((dacdef[i] & 0xF00000) >> 12) + ((dacdef[i] & 0xF000) >> 8) + ((dacdef[i] & 0xF0) >> 4));
        }
        */

        while (cid < argc)
        {
            if (argv[cid][0] == '-') {

                int ch = argv[cid][1];
                switch (ch) {

                    // Загрузка b=BIOS, c=COM файла
                    case 'b':
                    case 'c':

                        fp = fopen(argv[++cid], "rb");
                        if (fp) { fread(memory + (ch == 'b' ? 0 : 0x100), 1, 65536, fp); fclose(fp); }

                        printf("LOAD %c: %s\n", ch, argv[cid]);

                        // Старт в 0000h:0100h
                        if (ch == 'c') mod_core->cfg_ip0 = 1;
                        break;

                    // Выводка дебаггинга в логконсоль
                    case 'd': debuglog = 1; break;
                    case 'v': savevideo = 1; fp = fopen("record.ppm", "w"); if (fp) fclose(fp); break;
                }
            }

            cid++;
        }

        // Запуск процессора
        mod_core->clock = 0; mod_core->eval();
        mod_core->clock = 1; mod_core->eval();
        mod_core->reset_n = 1;
        mod_core->ce = 1;
    }

    int main()
    {
        for (;;) {

            // Прием событий
            while (SDL_PollEvent(& evt)) {

                // Событие выхода
                switch (evt.type) {

                    case SDL_QUIT:
                        return 0;

                    case SDL_KEYDOWN:
                        kbd_scancode(evt.key.keysym.scancode, 0);
                        break;

                    case SDL_KEYUP:
                        kbd_scancode(evt.key.keysym.scancode, 1);
                        break;
                }
            }

            Uint32 tps = 0;
            Uint32 ticks = SDL_GetTicks();

            // Отсчитать требуемое количество тактов
            do { tps += frame(); } while (SDL_GetTicks() - ticks < frame_length);

            refresh();
            update();

            SDL_Delay(1);
            return 1;
        }
    }

    // Пачка инструкции
    int frame()
    {
        int tps = 1000;
        for (int i = 0; i < tps; i++) {

            int vidac_cmd = 0;

            // Обработка клавиатуры
            int _kb = kbd_pop();

            // Логирование
            if (mod_core->m0 && debuglog) {

                uint32_t address = mod_core->cs*16 + mod_core->ip;

                // Чуваааак! Код инструкции HLT
                if (memory[address] != 0xF4) {

                    dasm->disassemble(address);
                    printf("[%08X|%c%c%c%c%c%c%c%c%c] %04X:%04X %s\n",
                        tsc,
                        (mod_core->flags & 0x800 ? 'O' : '.'),
                        (mod_core->flags & 0x400 ? 'D' : '.'),
                        (mod_core->flags & 0x200 ? 'I' : '.'),
                        (mod_core->flags & 0x100 ? 'T' : '.'),
                        (mod_core->flags & 0x080 ? 'S' : '.'),
                        (mod_core->flags & 0x040 ? 'Z' : '.'),
                        (mod_core->flags & 0x010 ? 'A' : '.'),
                        (mod_core->flags & 0x004 ? 'P' : '.'),
                        (mod_core->flags & 0x001 ? 'C' : '.'),
                        mod_core->cs, mod_core->ip,
                        dasm->dis_row
                        // mod_core->cx, mod_core->di
                    );
                }
            }

            // ----------------------
            if (mod_core->we) memory[ mod_core->address ] = mod_core->out;
            mod_core->in = memory[ mod_core->address ];

            // Контроллер прерываний
            // ----------------------

            // @TODO Timer

            // Есть прерывание от клавиатуры
            if (_kb && irq_pend == 0) {

                kb_data = _kb;
                kb_hit  = 1;

                mod_core->irq    = !mod_core->irq;
                mod_core->irq_in = 9;

                irq_pend = 1;
            }

            // Чтение из портов
            if (mod_core->port_r) {

                switch (mod_core->port_a) {

                    case 0x60: mod_core->port_i = kb_data; break;
                    case 0x61: mod_core->port_i = kb_hit; kb_hit = 0; break;
                    case 0xFE: mod_core->port_i = sd_status; break;
                    case 0xFF: mod_core->port_i = spi_data; break;
                }
            }

            // Запись в порт
            if (mod_core->port_w) {

                switch (mod_core->port_a) {

                    case 0x0020: irq_pend = 0; break;                   // EOI
                    case 0x00A0: irq_mask = mod_core->port_o; break;    // IOMASK
                    case 0x00FE: sd_status = 0; break;                  // Управление SD
                    case 0x00FF: sdspi(mod_core->port_o); break;        // Отослать данные к SD

                    // Запрос на рендер
                    case 0x0300: vidac_cmd = 1; mod_vidac->page = mod_core->port_o & 1; break;

                    // Текущая видеостраница
                    case 0x03C0: video_page = mod_core->port_o & 1; break;

                    // Программирование палитры
                    case 0x03C8: dac_id = mod_core->port_o; dac_cnt = 0; break;
                    case 0x03C9:

                        switch (dac_cnt)
                        {
                            case 0: dac[dac_id] = (dac[dac_id] & 0x00FFFF) | ((mod_core->port_o & 0x3F) * 65536 * 4); break;
                            case 1: dac[dac_id] = (dac[dac_id] & 0xFF00FF) | ((mod_core->port_o & 0x3F) * 256 * 4); break;
                            case 2: dac[dac_id] = (dac[dac_id] & 0xFFFF00) | ((mod_core->port_o & 0x3F) * 4); break;
                        }

                        // Перещелкнуть на другой регистр
                        if (dac_cnt == 2) {
                            dac_id = (dac_id + 1) & 0xFF;
                        }

                        dac_cnt = (dac_cnt + 1) % 3;

                        break;

                    // Переключение видеорежима
                    case 0x03D8: vmode = mod_core->port_o; break;
                }
            }

            // Такт на ядро
            mod_core->clock = 0; mod_core->eval();
            mod_core->clock = 1; mod_core->eval();
            tsc++;

            // Запрос к VIDAC
            mod_vidac->cmd = vidac_cmd;

            // Обработка только если VIDAC реально работает
            if (mod_vidac->cmd || mod_vidac->bsy) {

                int _a = 0xA0000 + mod_vidac->a;

                mod_vidac->i = memory[_a];
                if (mod_vidac->w) memory[_a] = mod_vidac->o;

                // Отладка
                // printf("VIDAC CMD=%d, BSY=%d, A=%05X, D=%02X, O=%02X, w=%d\n", mod_vidac->cmd, mod_vidac->bsy, _a, mod_vidac->i, mod_vidac->o, mod_vidac->w);

                mod_vidac->clock = 0; mod_vidac->eval();
                mod_vidac->clock = 1; mod_vidac->eval();
            }

            // 60 FPS
            if ((tsc % 416666) == 0) saveframe();
        }

        return tps;
    }

    // Обновить кадр
    void refresh()
    {
        // Видеорежим 320 x 200
        if (vmode & 2) {

            for (int y = 0; y < 400; y++)
            for (int x = 0; x < 640; x++) {
                pset(x, y, dac[memory[(video_page ? 0xB0000 : 0xA0000) + (x>>1) + (y>>1)*320]]);
            }
        }
        // Текстовый видеорежим
        else {

            for (int y = 0; y < 25; y++)
            for (int x = 0; x < 80; x++)
            {
                uint32_t a = 0xB8000 + 2*x + y*160;
                uint8_t ch = memory[a+0];
                uint8_t at = memory[a+1];

                for (int i = 0; i < 16; i++)
                for (int j = 0; j < 8; j++)
                {
                    int bk = (cursor == 80*y + x && i >= 14) && (cursor_blink < 15);

                    int ft = font16[16*ch + i];
                    int cl = (ft & (0x80 >> j)) || bk ? (at & 15) : (at >> 4) & 3;

                    pset(x*8 + j, y*16 + i, dac[cl]);
                }
            }

            cursor_blink = (cursor_blink + 1) % 30;
        }

    }

    // Обновить окно
    void update()
    {
        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = scale * width;
        dstRect.h = scale * height;

        SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, width * sizeof(Uint32));
        SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
        SDL_RenderClear         (sdl_renderer);
        SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
        SDL_RenderPresent       (sdl_renderer);
    }

    // Убрать окно из памяти
    int destroy()
    {
        free(screen_buffer);
        free(memory);

        SDL_DestroyTexture(sdl_screen_texture);
        SDL_FreeFormat(sdl_pixel_format);
        SDL_DestroyRenderer(sdl_renderer);
        SDL_DestroyWindow(sdl_window);
        SDL_Quit();

        return 0;
    }

    // Установка точки
    void pset(int x, int y, Uint32 cl)
    {
        if (x < 0 || y < 0 || x >= width || y >= height)
            return;

        screen_buffer[width*y + x] = cl;
    }

    // Сканирование нажатой клавиши
    // https://ru.wikipedia.org/wiki/Скан-код
    void kbd_scancode(int scancode, int release)
    {
        switch (scancode) {

            // Коды клавиш A-Z
            case SDL_SCANCODE_A: if (release) kbd_push(0xF0); kbd_push(0x1C); break;
            case SDL_SCANCODE_B: if (release) kbd_push(0xF0); kbd_push(0x32); break;
            case SDL_SCANCODE_C: if (release) kbd_push(0xF0); kbd_push(0x21); break;
            case SDL_SCANCODE_D: if (release) kbd_push(0xF0); kbd_push(0x23); break;
            case SDL_SCANCODE_E: if (release) kbd_push(0xF0); kbd_push(0x24); break;
            case SDL_SCANCODE_F: if (release) kbd_push(0xF0); kbd_push(0x2B); break;
            case SDL_SCANCODE_G: if (release) kbd_push(0xF0); kbd_push(0x34); break;
            case SDL_SCANCODE_H: if (release) kbd_push(0xF0); kbd_push(0x33); break;
            case SDL_SCANCODE_I: if (release) kbd_push(0xF0); kbd_push(0x43); break;
            case SDL_SCANCODE_J: if (release) kbd_push(0xF0); kbd_push(0x3B); break;
            case SDL_SCANCODE_K: if (release) kbd_push(0xF0); kbd_push(0x42); break;
            case SDL_SCANCODE_L: if (release) kbd_push(0xF0); kbd_push(0x4B); break;
            case SDL_SCANCODE_M: if (release) kbd_push(0xF0); kbd_push(0x3A); break;
            case SDL_SCANCODE_N: if (release) kbd_push(0xF0); kbd_push(0x31); break;
            case SDL_SCANCODE_O: if (release) kbd_push(0xF0); kbd_push(0x44); break;
            case SDL_SCANCODE_P: if (release) kbd_push(0xF0); kbd_push(0x4D); break;
            case SDL_SCANCODE_Q: if (release) kbd_push(0xF0); kbd_push(0x15); break;
            case SDL_SCANCODE_R: if (release) kbd_push(0xF0); kbd_push(0x2D); break;
            case SDL_SCANCODE_S: if (release) kbd_push(0xF0); kbd_push(0x1B); break;
            case SDL_SCANCODE_T: if (release) kbd_push(0xF0); kbd_push(0x2C); break;
            case SDL_SCANCODE_U: if (release) kbd_push(0xF0); kbd_push(0x3C); break;
            case SDL_SCANCODE_V: if (release) kbd_push(0xF0); kbd_push(0x2A); break;
            case SDL_SCANCODE_W: if (release) kbd_push(0xF0); kbd_push(0x1D); break;
            case SDL_SCANCODE_X: if (release) kbd_push(0xF0); kbd_push(0x22); break;
            case SDL_SCANCODE_Y: if (release) kbd_push(0xF0); kbd_push(0x35); break;
            case SDL_SCANCODE_Z: if (release) kbd_push(0xF0); kbd_push(0x1A); break;

            // Цифры
            case SDL_SCANCODE_0: if (release) kbd_push(0xF0); kbd_push(0x45); break;
            case SDL_SCANCODE_1: if (release) kbd_push(0xF0); kbd_push(0x16); break;
            case SDL_SCANCODE_2: if (release) kbd_push(0xF0); kbd_push(0x1E); break;
            case SDL_SCANCODE_3: if (release) kbd_push(0xF0); kbd_push(0x26); break;
            case SDL_SCANCODE_4: if (release) kbd_push(0xF0); kbd_push(0x25); break;
            case SDL_SCANCODE_5: if (release) kbd_push(0xF0); kbd_push(0x2E); break;
            case SDL_SCANCODE_6: if (release) kbd_push(0xF0); kbd_push(0x36); break;
            case SDL_SCANCODE_7: if (release) kbd_push(0xF0); kbd_push(0x3D); break;
            case SDL_SCANCODE_8: if (release) kbd_push(0xF0); kbd_push(0x3E); break;
            case SDL_SCANCODE_9: if (release) kbd_push(0xF0); kbd_push(0x46); break;

            // Keypad
            case SDL_SCANCODE_KP_0: if (release) kbd_push(0xF0); kbd_push(0x70); break;
            case SDL_SCANCODE_KP_1: if (release) kbd_push(0xF0); kbd_push(0x69); break;
            case SDL_SCANCODE_KP_2: if (release) kbd_push(0xF0); kbd_push(0x72); break;
            case SDL_SCANCODE_KP_3: if (release) kbd_push(0xF0); kbd_push(0x7A); break;
            case SDL_SCANCODE_KP_4: if (release) kbd_push(0xF0); kbd_push(0x6B); break;
            case SDL_SCANCODE_KP_5: if (release) kbd_push(0xF0); kbd_push(0x73); break;
            case SDL_SCANCODE_KP_6: if (release) kbd_push(0xF0); kbd_push(0x74); break;
            case SDL_SCANCODE_KP_7: if (release) kbd_push(0xF0); kbd_push(0x6C); break;
            case SDL_SCANCODE_KP_8: if (release) kbd_push(0xF0); kbd_push(0x75); break;
            case SDL_SCANCODE_KP_9: if (release) kbd_push(0xF0); kbd_push(0x7D); break;

            // Специальные символы
            case SDL_SCANCODE_GRAVE:        if (release) kbd_push(0xF0); kbd_push(0x0E); break;
            case SDL_SCANCODE_MINUS:        if (release) kbd_push(0xF0); kbd_push(0x4E); break;
            case SDL_SCANCODE_EQUALS:       if (release) kbd_push(0xF0); kbd_push(0x55); break;
            case SDL_SCANCODE_BACKSLASH:    if (release) kbd_push(0xF0); kbd_push(0x5D); break;
            case SDL_SCANCODE_LEFTBRACKET:  if (release) kbd_push(0xF0); kbd_push(0x54); break;
            case SDL_SCANCODE_RIGHTBRACKET: if (release) kbd_push(0xF0); kbd_push(0x5B); break;
            case SDL_SCANCODE_SEMICOLON:    if (release) kbd_push(0xF0); kbd_push(0x4C); break;
            case SDL_SCANCODE_APOSTROPHE:   if (release) kbd_push(0xF0); kbd_push(0x52); break;
            case SDL_SCANCODE_COMMA:        if (release) kbd_push(0xF0); kbd_push(0x41); break;
            case SDL_SCANCODE_PERIOD:       if (release) kbd_push(0xF0); kbd_push(0x49); break;
            case SDL_SCANCODE_SLASH:        if (release) kbd_push(0xF0); kbd_push(0x4A); break;
            case SDL_SCANCODE_BACKSPACE:    if (release) kbd_push(0xF0); kbd_push(0x66); break;
            case SDL_SCANCODE_SPACE:        if (release) kbd_push(0xF0); kbd_push(0x29); break;
            case SDL_SCANCODE_TAB:          if (release) kbd_push(0xF0); kbd_push(0x0D); break;
            case SDL_SCANCODE_CAPSLOCK:     if (release) kbd_push(0xF0); kbd_push(0x58); break;
            case SDL_SCANCODE_LSHIFT:       if (release) kbd_push(0xF0); kbd_push(0x12); break;
            case SDL_SCANCODE_LCTRL:        if (release) kbd_push(0xF0); kbd_push(0x14); break;
            case SDL_SCANCODE_LALT:         if (release) kbd_push(0xF0); kbd_push(0x11); break;
            case SDL_SCANCODE_RSHIFT:       if (release) kbd_push(0xF0); kbd_push(0x59); break;
            case SDL_SCANCODE_RETURN:       if (release) kbd_push(0xF0); kbd_push(0x5A); break;
            case SDL_SCANCODE_ESCAPE:       if (release) kbd_push(0xF0); kbd_push(0x76); break;
            case SDL_SCANCODE_NUMLOCKCLEAR: if (release) kbd_push(0xF0); kbd_push(0x77); break;
            case SDL_SCANCODE_KP_MULTIPLY:  if (release) kbd_push(0xF0); kbd_push(0x7C); break;
            case SDL_SCANCODE_KP_MINUS:     if (release) kbd_push(0xF0); kbd_push(0x7B); break;
            case SDL_SCANCODE_KP_PLUS:      if (release) kbd_push(0xF0); kbd_push(0x79); break;
            case SDL_SCANCODE_KP_PERIOD:    if (release) kbd_push(0xF0); kbd_push(0x71); break;
            case SDL_SCANCODE_SCROLLLOCK:   if (release) kbd_push(0xF0); kbd_push(0x7E); break;

            // F1-F12 Клавиши
            case SDL_SCANCODE_F1:   if (release) kbd_push(0xF0); kbd_push(0x05); break;
            case SDL_SCANCODE_F2:   if (release) kbd_push(0xF0); kbd_push(0x06); break;
            case SDL_SCANCODE_F3:   if (release) kbd_push(0xF0); kbd_push(0x04); break;
            case SDL_SCANCODE_F4:   if (release) kbd_push(0xF0); kbd_push(0x0C); break;
            case SDL_SCANCODE_F5:   if (release) kbd_push(0xF0); kbd_push(0x03); break;
            case SDL_SCANCODE_F6:   if (release) kbd_push(0xF0); kbd_push(0x0B); break;
            case SDL_SCANCODE_F7:   if (release) kbd_push(0xF0); kbd_push(0x83); break;
            case SDL_SCANCODE_F8:   if (release) kbd_push(0xF0); kbd_push(0x0A); break;
            case SDL_SCANCODE_F9:   if (release) kbd_push(0xF0); kbd_push(0x01); break;
            case SDL_SCANCODE_F10:  if (release) kbd_push(0xF0); kbd_push(0x09); break;
            case SDL_SCANCODE_F11:  if (release) kbd_push(0xF0); kbd_push(0x78); break;
            case SDL_SCANCODE_F12:  if (release) kbd_push(0xF0); kbd_push(0x07); break;

            // Расширенные клавиши
            case SDL_SCANCODE_LGUI:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x1F); break;
            case SDL_SCANCODE_RGUI:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x27); break;
            case SDL_SCANCODE_APPLICATION:  kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x2F); break;
            case SDL_SCANCODE_RCTRL:        kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x14); break;
            case SDL_SCANCODE_RALT:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x11); break;
            case SDL_SCANCODE_KP_DIVIDE:    kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x4A); break;
            case SDL_SCANCODE_KP_ENTER:     kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x5A); break;

            case SDL_SCANCODE_INSERT:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x70); break;
            case SDL_SCANCODE_HOME:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x6C); break;
            case SDL_SCANCODE_END:          kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x69); break;
            case SDL_SCANCODE_PAGEUP:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x7D); break;
            case SDL_SCANCODE_PAGEDOWN:     kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x7A); break;
            case SDL_SCANCODE_DELETE:       kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x71); break;

            case SDL_SCANCODE_UP:           kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x75); break;
            case SDL_SCANCODE_DOWN:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x72); break;
            case SDL_SCANCODE_LEFT:         kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x6B); break;
            case SDL_SCANCODE_RIGHT:        kbd_push(0xE0); if (release) kbd_push(0xF0); kbd_push(0x74); break;

            // Клавиша PrnScr
            case SDL_SCANCODE_PRINTSCREEN: {

                if (release == 0) {

                    kbd_push(0xE0); kbd_push(0x12);
                    kbd_push(0xE0); kbd_push(0x7C);

                } else {

                    kbd_push(0xE0); kbd_push(0xF0); kbd_push(0x7C);
                    kbd_push(0xE0); kbd_push(0xF0); kbd_push(0x12);
                }

                break;
            }

            // Клавиша Pause
            case SDL_SCANCODE_PAUSE: {

                kbd_push(0xE1);
                kbd_push(0x14); if (release) kbd_push(0xF0); kbd_push(0x77);
                kbd_push(0x14); if (release) kbd_push(0xF0); kbd_push(0x77);
                break;
            }
        }
    }

    // Нажатие на клавишу
    void kbd_push(int data)
    {
        if (kbd_top >= 255) return;
        kbd[kbd_top] = data;
        kbd_top++;
    }

    // Извлечение PS/2
    int kbd_pop()
    {
        int sym = 0;

        // В очереди нет клавиш для нажатия
        if (kbd_top == 0) return 0;

        // 25000000/2000 = 12.5 kHz Очередной полутакт для PS/2
        if (++kbd_ticker >= 8*2000) {

            sym = kbd[0];
            kbd_top--;
            kbd_ticker = 0;

            for (int i = 0; i < kbd_top; i++) kbd[i] = kbd[i+1];
        }

        return sym;
    }

    // Сохранение фрейма
    void saveframe()
    {
        if (savevideo == 0) {
            return;
        }

        FILE* fp = fopen("record.ppm", "ab");
        if (fp) {

            fprintf(fp, "P6\n# APPLICATION\n%d %d\n255\n", width, height);
            for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++) {

                int cl = screen_buffer[y*width + x];
                int vl = ((cl >> 16) & 255) + (cl & 0xFF00) + ((cl&255)<<16);
                fwrite(&vl, 1, 3, fp);
            }

            fclose(fp);
        }
    }

    // Эмуляция протокола SDCard
    void sdspi(int data)
    {
        switch (spi_status) {

            // IDLE
            case 0:

                // Чтение в 0-м дает последний ответ от команды
                if (data == 0xFF) {

                    spi_data = spi_resp;
                    spi_resp = 0xFF;
                }
                // Запуск приема команды
                else if ((data & 0xC0) == 0x40) {

                    spi_status  = 1;
                    spi_command = data & 0x3F;
                    spi_arg     = 0;
                    spi_phase   = 0;
                }

                break;

            // COMMAND (прием)
            case 1: {

                if (spi_phase < 4) {

                    spi_arg = (spi_arg << 8) | data;
                    spi_phase++;

                } else {

                    spi_phase = 0;
                    spi_crc   = data;

                    /* Ответ зависит от команды */
                    switch (spi_command) {

                        /* CMDxx */
                        case 0:  spi_status = 0; spi_resp = 0x01; break;
                        case 8:  spi_status = 2; spi_resp = 0x00; break;
                        case 13: spi_status = 6; spi_resp = 0x00; break;    // STATUS
                        case 17: spi_status = 4; spi_lba  = spi_arg; break; // BLOCK SEARCH READ
                        case 24: spi_status = 5; spi_lba  = spi_arg; break; // BLOCK SEARCH WRITE
                        case 41: spi_status = 0; spi_resp = 0x00; break;    // READY=0
                        case 55: spi_status = 0; spi_resp = 0x01; break;    // ACMD=1
                        case 58: spi_status = 3; spi_resp = 0x00; break;    // CHECK=0
                        default: spi_status = 0; spi_resp = 0xFF; break;    // Unknown
                    }
                }

                break;
            }

            // OCR Read (5 bytes)
            case 2: {

                if (data == 0xFF) {

                    if (spi_phase == 4) {
                        spi_data = 0xAA;
                        spi_status = 0;
                    } else {
                        spi_data = 0x00;
                    }

                    spi_phase++;
                }
                else {
                    printf("SPI Illegal Write #1"); exit(1);
                }

                break;
            }

            // Информация о SDHC поддержке
            case 3: {

                if (data == 0xFF) {

                    if (spi_phase == 0) {
                        spi_data = 0x00;
                    } else if (spi_phase == 1) {
                        spi_data = 0xC0;
                    } else if (spi_phase < 4) {
                        spi_data = 0xFF;
                    } else {
                        spi_data = 0xFF;
                        spi_status = 0;
                    }

                    spi_phase++;

                } else {
                    printf("SPI Illegal Write #2"); exit(1);
                }

                break;
            }

            // Чтение с диска
            case 4: {

                if (spi_phase == 0) {

                    spi_data = 0x00;
                    spi_file = fopen("sd.img", "ab+");
                    if (spi_file == NULL) { printf("Error open file\n"); exit(0); }
                    fseek(spi_file, 512 * spi_lba, SEEK_SET);
                    (void) fread(spi_sector, 1, 512, spi_file);
                    fclose(spi_file);

                } else if (spi_phase == 1) {
                    spi_data = 0xFE;
                } else if (spi_phase < 514) {
                    spi_data = spi_sector[spi_phase - 2];
                }

                spi_phase++;
                if (spi_phase == 514) {

                    spi_status = 0;
                    spi_resp   = 0xFF;
                }

                break;
            }

            // Запись на диск
            case 5: {

                if (spi_phase == 0) {
                    spi_data = 0x00; // ACK

                } else if (spi_phase == 1) {

                    if (data != 0xFE) {
                        printf("Illegal opcode (non FE)\n"); exit(1);
                    }

                } else if (spi_phase < 514) {
                    spi_sector[spi_phase - 2] = data;

                } else if (spi_phase == 516) {
                    spi_data = 0x05; // ACK

                } else if (spi_phase < 520) {
                    spi_data = 0xFF;
                }

                spi_phase++;

                // Окончание программирования
                if (spi_phase == 520) {

                    spi_status = 0;
                    spi_resp   = 0x00;

                    // Запись новых данных на диск
                    spi_file = fopen("sd.img", "r+b");
                    if (spi_file == NULL) { printf("Error open file\n"); exit(0); }
                    fseek(spi_file, 512 * spi_lba, SEEK_SET);
                    (void) fwrite(spi_sector, 1, 512, spi_file);
                    fclose(spi_file);
                }

                break;
            }

            // STATUS [2 Byte 00 00]
            case 6: {

                if (data == 0xFF) {

                    if (spi_phase == 1)
                        spi_status = 0;

                    spi_data = 0x00;
                    spi_phase++;
                }
                else {
                    printf("SPI Illegal Write #1"); exit(1);
                }
            }
        }
    }
};
