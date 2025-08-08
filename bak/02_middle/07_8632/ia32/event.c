/*
 * События
 */

SDL_KeyboardEvent   *eventkey;
SDL_Event           event;

int fps;

// Получение клавиши
int get_key_code(SDL_Event event) {            
     
    eventkey = &event.key;
    
    // printf( "Scancode: 0x%02X", eventkey->keysym.scancode );
    // https://www.libsdl.org/release/SDL-1.2.15/docs/html/sdlgetkeyname.html
    // printf( ", Name: %s\n", SDL_GetKeyName( eventkey->keysym.sym ) );
    
    /* Получить скан-код клавиш */
    return eventkey->keysym.scancode;
}

// Таймер, который вызывается раз 1/60 секунду
Uint32 TimerFPS(Uint32 interval, void *param) {
    
    SDL_Event     event;
    SDL_UserEvent userevent;
    
    fps = fps == 50 ? 0 : fps + 1;
    
    /* Создать новый Event */
    userevent.type  = SDL_USEREVENT;
    userevent.code  = 0;
    userevent.data1 = NULL;
    userevent.data2 = NULL;

    event.type = SDL_USEREVENT;
    event.user = userevent;

    SDL_PushEvent(&event);
    return(interval);    
}

void init_event() {
        
    fps = 0;    
    SDL_AddTimer(20, TimerFPS, NULL);
}

void KeyF7() {
    
    step();

    // Установка курсора
    cursor_at = eip;
    
    // eip = eip + 2;
    update();    
    
}

void KeyF8() {
    
}
