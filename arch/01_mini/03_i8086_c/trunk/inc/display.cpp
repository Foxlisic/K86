#include "SDL.h"

class DisplaySDL {

public:

    // Размер окна
    int width;
    int height;
    int keycode;
    int touche;

    // Текущий видеорежим
    int videomode;
    int cursor_x, cursor_y,
        cursor_blink,
        cursor_start, cursor_end;

    clock_t time_irq;
    clock_t time_cursor;
    double  time_elapsed;

    // Поверхность окна SDL
    SDL_Surface*  sdl_screen;

    // Событие в окне
    SDL_Event  event;

    // Тип события
    int _event_type;

    // Общая память
    unsigned char* m;

    int need_redraw;            // Требуется перерисовка окна полностью
    int dac[256] = {};

    int dac16[16] = {
        /* 00 */ 0x000000,
        /* 01 */ 0x0000aa,
        /* 02 */ 0x00aa00,
        /* 03 */ 0x00aaaa,
        /* 04 */ 0xaa0000,
        /* 05 */ 0xaa00aa,
        /* 06 */ 0xaa5500,
        /* 07 */ 0xaaaaaa,
        /* 08 */ 0x555555,
        /* 09 */ 0x5555ff,
        /* 0a */ 0x55ff55,
        /* 0b */ 0x55ffff,
        /* 0c */ 0xff5555,
        /* 0d */ 0xff55ff,
        /* 0e */ 0xffff55,
        /* 0f */ 0xffffff,
    };

    // Таблица DAC по умолчанию
    int dac256[256] = {
        /* 00 */ 0x000000,
        /* 01 */ 0x0000aa,
        /* 02 */ 0x00aa00,
        /* 03 */ 0x00aaaa,
        /* 04 */ 0xaa0000,
        /* 05 */ 0xaa00aa,
        /* 06 */ 0xaa5500,
        /* 07 */ 0xaaaaaa,
        /* 08 */ 0x555555,
        /* 09 */ 0x5555ff,
        /* 0a */ 0x55ff55,
        /* 0b */ 0x55ffff,
        /* 0c */ 0xff5555,
        /* 0d */ 0xff55ff,
        /* 0e */ 0xffff55,
        /* 0f */ 0xffffff,
        /* 10 */ 0x000000,
        /* 11 */ 0x141414,
        /* 12 */ 0x202020,
        /* 13 */ 0x2c2c2c,
        /* 14 */ 0x383838,
        /* 15 */ 0x454545,
        /* 16 */ 0x515151,
        /* 17 */ 0x616161,
        /* 18 */ 0x717171,
        /* 19 */ 0x828282,
        /* 1a */ 0x929292,
        /* 1b */ 0xa2a2a2,
        /* 1c */ 0xb6b6b6,
        /* 1d */ 0xcbcbcb,
        /* 1e */ 0xe3e3e3,
        /* 1f */ 0xffffff,
        /* 20 */ 0x0000ff,
        /* 21 */ 0x4100ff,
        /* 22 */ 0x7d00ff,
        /* 23 */ 0xbe00ff,
        /* 24 */ 0xff00ff,
        /* 25 */ 0xff00be,
        /* 26 */ 0xff007d,
        /* 27 */ 0xff0041,
        /* 28 */ 0xff0000,
        /* 29 */ 0xff4100,
        /* 2a */ 0xff7d00,
        /* 2b */ 0xffbe00,
        /* 2c */ 0xffff00,
        /* 2d */ 0xbeff00,
        /* 2e */ 0x7dff00,
        /* 2f */ 0x41ff00,
        /* 30 */ 0x00ff00,
        /* 31 */ 0x00ff41,
        /* 32 */ 0x00ff7d,
        /* 33 */ 0x00ffbe,
        /* 34 */ 0x00ffff,
        /* 35 */ 0x00beff,
        /* 36 */ 0x007dff,
        /* 37 */ 0x0041ff,
        /* 38 */ 0x7d7dff,
        /* 39 */ 0x9e7dff,
        /* 3a */ 0xbe7dff,
        /* 3b */ 0xdf7dff,
        /* 3c */ 0xff7dff,
        /* 3d */ 0xff7ddf,
        /* 3e */ 0xff7dbe,
        /* 3f */ 0xff7d9e,
        /* 40 */ 0xff7d7d,
        /* 41 */ 0xff9e7d,
        /* 42 */ 0xffbe7d,
        /* 43 */ 0xffdf7d,
        /* 44 */ 0xffff7d,
        /* 45 */ 0xdfff7d,
        /* 46 */ 0xbeff7d,
        /* 47 */ 0x9eff7d,
        /* 48 */ 0x7dff7d,
        /* 49 */ 0x7dff9e,
        /* 4a */ 0x7dffbe,
        /* 4b */ 0x7dffdf,
        /* 4c */ 0x7dffff,
        /* 4d */ 0x7ddfff,
        /* 4e */ 0x7dbeff,
        /* 4f */ 0x7d9eff,
        /* 50 */ 0xb6b6ff,
        /* 51 */ 0xc7b6ff,
        /* 52 */ 0xdbb6ff,
        /* 53 */ 0xebb6ff,
        /* 54 */ 0xffb6ff,
        /* 55 */ 0xffb6eb,
        /* 56 */ 0xffb6db,
        /* 57 */ 0xffb6c7,
        /* 58 */ 0xffb6b6,
        /* 59 */ 0xffc7b6,
        /* 5a */ 0xffdbb6,
        /* 5b */ 0xffebb6,
        /* 5c */ 0xffffb6,
        /* 5d */ 0xebffb6,
        /* 5e */ 0xdbffb6,
        /* 5f */ 0xc7ffb6,
        /* 60 */ 0xb6ffb6,
        /* 61 */ 0xb6ffc7,
        /* 62 */ 0xb6ffdb,
        /* 63 */ 0xb6ffeb,
        /* 64 */ 0xb6ffff,
        /* 65 */ 0xb6ebff,
        /* 66 */ 0xb6dbff,
        /* 67 */ 0xb6c7ff,
        /* 68 */ 0x000071,
        /* 69 */ 0x1c0071,
        /* 6a */ 0x380071,
        /* 6b */ 0x550071,
        /* 6c */ 0x710071,
        /* 6d */ 0x710055,
        /* 6e */ 0x710038,
        /* 6f */ 0x71001c,
        /* 70 */ 0x710000,
        /* 71 */ 0x711c00,
        /* 72 */ 0x713800,
        /* 73 */ 0x715500,
        /* 74 */ 0x717100,
        /* 75 */ 0x557100,
        /* 76 */ 0x387100,
        /* 77 */ 0x1c7100,
        /* 78 */ 0x007100,
        /* 79 */ 0x00711c,
        /* 7a */ 0x007138,
        /* 7b */ 0x007155,
        /* 7c */ 0x007171,
        /* 7d */ 0x005571,
        /* 7e */ 0x003871,
        /* 7f */ 0x001c71,
        /* 80 */ 0x383871,
        /* 81 */ 0x453871,
        /* 82 */ 0x553871,
        /* 83 */ 0x613871,
        /* 84 */ 0x713871,
        /* 85 */ 0x713861,
        /* 86 */ 0x713855,
        /* 87 */ 0x713845,
        /* 88 */ 0x713838,
        /* 89 */ 0x714538,
        /* 8a */ 0x715538,
        /* 8b */ 0x716138,
        /* 8c */ 0x717138,
        /* 8d */ 0x617138,
        /* 8e */ 0x557138,
        /* 8f */ 0x457138,
        /* 90 */ 0x387138,
        /* 91 */ 0x387145,
        /* 92 */ 0x387155,
        /* 93 */ 0x387161,
        /* 94 */ 0x387171,
        /* 95 */ 0x386171,
        /* 96 */ 0x385571,
        /* 97 */ 0x384571,
        /* 98 */ 0x515171,
        /* 99 */ 0x595171,
        /* 9a */ 0x615171,
        /* 9b */ 0x695171,
        /* 9c */ 0x715171,
        /* 9d */ 0x715169,
        /* 9e */ 0x715161,
        /* 9f */ 0x715159,
        /* a0 */ 0x715151,
        /* a1 */ 0x715951,
        /* a2 */ 0x716151,
        /* a3 */ 0x716951,
        /* a4 */ 0x717151,
        /* a5 */ 0x697151,
        /* a6 */ 0x617151,
        /* a7 */ 0x597151,
        /* a8 */ 0x517151,
        /* a9 */ 0x517159,
        /* aa */ 0x517161,
        /* ab */ 0x517169,
        /* ac */ 0x517171,
        /* ad */ 0x516971,
        /* ae */ 0x516171,
        /* af */ 0x515971,
        /* b0 */ 0x000041,
        /* b1 */ 0x100041,
        /* b2 */ 0x200041,
        /* b3 */ 0x300041,
        /* b4 */ 0x410041,
        /* b5 */ 0x410030,
        /* b6 */ 0x410020,
        /* b7 */ 0x410010,
        /* b8 */ 0x410000,
        /* b9 */ 0x411000,
        /* ba */ 0x412000,
        /* bb */ 0x413000,
        /* bc */ 0x414100,
        /* bd */ 0x304100,
        /* be */ 0x204100,
        /* bf */ 0x104100,
        /* c0 */ 0x004100,
        /* c1 */ 0x004110,
        /* c2 */ 0x004120,
        /* c3 */ 0x004130,
        /* c4 */ 0x004141,
        /* c5 */ 0x003041,
        /* c6 */ 0x002041,
        /* c7 */ 0x001041,
        /* c8 */ 0x202041,
        /* c9 */ 0x282041,
        /* ca */ 0x302041,
        /* cb */ 0x382041,
        /* cc */ 0x412041,
        /* cd */ 0x412038,
        /* ce */ 0x412030,
        /* cf */ 0x412028,
        /* d0 */ 0x412020,
        /* d1 */ 0x412820,
        /* d2 */ 0x413020,
        /* d3 */ 0x413820,
        /* d4 */ 0x414120,
        /* d5 */ 0x384120,
        /* d6 */ 0x304120,
        /* d7 */ 0x284120,
        /* d8 */ 0x204120,
        /* d9 */ 0x204128,
        /* da */ 0x204130,
        /* db */ 0x204138,
        /* dc */ 0x204141,
        /* dd */ 0x203841,
        /* de */ 0x203041,
        /* df */ 0x202841,
        /* e0 */ 0x2c2c41,
        /* e1 */ 0x302c41,
        /* e2 */ 0x342c41,
        /* e3 */ 0x3c2c41,
        /* e4 */ 0x412c41,
        /* e5 */ 0x412c3c,
        /* e6 */ 0x412c34,
        /* e7 */ 0x412c30,
        /* e8 */ 0x412c2c,
        /* e9 */ 0x41302c,
        /* ea */ 0x41342c,
        /* eb */ 0x413c2c,
        /* ec */ 0x41412c,
        /* ed */ 0x3c412c,
        /* ee */ 0x34412c,
        /* ef */ 0x30412c,
        /* f0 */ 0x2c412c,
        /* f1 */ 0x2c4130,
        /* f2 */ 0x2c4134,
        /* f3 */ 0x2c413c,
        /* f4 */ 0x2c4141,
        /* f5 */ 0x2c3c41,
        /* f6 */ 0x2c3441,
        /* f7 */ 0x2c3041,
        /* f8 */ 0x000000,
        /* f9 */ 0x000000,
        /* fa */ 0x000000,
        /* fb */ 0x000000,
        /* fc */ 0x000000,
        /* fd */ 0x000000,
        /* fe */ 0x000000,
        /* ff */ 0x000000,
    };

// ---------------------------------------------------------------------

    /* Инициализация размеров окна */
    DisplaySDL(int w, int h) {

        int i;

        width     = w;
        height    = h;
        touche    = 0;

        time_irq     = clock();
        time_cursor  = clock();

        // Видео и таймер ON
        SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER);
        SDL_EnableUNICODE(1);

        // 80x25 textmode
        videomode = 0x03;
        need_redraw = 1;

        cursor_x  = 0;
        cursor_y  = 0;
        cursor_blink = 0;
        cursor_start = 14;
        cursor_end   = 15;

        for (i = 0; i < 16; i++) dac[i] = dac16[i];
    };

    /* Показать окно */
    void show(const char* name) {

        sdl_screen = SDL_SetVideoMode(width, height, 32, SDL_HWSURFACE | SDL_DOUBLEBUF);
        SDL_WM_SetCaption( name, 0 );
    }

    /* Получить последний тип события */
    int event_type() {
        return this->_event_type;
    }

    /* Получение ID клавиши */
    int get_key(SDL_Event event) {

        /* Получение ссылки на структуру с данными о нажатой клавише */
        SDL_KeyboardEvent * eventkey = &event.key;

        /* Получить скан-код клавиш */
        return eventkey->keysym.scancode;
    }

    /* Колбэк таймера по умолчанию: статичный, единственный */
    static uint Timer(uint interval, void *param) {

        SDL_Event     event;
        SDL_UserEvent userevent;

        /* Создать новый Event */
        userevent.type  = SDL_USEREVENT;
        userevent.code  = 0;
        userevent.data1 = NULL;
        userevent.data2 = NULL;

        event.type = SDL_USEREVENT;
        event.user = userevent;

        SDL_PushEvent(&event);
        return (interval);
    }

    /* Инициализация события таймера */
    void enabletimer(uint interval) {
        SDL_AddTimer(interval, DisplaySDL::Timer, NULL);
    }

    /* Сокращенный вариант на 1 с */
    void enabletimer() {
        this->enabletimer(1000);
    }

    /* Бесконечный цикл обработки */
    int loop() {

        /* Пока титры не разлучат нас */
        while (1) {

            do_events();
            SDL_Delay(1);
        }

        return 0;
    }

    /* Выполнить оставшиеся события */
    void do_events() {

        /* Опрос событий, произошедших за 1 мс */
        while (SDL_PollEvent(& event)) {
            this->do_event(event.type);
        }
    }

    /* Получение типа event, если он есть */
    int has_event() {

        while (1) {

            /* Опрос событий, произошедших за 1 мс */
            while (SDL_PollEvent(& event)) {

                this->_event_type = event.type;
                return event.type;
            }

            /* Снижение нагрузки на процессор */
            SDL_Delay(1);
        }
    }

    /* Разрешение событий методами класса */
    int do_event(int evt_type) {

        switch (evt_type) {

            /* Если нажата на крестик, то приложение будет закрыто */
            case SDL_QUIT: return this->action_quit();

            /* Нажата мышь */
            case SDL_MOUSEBUTTONDOWN: this->action_mouse_down(); break;

            /* Кнопка мыши отжата */
            case SDL_MOUSEBUTTONUP: this->action_mouse_up(); break;

            /* Мышь перемещена */
            case SDL_MOUSEMOTION: this->action_mouse_motion(); break;

            /* Нажата какая-то клавиша */
            case SDL_KEYDOWN: this->action_key_down( keycode = get_key(event) ); break;

            /* Вызывается по таймеру */
            case SDL_USEREVENT: this->action_user_event(); break;
        }

        return 0;
    }

    // -----------------------------------------------------------------
    // Графические построения
    // -----------------------------------------------------------------

    /* Рисуется точка */
    void pset(int x, int y, uint color) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
            ( (Uint32*)sdl_screen->pixels )[ x + width*y ] = color;
        }
    }

    /* Обменять буфер экрана */
    void flip() {
        SDL_Flip(sdl_screen);
    }

    /*
     * Рисование линии по алгоритму Брезенхема
     * https://ru.wikipedia.org/wiki/Алгоритм_Брезенхэма
     */
    void line(int x1, int y1, int x2, int y2, uint color) {

        // Инициализация смещений
        int signx  = x1 < x2 ? 1 : -1;
        int signy  = y1 < y2 ? 1 : -1;
        int deltax = x2 > x1 ? x2 - x1 : x1 - x2;
        int deltay = y2 > y1 ? y2 - y1 : y1 - y2;
        int error  = deltax - deltay;
        int error2;

        // Если линия - это точка
        this->pset(x2, y2, color);

        // Перебирать до конца
        while ((x1 != x2) || (y1 != y2)) {

            this->pset(x1, y1, color);

            error2 = 2 * error;

            // Коррекция по X
            if (error2 > -deltay) {
                error -= deltay;
                x1 += signx;
            }

            // Коррекция по Y
            if (error2 < deltax) {
                error += deltax;
                y1 += signy;
            }
        }
    }

    /* Рисование окружности */
    void circle(int xc, int yc, int radius, uint color) {

        int x = 0,
            y = radius,
            d = 3 - 2*y;

        while (x <= y) {

            // Верхний и нижний сектор
            this->pset(xc - x, yc + y, color);
            this->pset(xc + x, yc + y, color);
            this->pset(xc - x, yc - y, color);
            this->pset(xc + x, yc - y, color);

            // Левый и правый сектор
            this->pset(xc - y, yc + x, color);
            this->pset(xc + y, yc + x, color);
            this->pset(xc - y, yc - x, color);
            this->pset(xc + y, yc - x, color);

            d += (4*x + 6);
            if (d >= 0) {
                d += 4*(1 - y);
                y--;
            }

            x++;
        }
    }

    // Рисование окружности
    void circle_fill(int xc, int yc, int radius, uint color) {

        int x = 0,
            y = radius,
            d = 3 - 2*y;

        while (x <= y) {

            // Верхний и нижний сектор
            this->line(xc - x, yc + y, xc + x, yc + y, color);
            this->line(xc - x, yc - y, xc + x, yc - y, color);

            // Левый и правый сектор
            this->line(xc - y, yc + x, xc + y, yc + x, color);
            this->line(xc - y, yc - x, xc + y, yc - x, color);

            d += (4*x + 6);
            if (d >= 0) {
                d += 4*(1 - y);
                y--;
            }

            x++;
        }
    }

    // Печать отладочной строки на экране
    void print(int x, int y, const char* s, int color, int bgcolor) {

        int i, j, k = 0, chr, font;

        while (s[k]) {

            chr = s[k]; k++;

            for (i = 0; i < 16; i++) {

                font = BiosFontRus[ chr*16 + i ];
                for (j = 0; j < 8; j++) {

                    if (font & (1 << (7 - j))) {
                        pset(x + j, y + i, color);
                    } else if (bgcolor >= 0) {
                        pset(x + j, y + i, bgcolor);
                    }
                }
            }

            x += 8;
        }
    }

    // -----------------------------------------------------------------

    void set_memory(unsigned char* m_) {
        m = m_;
    }

    // Запись в память
    void write(int addr) {

        switch (videomode) {

            case 0x03: update_text_char(addr); break;
            case 0x13: update_13h_pixel(addr); break;
        }
    }

    // Установка курсора
    void set_cursor(int x, int y) {

        int old_x = cursor_x,
            old_y = cursor_y;

        cursor_x = x;
        cursor_y = y;

        m[ BDA_CURSOR_X ] = x & 0xff;
        m[ BDA_CURSOR_Y ] = y & 0xff;

        update_text_char(0xb8000 + 2*(old_y*80 + old_x)); // Обновить в старой позиции
        update_text_char(0xb8000 + 2*(    y*80 +     x)); // Обновить в новой позиции
    }

    // Перерисовка дисплея в разных режимах
    int redraw() {

        int i;

        switch (videomode) {

            case 0x03: // 80x25x16 TEXT

                for (i = 0xb8000; i < 0xb8000 + 4000; i += 2)
                    update_text_char(i);

                break;

            case 0x13: // 320x200x256 VID

                for (i = 0xa0000; i < 0xa0000 + 64000; i++)
                    update_13h_pixel(i);

                break;

            default: return 0;
        }

        flip();

        return 1;
    }

    // Рисование точки на экране
    void update_13h_pixel(int addr) {

        int color, i, j;

        if (addr >= 0xa0000 && addr < 0xa0000 + 64000) {

            int a = addr - 0xa0000;
            int y = 4*(a / 320);
            int x = 4*(a % 320);

            touche = 1;
            color  = dac[ m[ addr ] ];

            for (i = 0; i < 4; i++)
            for (j = 0; j < 4; j++)
                pset(x + j, y + i, color);
        }
    }

    // Перерисовать символ на экране
    void update_text_char(int addr) {

        int addrin, chr, attr, font, i, j, x, y,
            color_bg, color_fr, color, cx, cy;

        if (addr >= 0xb8000 && addr < (0xb8000 + 4000) && (videomode == 0x03)) {

            addrin = addr & 0xffffe;
            touche = 1;

            // Расчет позиции (x, y)
            x    = (addr - 0xb8000) >> 1;
            y    = x / 80;
            x    = x % 80;
            cx   = x;
            cy   = y;
            x  <<= (3 + 1);
            y  <<= (4 + 1);

            chr  = m[ addrin + 0 ];
            attr = m[ addrin + 1 ];

            color_fr = dac[  attr & 0x0F ];
            color_bg = dac[ (attr & 0x70) >> 4 ];

            for (i = 0; i < 16; i++) {

                font = BiosFontRus[ chr*16 + i ];
                for (j = 0; j < 8; j++) {

                    // Есть ли курсор и мигнул ли он?
                    int inv = (cursor_blink && cursor_start <= i && i <= cursor_end && cx == cursor_x && cy == cursor_y);

                    color = (font & (1 << (7 - j))) ^ inv ? color_fr : color_bg;

                    // 2x2 точки
                    pset(x + 2*j + 0, y + 2*i + 0, color);
                    pset(x + 2*j + 0, y + 2*i + 1, color);
                    pset(x + 2*j + 1, y + 2*i + 0, color);
                    pset(x + 2*j + 1, y + 2*i + 1, color);
                }
            }
        }
    }

    // -----------------------------------------------------------------
    // Действия, которые можно реализовать
    // -----------------------------------------------------------------

    int  action_quit() { exit(0); }
    void action_mouse_down() { }
    void action_mouse_up() { };
    void action_mouse_motion() { };
    void action_key_down(int code) { };
    void action_key_up(int code) { };

    void action_user_event();
};
