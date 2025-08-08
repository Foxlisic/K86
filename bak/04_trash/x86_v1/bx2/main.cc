#include <glut.cc>

#include "machine.cc"
#include "cpu.cc"

// Основная процедура, точка входа
int main(int argc, char* argv[]) {
    
    screen(2); 
    machine_init();
    
    regs[REG_EAX] = 0xa000ffff;
    regs[REG_EBX] = 0x5234424F;

    step();      
    debugreg();

    // 18 обновлений в секуду
    start(55);

    return 0;
}
