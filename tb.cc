#define SDL_MAIN_HANDLED

#include <stdlib.h>

#include "obj_dir/Vvideo.h"

#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdio.h>

class App {
protected:

    SDL_Window*     sdl_window;
    SDL_Renderer*   sdl_renderer;
    SDL_Texture*    sdl_screen_texture;
    Uint32*         screen_buffer;

    Uint32  width, height, _scale, _width, _height;
    Uint32  frame_id, frame_length, frame_prev_ticks;
    int     x, y, _hs, _vs;

    Vvideo* mod_ppu;

public:

    // -----------------------------------------------------------------------------
    // ОБЩИЕ МЕТОДЫ
    // -----------------------------------------------------------------------------

    App(int w, int h, int scale = 2, int fps = 25)
    {
        _scale   = scale;
        _width   = w;
        _height  = h;
         width   = w * scale;
         height  = h * scale;
        frame_id = 0;

        _hs = 1;
        _vs = 0;

        x = 0;
        y = 0;

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window          = SDL_CreateWindow("K86: THE EDGE", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN);
        sdl_renderer        = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer       = (Uint32*) malloc(_width * _height * sizeof(Uint32));
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, _width, _height);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        // Настройка FPS
        frame_length     = 1000 / (fps ? fps : 1);
        frame_prev_ticks = SDL_GetTicks();

        mod_ppu = new Vvideo;
    }

    // Ожидание событий
    int main()
    {
        SDL_Event evt;
        SDL_Rect  dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = width;
        dstRect.h = height;

        for (;;) {

            Uint32 ticks = SDL_GetTicks();

            // Ожидать наступления события
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Выход из программы по нажатии "крестика"
                    case SDL_QUIT: return 0;
                }
            }

            // Истечение таймаута: обновление экрана
            if (ticks - frame_prev_ticks >= frame_length) {

                frame_prev_ticks = ticks;

                SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, _width * sizeof(Uint32));
                SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
                SDL_RenderClear         (sdl_renderer);
                SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
                SDL_RenderPresent       (sdl_renderer);

                return 1;
            }

            SDL_Delay(1);
        }
    }

    // Уничтожение окна
    int destroy()
    {
        if (sdl_screen_texture) { SDL_DestroyTexture(sdl_screen_texture);   sdl_screen_texture  = NULL; }
        if (sdl_renderer)       { SDL_DestroyRenderer(sdl_renderer);        sdl_renderer        = NULL; }

        free(screen_buffer);

        SDL_DestroyWindow(sdl_window);
        SDL_Quit();

        return 0;
    }

    // -----------------------------------------------------------------------------
    // ФУНКЦИИ РИСОВАНИЯ
    // -----------------------------------------------------------------------------

    // Установка точки
    void pset(int x, int y, Uint32 cl)
    {
        if (x < 0 || y < 0 || x >= _width || y >= _height)
            return;

        screen_buffer[y*_width + x] = cl;
    }

    // Отслеживание сигнала RGB по HS/VS; save=1 сохранить фрейм как ppm, 2=как png
    void vga(int hs, int vs, int color)
    {
        if (hs) x++;

        // Отслеживание изменений HS/VS
        if (_hs == 0 && hs == 1) { x = 0; y++; }
        if (_vs == 1 && vs == 0) { x = 0; y = 0; }

        // Сохранить предыдущее значение
        _hs = hs;
        _vs = vs;

        // Вывод на экран
        pset(x - 48, y - 35, color);
    }

	// Основной обработчик (TOP-уровень)
	void tick()
    {
        mod_ppu->data = 0x12;

        mod_ppu->clock = 0; mod_ppu->eval();
        mod_ppu->clock = 1; mod_ppu->eval();

		vga(mod_ppu->hs, mod_ppu->vs, 65536*(mod_ppu->r << 4) + 256*(mod_ppu->g << 4) + (mod_ppu->b << 4));
	}
};

// Главный цикл работы программы
int main(int argc, char **argv)
{
    // -------------------------------------
    // Verilated::commandArgs(argc, argv);
    App* app = new App(640, 400);
    // -------------------------------------

    while (app->main()) {
        for (int i = 0; i < 150000; i++)
            app->tick();
    }

    return app->destroy();
}
