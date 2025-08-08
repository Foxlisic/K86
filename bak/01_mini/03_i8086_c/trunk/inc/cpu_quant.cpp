CPU  cpu;
BIOS bios;

// 50 раз срабатывание таймера
void DisplaySDL::action_user_event() {

    clock_t start = clock(), end;
    double  cpu_time_used;
    double  peak = (1.0 / 50.0) * 0.90; // 90% host cpu
    char    s[250];

    int i;

    do { /* Допустимая нагрузка в течении 1/50 секунд */

        /* Исполнить квант времени cpu */
        for (i = 0; i < CPU_QUANT; i++) {
            cpu.step();
        }

        end = clock();
        cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;

    } while (cpu_time_used < peak);
    
    // Потребовалась полная перерисовка
    if (need_redraw) {
        
        touche = 1;
        redraw();
    }
    
    clock_t curclock = clock();

    // IRQ Timer
    if ((double)(curclock - time_irq) > (double)CLOCKS_PER_SEC / 18.1) { 

        // TIMER
        time_irq = curclock;
    }
    
    // Мерцание курсора
    if ((double)(curclock - time_cursor) > (double)CLOCKS_PER_SEC * 0.25) { 
        
        // Кол-во выполненных инструкции в секунду
        sprintf(s, "%3.0fM", 50.0 * ((double)cpu.get_tstates() / 1000000.0) );    
        print(1280 - 8*6, 800, s, 0xffffff, 0); 
        
        // Обновить курсор
        cursor_blink = 1 - cursor_blink;        
        set_cursor(cursor_x, cursor_y);

        touche = 1;
        time_cursor = curclock;
    }
    
    // Регистры
    if (cpu.cpu_halt) {

        touche = 1;

        sprintf(s, "ax:     cx:     dx:     bx:    "); print(8*0, 800, s, 0xc0c0c0, 0);
        sprintf(s, "   %04x    %04x    %04x    %04x", cpu.r.ax, cpu.r.cx, cpu.r.dx, cpu.r.bx); print(8*0, 800, s, 0x00ff00, -1);
        sprintf(s, "sp:     bp:     si:     di:    "); print(8*32, 800, s, 0xc0c0c0, 0);
        sprintf(s, "   %04x    %04x    %04x    %04x", cpu.r.sp, cpu.r.bp, cpu.r.si, cpu.r.di); print(8*32, 800, s, 0x00ff00, -1);
        sprintf(s, "es:     ss:     ds:     cs:ip       "); print(8*64, 800, s, 0xffff00, 0);
        sprintf(s, "   %04x    %04x    %04x       %04x:%04x", cpu.r.es, cpu.r.ss, cpu.r.ds, cpu.r.cs, cpu.ip); print(8*64, 800, s, 0x00ff00, -1);
    }

    cpu.reset_tstates();

    /* Обновить экран только если есть что обновлять */
    if (touche) { flip(); } touche = 0;
};
