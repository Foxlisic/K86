#include "SDL.h"            // Требуется apt install libsdl1.2-dev
#include <stdio.h>

// --------------------------

#include "declare.h"

#include "memory.c"
#include "event.c"
#include "audio.c"
#include "video.c"
#include "instr.c"
#include "cpu.c"
#include "disas.c"
#include "load.c"

int main(int argc, char* argv[]) {

    /* Включение возможностей */
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER);

    init_event();
    init_video();
    init_audio();
    init_disas();
    init_cpu();
    
    preload(argc, argv);
        
    int kk;
    
    /* Вывести дизассемблер */
    update();
        
    /* Бесконечный цикл */
    while (1) {

        while (SDL_PollEvent(&event)) {
            
            switch (event.type) {

                // SDL_KEYUP
                
                /* Один кадр (1/60) */
                case SDL_USEREVENT: 

                    redraw();
                    break;
                
                /* Нажата кнопка выхода */
                case SDL_QUIT: 
                
                    exit(0);                

                /* Нажата какая-то клавиша */
                case SDL_KEYDOWN:

                    kk = get_key_code(event);
                    
                    switch (kk) {
                        
                        case 9: return 0;
                        case 73: KeyF7(); break;
                        case 74: KeyF8(); break;
                        
                    }                    

                    break;

                /* Дернута мышь */
                // case SDL_MOUSEMOTION:   
                           
                // default:
                // printf("I don't know what this event is!\n");
            }            
        }
        
        SDL_Delay(1); /* Снижение нагрузки на процессор */
    } 

    SDL_CloseAudio();      
    return 0;
}
