#include "machine.h"
#include "fonts.h"

// Инициализировать память и переменные
void machine_init() {
    
    for (int i = 0xb8000; i < 0xb8000 + 4000; i += 2) {
        memory[i]   = i & 255;
        memory[i+1] = 0x17;
    }
}

// Рисование на экране символа ch в текстовом режиме
// ch-номер символа от 0..255
// attr-это атрибут в виде attr[7:4] цвет фона attr[3:0] цвет буквы
void update_char(int x, int y, byte ch, byte attr) {
    
    x *= 8;
    y *= 16;
    
    for (int i = 0; i < 16; i++)  {
        
        byte mask = asciicp866[ch][i];
        for (int j = 0; j < 8; j++) {
                
            int cl = mask & (1 << (7-j)) ? (attr & 15) : (attr >> 4);
            pset(x + j, y + i, dac(cl));
        }
    }    
}

// Обновление всего экрана B8000h
void update_screen() {
    
    for (int y = 0; y < 25; y++)
    for (int x = 0; x < 80; x++) {
        
        word at   = 2*x + 160*y;
        byte ch   = memory[0xB8000 + at];
        byte attr = memory[0xB8001 + at];

        update_char(x, y, ch, attr); 
    }
}

// Обработчик окна при вызове таймера
void display() {
    
    
    update_screen();


    update();
}