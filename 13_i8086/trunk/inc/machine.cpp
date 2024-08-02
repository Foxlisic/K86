class Machine {

protected:

    FILE* fp;   // ROM
    FILE* fd;   // Флоппи

    // Для установки DAC
    DisplaySDL* display;

    // Общая память 1 Мб + 64кб + 256 (XLATB)
    unsigned char mem[65535*16 + 65536 + 256];

    // VGA DAC
    int     vga_dac_index;
    int     vga_dac_phase;
    int     vga_dac_color;

public:

    // Загрузка ROM-файла в память
    Machine(char* file, int offset) {

        int cnt;

        fp = fopen(file, "r");
        if (fp == NULL) { exit(1); }

        do {

            cnt = fread(mem + offset, 1, 4096, fp);
            offset += 4096;

        } while (cnt > 0);

        // Программирование DAC
        vga_dac_index = 0;
        vga_dac_phase = 0;
        vga_dac_color = 0;

        fclose(fp);
    }

    void set_display(DisplaySDL* display_) {
        display = display_;
    }

    // Открыть флоппи-диск, если есть
    void open_floppy(char* filename) {
        fd = fopen(filename, "r+b");
    }

    // Готово ли устройство?
    int device_ready(int dl) {

        switch (dl) {

            case 0x00: return fd != NULL ? 1 : 0;
            default: return 0;
        }
    }

    // Чтение сектора, mode=0 read, mode=1 write
    int rw_sector(int mode, int dl, int lba, uint addr) {

        switch (dl) {

            case 0x00: { // Флоппи-диск

                // запрошен адовый сектор
                if (lba >= 2880) return 1;

                fseek(fd, 512*lba, SEEK_SET);

                if (mode == 0)
                    fread(mem + addr, 1, 512, fd);
                else
                    fwrite(mem + addr, 1, 512, fd);

                return 0;
            }
        }

        return 1;
    }

    // Указатель на память
    unsigned char* get_memory() {
        return mem;
    }

    // Запись в порт
    void port_out(uint addr, uint data) {

        data &= 0xff;

        if (addr == 0x3c8) { /* Запрос на DAC Index */

            vga_dac_index = data & 0xff;
            vga_dac_phase = 0;
        }
        else if (addr == 0x3c9) { /* Установка цвета */

            data = ((data << 2) & 0xff) | 3;

            switch (vga_dac_phase) {

                case 0: vga_dac_phase = 1; vga_dac_color =  data; break;
                case 1: vga_dac_phase = 2; vga_dac_color = (data << 8)  | vga_dac_color; break;
                case 2: vga_dac_phase = 0; vga_dac_color = (data << 16) | vga_dac_color;

                    display->dac[ vga_dac_index ] = vga_dac_color;
                    display->need_redraw = 1;
                    break;
            }

        }
    }

    // Чтение из порта
    uint port_in(uint addr) {
        return 0xffff;
    }
};


