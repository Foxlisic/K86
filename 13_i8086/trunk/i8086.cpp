#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

void panic(const char* s) { printf("%s", s); exit(1); }

#include "inc/bios.h"
#include "inc/cpu.h"

#include "inc/BiosFontRus.h"
#include "inc/display.cpp"
#include "inc/argparam.cpp"
#include "inc/machine.cpp"
#include "inc/bios.cpp"
#include "inc/cpu.cpp"
#include "inc/cpu_quant.cpp"

int main(int argc, char* argv[]) {

    // Инициализация и запуск
    ArgParam    arg(argc, argv);
    DisplaySDL  display(1280, 816); // 480*2+16
    Machine     pc(arg.get_romfile(), arg.get_romaddr());

    display.show("i8086");
    display.enabletimer(25);
    
    // Устройства
    pc.open_floppy( arg.get_floppy() );    
    pc.set_display( & display );    

    // Установка указателя на память для рендера
    display.set_memory( pc.get_memory() );

    // Связь CPU с Machine, Display и т.д.
    cpu.set_dump    ( arg.get_dump() );
    cpu.set_memory  ( pc.get_memory() );
    cpu.set_machine ( & pc );
    cpu.set_display ( & display );
    cpu.set_bios    ( & bios );
    cpu.set_cs_ip   ( 0xf000, 0 );

    // Связь BIOS
    bios.machine = & pc;
    bios.display = & display;

    display.loop();
}
