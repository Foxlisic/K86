#include <iostream>
#include <SDL2/SDL.h>

#include "fontable.h"
#include "disasm.cc"
#include "portable86.cc"
#include "machine.cc"

machine comp;

int main(int argc, char** argv)
{
    comp.load(argc, argv);
    comp.create();
    comp.run();

    return 0;
}
