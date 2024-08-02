// *** ГРАЖДАНЕ! СОБЛЮДАЙТЕ ПОРЯДОК ПОДКЛЮЧЕНИЯ ФАЙЛОВ! *** //

#include <glut.cc>
#include <stdio.h>

#include "typedef.h"
#include "machine.h"
#include "biosfont.h"
#include "cpu.h"
#include "cpu.cc"

glut    win;
CPU     cpu;

#include "machine.cc"

int main(int argc, char* argv[]) {
    
    machine_start(argc, argv);
    return 0;
}