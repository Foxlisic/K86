#include <stdlib.h>
#include <stdio.h>

// ---------------------------------------------------------------------
#include "cpu/cpu.h"
#include "cpu/modrm.h"

#include "cpu/cpu.c"
#include "cpu/modrm.c"
#include "cpu/fetch.c"
#include "cpu/misc.c"

// Арифметические
#include "cpu/arith.c"

// Набор инструкции
#include "cpu/instruction.c"
#include "cpu/instruction.h"
#include "cpu/step.c"

#include "machine.c"

int main(int argc, char* argv[]) {

    INIT(); pc_load_rom();

    STEP();

    pc_regs(); pc_dump(0xf0000);

    return 0;
}
