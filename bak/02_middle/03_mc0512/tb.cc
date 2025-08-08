#include "obj_dir/Vgpu.h"
#include "obj_dir/Vcpu.h"
#include "obj_dir/Vkbd.h"

#include "disasm.cc"
#include "tb.h"

App* app;

// Основной файл
int main(int argc, char* argv[]) {

    app = new App(argc, argv);

    int   instr   = 125000;
    int   maximum = 0;
    float target  = 100;

    // Исполнение одного фрейма
    while (app->main()) {

        Uint32 start = SDL_GetTicks();

        // Есть ограничение по скорости
        if (maximum && maximum < instr) instr = maximum;

        // Автоматическая коррекция кол-ва инструкции в секунду
        for (int i = 0; i < instr; i++) {
            app->tick();
        }

        // Коррекция тактов
        Uint32 delay = (SDL_GetTicks() - start);

        instr = (instr * (0.5 * target) / (float)delay);
        instr = instr < 1000 ? 1000 : instr;
    }

    return app->destroy();
}
