#include "machine.h"

machine::machine(int w, int h, int scale, int fps) {
    createwin(w, h, scale, "SDL2 Window", fps);
}

machine::~machine() {
    destroy();
}

// -----------------------------------------------------------------
// Обработка окна
// -----------------------------------------------------------------

// Создать няшное окно
int machine::createwin(int w, int h, int scale, const char* name = "SDL2", int fps = 50) {

    unsigned format = SDL_PIXELFORMAT_BGRA32;

    _scale      = scale;
    _width      = w;
    _height     = h;
    _frameid    = 0;
    kb_trigger  = 0;

    width  = w * scale;
    height = h * scale;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        return 1;
    }

    SDL_ClearError();

    // Создать окно
    sdl_window = SDL_CreateWindow(name,SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN);
    if (sdl_window == NULL) return 1;

    // Создать отрисовщик текстур
    sdl_renderer = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
    if (!sdl_renderer) return 2;

    // Формат пикселей
    sdl_pixel_format = SDL_AllocFormat(format);
    if (!sdl_pixel_format) return 3;

    //  Создать текстуру в памяти
    sdl_screen_texture = SDL_CreateTexture(sdl_renderer, format, SDL_TEXTUREACCESS_STREAMING, width, height);
    if (!sdl_screen_texture) return 4;

    // Смешивания текстур нет
    SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

    // Буфер экрана в памяти
    screen_buffer    = (Uint32*)malloc(width * height * sizeof(Uint32));

    // Настройка FPS
    frame_length     = 1000 / (fps ? fps : 1);
    frame_prev_ticks = SDL_GetTicks();

    return 0;
}

// Ожидание событий
int machine::handler() {

    for (;;) {

        Uint32 ticks = SDL_GetTicks();

        // Ожидать наступления события
        while (SDL_PollEvent(&event)) {

            switch (event.type) {

                case SDL_QUIT: {
                    return 0;
                }

                // https://wiki.machinesdl.org/SDL_Scancode
                case SDL_KEYDOWN: {

                    kb_code = event.key.keysym.scancode;
                    return 1;
                }
            }
        }

        // Истечение таймаута
        if (ticks - frame_prev_ticks >= frame_length) {

            _frameid++;
            frame_prev_ticks = ticks;
            update();
        }

        SDL_Delay(1);
    }
}

// Обновить окно
void machine::update() {

    SDL_Rect dstRect;

    dstRect.x = 0;
    dstRect.y = 0;
    dstRect.w = width;
    dstRect.h = height;

    SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, width * sizeof(Uint32));
    SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
    SDL_RenderClear         (sdl_renderer);
    SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, &dstRect);
    SDL_RenderPresent       (sdl_renderer);
}

// Уничтожение окна
void machine::destroy() {

    if (sdl_screen_texture) {
        SDL_DestroyTexture(sdl_screen_texture);
        sdl_screen_texture = NULL;
    }

    if (sdl_pixel_format) {
        SDL_FreeFormat(sdl_pixel_format);
        sdl_pixel_format = NULL;
    }

    if (sdl_renderer) {
        SDL_DestroyRenderer(sdl_renderer);
        sdl_renderer = NULL;
    }

    free(screen_buffer);
    free(memory);

    SDL_DestroyWindow(sdl_window);
    SDL_Quit();
}

// Получение последнего нажатого сканкода
int machine::get_kbcode() {

    if (kb_trigger) {
        kb_trigger = 0;
        return kb_code;
    }

    return 0;
}

// -----------------------------------------------------------------
// Рисование в буфере
// -----------------------------------------------------------------

// Установка точки
void machine::pset(int x, int y, Uint32 cl) {

    if (x < 0 || y < 0 || x >= _width || y >= _height)
        return;

    if (_scale == 1) {
        screen_buffer[y*width + x] = cl;
    } else {
        for (int i = 0; i < _scale; i++)
        for (int j = 0; j < _scale; j++)
            screen_buffer[(_scale*y+i)*width + (_scale*x + j)] = cl;
    }
}

// Печать текстового символа
void machine::print_char(int x, int y, unsigned char ch, int attr) {
    
    int fore = attr & 15;
    int back = attr >> 4;
    
    for (int i = 0; i < 16; i++)         
    for (int j = 0; j < 8; j++) {
        
        int cl = font_8x16[ch][i] & (0x80 >> j) ? fore : back;
        pset(x*8 + j, y*16 + i, dac[cl & 15]);        
    }
}

// Перерисовать текстовый экран
void machine::repaint_text() {
    
    for (int i = 0; i < 25; i++)
    for (int j = 0; j < 80; j++) {
        
        int addr = 0xB8000 + i*160 + j*2;        
        print_char(j, i, memory[addr], memory[addr+1]);        
    }
}

// -----------------------------------------------------------------
// Периферия и прочее
// -----------------------------------------------------------------

int machine::init(int argc, char* argv[]) {

    int i = 1;
    int address = 0xf0000;
    int tmp;

    // Проверка на корректную разрядность
    if (sizeof(word)  != 2) return 1;
    if (sizeof(dword) != 4) return 1;
    if (sizeof(qword) != 8) return 1;
    
    // Создать память для процессора
    memory = (byte*) malloc(MAX_MEMORY);

    // Сбросить процессор
    reset();

    while (i < argc) {

        char* cp = argv[i];

        // Параметр аргумента
        if (cp[0] == '-') {

            switch (cp[1]) {

                // Адрес загрузки файла в память (-a f0000)
                case 'a': sscanf(argv[i+1], "%x", &address); i++; break;

                // Установить в CS:EIP (-p ffff:0000)
                case 'p': sscanf(argv[i+1], "%x:%x", &tmp, &eip); segs[cs] = tmp; i++; break;
            }
        }
        // Это файл
        else {

            FILE* fp = fopen(argv[i], "rb");
            
            if (fp) {

                fseek(fp, 0, SEEK_END);
                int size = ftell(fp);
                fseek(fp, 0, SEEK_SET);
                fread(memory + address, 1, size, fp);
                fclose(fp);
                
                printf("LOAD %s FILE TO %x\n", argv[i], address);

            } else {

                printf("File %s not found\n", argv[i]);
                return 2;
            }
        }

        i++;
    }
    
    return 0;
}

// Запись в порт
void machine::iowrite(word address, byte data) {
}

// Чтение из порта
byte machine::ioread(word address) {
    
    return 0xFF;
}