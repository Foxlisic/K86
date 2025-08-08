#include <SDL2/SDL.h>
// -----------------------------------------------------------------------------
#define WIDTH  640
#define HEIGHT 400
#define SCALE  2
// -----------------------------------------------------------------------------
SDL_Surface*    surface;
SDL_Window*     window;
SDL_Renderer*   renderer;
SDL_Texture*    texture;
SDL_Event       evt;
SDL_Rect        dstRect;
Uint32*         screen;
// -----------------------------------------------------------------------------
void pset(int, int, Uint32);
// -----------------------------------------------------------------------------
void frame()
{
}
// -----------------------------------------------------------------------------
int main(int argc, char** argv)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        exit(1);
    }

    dstRect.x = 0;
    dstRect.y = 0;
    dstRect.w = SCALE*WIDTH;
    dstRect.h = SCALE*HEIGHT;

    SDL_ClearError();
    window   = SDL_CreateWindow("Demoscene2", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, dstRect.w, dstRect.h, SDL_WINDOW_SHOWN);
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    screen   = (Uint32*) malloc(WIDTH * HEIGHT * sizeof(Uint32));
    texture  = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_NONE);

    Uint32 pticks = 0, nticks;

    for (;;) {

        // Прием событий
        while (SDL_PollEvent(& evt)) {

            // Событие выхода
            switch (evt.type) {

                case SDL_QUIT:

                    free(screen);
                    SDL_DestroyTexture(texture);
                    SDL_DestroyRenderer(renderer);
                    SDL_DestroyWindow(window);
                    SDL_Quit();
                    return 0;
            }
        }

        // Обновление 50 раз в секунду
        if ((nticks = SDL_GetTicks()) - pticks >= 20) {

            frame();
            pticks = nticks;

            SDL_UpdateTexture       (texture, NULL, screen, WIDTH * sizeof(Uint32));
            SDL_SetRenderDrawColor  (renderer, 0, 0, 0, 0);
            SDL_RenderClear         (renderer);
            SDL_RenderCopy          (renderer, texture, NULL, & dstRect);
            SDL_RenderPresent       (renderer);
        }

        SDL_Delay(1);
    }
}

// Установка точки
void pset(int x, int y, Uint32 cl)
{
    if (x < 0 || y < 0 || x >= WIDTH || y >= HEIGHT) {
        return;
    }

    screen[WIDTH*y + x] = cl;
}
