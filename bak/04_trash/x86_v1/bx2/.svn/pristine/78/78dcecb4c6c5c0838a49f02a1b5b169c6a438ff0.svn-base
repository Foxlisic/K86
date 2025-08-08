#include "machine.h"
#include "cpu.h"
#include "fonts.h"

// Инициализировать память и переменные
void machine_init() {

    // Заполнить тестовыми данными
    for (int i = 0xb8000; i < 0xb8000 + 4000; i += 2) {
        memory[i]   = i & 255;
        memory[i+1] = 0x07;
    }

    cursor_x = 0;
    cursor_y = 0;
    cursor_s = 14;
    cursor_e = 15;

    readbios("bios/top.bin", 0xffff0);
    cpu_reset();
}

// Чтение куска файла в память
void readbios(const char* filename, dword address) {

    FILE* fp = fopen(filename, "rb");
    if (fp == NULL) exit(1);

    fseek(fp, 0, SEEK_END);
    int fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    fread(memory + address, 1, fsize, fp);
    fclose(fp);
}

// Рисование на экране символа ch в текстовом режиме
// ch-номер символа от 0..255
// attr-это атрибут в виде attr[7:4] цвет фона attr[3:0] цвет буквы
void update_char(int x, int y, byte ch, byte attr) {

    int cursor_match = (cursor_flash > 8) && (cursor_x == x && cursor_y == y);

    for (int i = 0; i < 16; i++)  {

        byte mask = asciicp866[ch][i];
        for (int j = 0; j < 8; j++) {

            int fr = (attr & 15), bg = (attr >> 4);
            int cl = !!(mask & (1 << (7-j)));

            cl = cl ^ (cursor_match && i >= cursor_s && i <= cursor_e) ? fr : bg;
            pset(8*x + j, 16*y + i, dac(cl));
        }
    }
}

// Обновление всего экрана B8000h
void update_screen() {

    for (int y = 0; y < 25; y++)
    for (int x = 0; x < 80; x++) {

        word at   = 2*x + 160*y;
        byte ch   = memory[0xB8000 + at];
        byte attr = memory[0xB8001 + at];

        update_char(x, y, ch, attr);
    }

    if (++cursor_flash >= 18) cursor_flash = 0;
}

// Обработчик окна при вызове таймера
void display() {

    update_screen();
    update();
}

// Вывести отладку
void debugreg() {

    printf("eax: %08x\n", regs[REG_EAX]);
    printf("ebx: %08x\n", regs[REG_EBX]);
    printf("ecx: %08x\n", regs[REG_ECX]);
    printf("edx: %08x\n", regs[REG_EDX]);
    printf("esp: %08x\n", regs[REG_ESP]);
    printf("ebp: %08x\n", regs[REG_EBP]);
    printf("esi: %08x\n", regs[REG_ESI]);
    printf("edi: %08x\n", regs[REG_EDI]);
    printf(" es: %04x [%08x, %08x]\n", segs[REG_ES].selector, segs[REG_ES].base, segs[REG_ES].limit);
    printf(" cs: %04x [%08x, %08x]\n", segs[REG_CS].selector, segs[REG_CS].base, segs[REG_CS].limit);
    printf(" ss: %04x [%08x, %08x]\n", segs[REG_SS].selector, segs[REG_SS].base, segs[REG_SS].limit);
    printf(" ds: %04x [%08x, %08x]\n", segs[REG_DS].selector, segs[REG_DS].base, segs[REG_DS].limit);
    printf(" fs: %04x [%08x, %08x]\n", segs[REG_FS].selector, segs[REG_FS].base, segs[REG_FS].limit);
    printf(" gs: %04x [%08x, %08x]\n", segs[REG_GS].selector, segs[REG_GS].base, segs[REG_GS].limit);
    printf("eip:    %08x\n", eip);
    printf("eflags: %c%c%c%c%c%c_%c_%c_%c\n",
        eflags & V_FLAG ? 'O' : ' ',
        eflags & D_FLAG ? 'D' : ' ',
        eflags & I_FLAG ? 'I' : ' ',
        eflags & T_FLAG ? 'T' : ' ',
        eflags & N_FLAG ? 'S' : ' ',
        eflags & Z_FLAG ? 'Z' : ' ',
        eflags & A_FLAG ? 'A' : ' ',
        eflags & P_FLAG ? 'P' : ' ',
        eflags & C_FLAG ? 'C' : ' '
    );
    
    printf("mod_seg: %08x\n", segment->base);
    printf("mod_ea:  %08x\n", mod_ea);
}

// Работа с памятью и внешними устройствами
// 1 MB доступен
// -----------------------------------------------------------------------------
byte phy_read(dword address) {
    return memory[address & 0xFFFFF];
}

void phy_write(dword address, byte data) {
    memory[address & 0xFFFFF] = data;
}

byte ioread(word port) { return 0xff; }
void iowrite(word port, byte data) { }
// -----------------------------------------------------------------------------
