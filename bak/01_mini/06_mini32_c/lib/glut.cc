#include "glut.h"

#include <stdio.h>
#include <stdlib.h>

// Запустить экран
void screen(int mode) {

    int   argc = 0;
    char* argv[1];
    
    switch (mode) {
        
        case  3: app_width = 1280; app_height = 800; app_factor = 2; break;
        case 12: app_width = 640; app_height = 480; app_factor = 2; break;
        case 13: app_width = 960; app_height = 600; app_factor = 3; break;
        default: exit(1);       
    }
    
    // Инициализация переменных
    app_interval = 25;

    // Запустить окно
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(app_width, app_height);
    glutInitWindowPosition(0, 0);
    glutCreateWindow("GLUT BASIC");
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluOrtho2D(-1.0, 1.0, -1.0, 1.0);

    // Выделить необходимую область памяти
    app_membuf = (unsigned char*) malloc(app_width * app_height * 4);
}

void start(int interval) {

    glutDisplayFunc(display);
    
    if (interval) {
        
        app_interval = interval;
        timer_function(0);        
    }
    
    glutMainLoop();
}

// Обработчик таймера
void timer_function(int value) {

    glutPostRedisplay();
    glutTimerFunc(app_interval, timer_function, 0);
}

// Преобразовать цвет в DOS
int dac(int c) {    
    return doscolortable[c & 255];
}

// Нарисовать точку
void pset(int x, int y, unsigned int cl) {

    x *= app_factor;
    y *= app_factor;

    if (x < 0 || y < 0 || x >= app_width || y >= app_height)
        return;

    for (int i = 0; i < app_factor; i++)
    for (int j = 0; j < app_factor; j++) {

        int cursor = 4*(j+x + (app_height-1-i-y)*app_width);
        app_membuf[cursor++] = cl>>16;
        app_membuf[cursor++] = cl>>8;
        app_membuf[cursor++] = cl;
        app_membuf[cursor++] = 255;
    }
}

// Получение точки с учетом factor
int point(int x, int y) {
    
    x *= app_factor;
    y *= app_factor;
    
    int cursor = 4*(x + (app_height-1-y)*app_width);
    
    unsigned char r = app_membuf[cursor  ];
    unsigned char g = app_membuf[cursor+1];
    unsigned char b = app_membuf[cursor+2];
            
    return (r*65536 + g*256 + b);
}

// Обновить экран
void update() {

    glRasterPos2i(-1, -1);
    glDrawPixels(app_width, app_height, GL_RGBA, GL_UNSIGNED_BYTE, app_membuf);
    glutSwapBuffers();
}

// Сохранение изображения в PPM
void saveppm(const char* filename) {
    
    char temp[256];
    
    int w = app_width  / app_factor;
    int h = app_height / app_factor;
    
    FILE* fp = fopen(filename, "wb");
    if (fp == NULL) exit(2);
    
    sprintf(temp, "P6\n%d %d\n255\n", w, h);
    fputs(temp, fp);
    
    for (int y = 0; y < h; y++)
    for (int x = 0; x < w; x++) {
        
        int p = point(x, y);
        
        temp[0] = p>>16;
        temp[1] = p>>8;
        temp[2] = p;
        
        fwrite(temp, 1, 3, fp);       
    }
    
    fclose(fp);
}
