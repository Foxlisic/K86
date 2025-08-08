#include "machine.h"

// Главная работа с окном и данными
int main (int argc, char** args) {

    machine x86(640, 400, 1, 25);

    // Инициализация эмулятора
    if (x86.init(argc, args)) {
        return 1;
    }
    
    // Тестовое выполнение
    // --------------------------------------
    for (int i = 0xb8000; i < 0xb8000+4000; i++) x86.write_byte(i, (i>>1) & 255);    
    x86.repaint_text();

    for (int i = 0; i < 32; i++) {
        
        x86.step();
        //x86.regdump();
        if (x86.halted()) break;
    }
    x86.regdump();
    // --------------------------------------

    // @todo while (x86.handler()) { }

    x86.destroy();
    return 0;
};
