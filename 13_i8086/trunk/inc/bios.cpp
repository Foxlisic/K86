/* Странный БИОС */

// https://en.wikipedia.org/wiki/BIOS_interrupt_call
// https://en.wikipedia.org/wiki/BIOS_interrupt_call

class BIOS {

public:

    DisplaySDL* display;
    Machine*    machine;

    int tty_x, tty_y, tty_color;

    /*
    write16(0, 4*0x00, 0xF000); // ZERO EXCEPTION
    write16(0, 4*0x01, 0xF001); // TRACE
    write16(0, 4*0x02, 0xF002);
    write16(0, 4*0x03, 0xF003);
    write16(0, 4*0x04, 0xF004);
    write16(0, 4*0x05, 0xF005); // BOUND
    write16(0, 4*0x06, 0xF006);
    write16(0, 4*0x07, 0xF007);

    write16(0, 4*0x08, 0xF008); // IRQ0: Timer
    write16(0, 4*0x09, 0xF009); // IRQ1: Keyboard
    write16(0, 4*0x0A, 0xF00A);
    write16(0, 4*0x0B, 0xF00B);
    write16(0, 4*0x0C, 0xF00C);
    write16(0, 4*0x0D, 0xF00D);
    write16(0, 4*0x0E, 0xF00E);
    write16(0, 4*0x0F, 0xF00F);

    write16(0, 4*0x10, 0x0); // VIDEO SERVICE
    write16(0, 4*0x11, 0x1); // EQUIPMENT LIST
    write16(0, 4*0x12, 0x2); // GET CONVENTIONAL MEMORY SIZE
    write16(0, 4*0x13, 0x3); // DISK SERVICE
    write16(0, 4*0x14, 0x4); // SERIAL PORT
    write16(0, 4*0x15, 0x5); // MISC
    write16(0, 4*0x16, 0x6); // KEYBOARD
    write16(0, 4*0x17, 0x7); // PRINTER
    write16(0, 4*0x18, 0x8); // CASETTE BASIC
    write16(0, 4*0x19, 0x9); // NEXT BOOT
    write16(0, 4*0x1A, 0xA); // REAL TIME CLOCK SERVICE
    write16(0, 4*0x1B, 0xB); // PCI SERVICE
    write16(0, 4*0x1C, 0xC); // CTRL+BREAK

    for (i = 0x10; i < 0x1D; i++) {
        write16(0, 4*i + 2, 0xFFFF);
    }
    */

    // INT Данные
    // 1Dh Video Parameter Table
    // 1Eh Diskette Parameter Table
    // 1Fh Video Graphics Character Table

    BIOS() {

        tty_x = 0;
        tty_y = 0;
        tty_color = 0x07;
    }

    struct Tregs  r;
    struct Tflags f;

    // Увеличить TTY_Y++
    void inc_tty() {

        tty_y++;
        if (tty_y == 25) {
            tty_y = 24;
            // scrollup
        }
    }

    // Адрес LBA по CHS: sector_count=18, head_count=2
    int get_floppy_lbachs(int sector_count, int head_count) {

        int head = (r.dx & 0xff00) >> 8; // dh
        int sec  = (r.cx & 0x3f) - 1; // 0..62
        int cyl  = ((r.cx & 0xc0) << 2) | ((r.cx >> 8) & 0xff);

        return sector_count*(head + head_count*cyl) + sec;
    }

    // Записать характер в тти моде
    // AL - символ
    // BH - страница (игнорируется)
    // BL - цвет (графика)
    void int10_ah0e() {

        int addr, chr;

        // Текстовый
        switch (display->videomode) {

            case 0x03: { // Текстовый видеорежим

                chr = r.ax & 0xff;

                // Прокрутка
                if (chr == 0x0A) {
                    inc_tty();
                }
                // Возврат каретки
                else if (chr == 0x0D) {
                    tty_x = 0;

                }
                // Печать символа
                else {

                    addr = 0xb8000 + 2*(80*tty_y + tty_x);

                    display->m[ addr   ] = chr;
                    display->m[ addr+1 ] = tty_color;

                    tty_x++;
                    if (tty_x == 80) { tty_x = 0; inc_tty(); }

                    display->write(addr);
                }

                display->set_cursor(tty_x, tty_y);
                break;
            }

            default:

                printf("INT10h: 0Eh func for vmode=%xh unimplemented ", display->videomode); exit(1);
                break;
        }
    }

    // Передача управления INT 10h
    void int10_handler() {

        // Видеорежим
        int vmode = 0, page_size = 0, vid_cols = 0, vid_rows = 0, i;

        switch ((r.ax & 0xff00) >> 8) {

            case 0x00: { /* Установка видеорежима */

                tty_x = 0;
                tty_y = 0;

                vmode = r.ax & 0xff;
                display->videomode = vmode;

                if (vmode == 0x03) {

                    page_size = 0x1000;
                    vid_cols = 80;
                    vid_rows = 25;

                    // установка нового dac и очистка экрана
                    for (i = 0; i < 16; i++) display->dac[i] = display->dac16[i];
                    for (i = 0; i < 4000; i++) display->m[0xb8000 + i] = 0x00;

                } else if (vmode == 0x13) {

                    page_size = 0xFA00;
                    vid_cols = 40;
                    vid_rows = 25;

                    for (i = 0; i < 256; i++) display->dac[i] = display->dac256[i];
                    for (i = 0; i < 64000; i++) display->m[0xa0000 + i] = 0x00;
                }

                // Записать в BDA
                display->m[ BDA_VIDMODE ]   = vmode;
                display->m[ BDA_VIDCOLS ]   = vid_cols;
                display->m[ BDA_VIDROWS ]   = vid_rows;
                display->m[ BDA_PAGESIZEL ] = page_size & 0xff;
                display->m[ BDA_PAGESIZEH ] = page_size >> 8;

                // Если установленный видеорежим сработал
                f.c = display->redraw() ? 0 : 1;
                break;
            }
            case 0x0E: { /* Печать символа в режиме teletype */
                int10_ah0e();
                break;
            }
        }
    }

    // Работа с диском
    void int13_handler() {

        int ah = (r.ax >> 8) & 0xff;
        int dl = (r.dx & 0xff);
        int lba, addr;

        switch (ah) {

            case 0x00: { /* Рекалибровка */
                break;
            }
            case 0x01: { /* Код ошибки */

                r.ax = (r.ax & 0xff00) | display->m[ BDA_DISK_LASTSTATUS ];
                break;
            }

            /*
             * DL = номер диска (0=диск A...; 80H=тв.диск 0; 81H=тв.диск 1)
             * DH = номер головки чтения/записи
             * CH = номер дорожки (цилиндра)(0-n) =¬
             * CL = номер сектора (1-n) ===========¦== См. замечание ниже.
             * AL = число секторов (в сумме не больше чем один цилиндр)
             * ES:BX => адрес буфера вызывающей программы
             * 0:0078 => таблица параметров дискеты (для гибких дисков)
             * 0:0104 => таблица параметров тв.диска (для твердых дисков)
             */

            case 0x02:   /* Прочитать сектор */
            case 0x03: { /* Записать сектор */

                if (dl == 0x00) {
                    lba = get_floppy_lbachs(18, 2);
                } else {
                    panic("non-floppy not supported");
                }

                // Если устройство готово
                if (machine->device_ready(dl)) {

                    addr = r.es*16 + r.bx;

                    switch (ah) {

                        case 0x2: f.c = machine->rw_sector(0, dl, lba, addr); break;
                        case 0x3: f.c = machine->rw_sector(1, dl, lba, addr); break;
                    }

                    // ah=0x04 сектор не найден
                    if (f.c) r.ax = (r.ax & 0xff) | 0x0400;

                } else {

                    f.c = 1;
                    r.ax = (r.ax & 0xff) | 0x0F00; // ah=0x0F нет драйва
                }

                break;
            }
        }
    }
};
