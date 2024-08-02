# Ассемблировать "биос"
cd bios && fasm rom.asm && cd ..

# Компиляция файла i8086.c 
if (g++ `sdl-config --cflags --libs` i8086.cpp -lSDL -Wall -Wno-unused-result -Ofast -o i8086) then
    ./i8086 --dump 7df0
fi
