if (fasm bios.asm)
then

    if (gcc `sdl-config --cflags --libs` main.c -lSDL -Wall -o e8632)
    then

        echo "OK"
        
        # Скачать freedos http://joelinoff.com/blog/?p=431
        ./e8632 # fdos.img
    fi

fi
