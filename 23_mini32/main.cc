#include <glut.cc>
#include "machine.cc"

// Основная процедура, точка входа
int main(int argc, char* argv[]) {
    
    screen(3); 
    machine_init();
    
    
    start(0);    
    return 0;
}
