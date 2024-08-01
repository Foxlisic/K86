// https://wiki.libsdl.org/SDL_AudioSpec
SDL_AudioSpec        sdl_audio = {44100, AUDIO_U8, 2, 0, 4096};

void audio_callback(void *data, unsigned char *stream, int len)
{
	for (int i = 0; i < len; i++) {        
		stream[i] = 128;
    }    
}

int init_audio() {
        
    sdl_audio.callback   = audio_callback;
    
    /* SDL Audio не получилось открыть? */
    if (SDL_OpenAudio(&sdl_audio, 0) < 0) { 
        return 1;
    }

    // Запуск
    SDL_PauseAudio(0);
    
    return 0;
}
