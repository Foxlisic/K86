// Запуск машины в работу
void machine_start(int argc, char* argv[]) {
    
    int width = 1280, height = 800, factor = 2;

    // Разбор параметров командной строки
    for (int i = 1; i < argc; i++) {     
    
        if (argv[i][0] == '-') {

            switch (argv[i][1]) {
                
                // Одинарный пиксель
                case '1': width = 640; height = 400; factor = 1; break;
            }                
        }
    }

    // Инициализация окна
    win.init(argc, argv, "x8086 emulator & debugger", width, height, factor);

    // Назначаем обработчики
    glutDisplayFunc(machine_update);
    machine_call_timer_func(0);

    // Запуск процесса в работу
    glutMainLoop();
}

// Вызов таймера каждые 20/1000 секунд
void machine_call_timer_func(int value) {

    glutPostRedisplay();
    glutTimerFunc(20, machine_call_timer_func, 0);
}

// Печать символа на экране в текстовом режиме
void machine_print_char(int x, int y, unsigned char ch) {

    for (int i = 0; i < 16; i++)
    {
        int mask = bios_font_16x8[ch][i];
        for (int j = 0; j < 8; j++) {

            int color = mask & (128 >> j) ? doscolor[15] : 0;
            win.pset(8*x + j, 16*y + i, color);
        }
    }
}

// Выполнение основных действий
void machine_update() {

    for (int y = 0; y < 400; y++)
    for (int x = 0; x < 640; x++)
        win.pset(x, y, win.doscl(x*y/256));

    machine_print_char(0, 0, 'x');

    win.update();
}

// Чтение из памяти
byte machine_read (dword address) {
    return memory[address & 0xfffff];
}

// Запись в память
void machine_write(dword address, byte data) {

    memory[address & 0xfffff] = data;
    // Отследить запись в видеопамять
}

// Чтение из порта
byte io_read(word port) {
    return 0xff;
}

// Запись в порт
void io_write(word port, byte data) {
}

