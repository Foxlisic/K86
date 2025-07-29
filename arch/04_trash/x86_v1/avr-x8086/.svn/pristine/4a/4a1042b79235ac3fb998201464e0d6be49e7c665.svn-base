#ifndef LINUX_HOST
#include <windows.h>
#endif
#include <GL/glut.h>

#include "glut.h"

class glut {

protected:

    int width, height;
    int factor;
    unsigned char* membuf;

public:

    glut()  { membuf = NULL; }
    ~glut() { if (membuf) free(membuf); }

    void init(const char* name, int w, int h, int f) {

        int argc = 0;
        char* argv[1];
        init(argc, argv, name, w, h, f);
    }

    void init(int argc, char** argv, const char* name, int w, int h, int f) {

        width  = w;
        height = h;
        factor = f;

        glutInit(&argc, argv);
        glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
        glutInitWindowSize(width, height);
        glutInitWindowPosition(0, 0);
        glutCreateWindow(name);

        glClearColor(0.0, 0.0, 0.0, 0.0);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluOrtho2D(-1.0, 1.0, -1.0, 1.0);

        membuf = (unsigned char*) malloc(width * height * 4);
    }

    // Получение DOS-цвета
    int doscl(int id) { return doscolor[id & 255]; }

    // Нарисовать точку
    void pset(int x, int y, unsigned int cl) {

        x *= factor;
        y *= factor;

        if (x < 0 || y < 0 || x >= width || y >= height)
            return;

        for (int i = 0; i < factor; i++)
        for (int j = 0; j < factor; j++) {

            int cursor = (j+x + (height-1-i-y)*width)*4;
            membuf[cursor++] = cl>>16;
            membuf[cursor++] = cl>>8;
            membuf[cursor++] = cl;
            membuf[cursor++] = 255;
        }
    }

    // Обновить экран
    void update() {

        glRasterPos2i(-1, -1);
        glDrawPixels(width, height, GL_RGBA, GL_UNSIGNED_BYTE, membuf);
        glutSwapBuffers();
    }
};