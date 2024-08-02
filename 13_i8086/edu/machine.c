// Выдача регистров
void pc_regs() {

    printf("ax:$%04x   bx:$%04x   cx:$%04x   dx:$%04x\n", AX, BX, CX, DX);
    printf("SP:$%04x   bp:$%04x   si:$%04x   di:$%04x\n", SP, BP, SI, DI);
    printf("cs:$%04x   es:$%04x   ss:$%04x   ds:$%04x\n", CS, ES, SS, DS);
    printf("ip:$%04x ==> $%05x   flags = [", IP, (CS*16 + IP));

    printf(flag_over ? "O" : " ");
    printf(flag_dir  ? "D" : " ");
    printf(flag_int  ? "I" : " ");
    printf(flag_trap ? "T" : " ");
    printf(flag_sign ? "S" : " ");
    printf(flag_zero ? "Z" : " ");
    printf(flag_aux  ? "A" : " ");
    printf(flag_parity ? "P" : " ");
    printf(flag_carry ? "C" : " ");
    printf("]\n");
}

// Выдача дампа
void pc_dump(int addr) {

    int i, j;

    // \e[92m .. \e[39m
    printf("       +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

    for (i = 0; i < 4; i++) {
        printf("%05x: ", addr + i*16);
        for (j = 0; j < 16; j++) {
            printf("%02x ", memory[addr + i*16 + j]);
        }
        printf("\n");
    }
}

// Загрузка ROM
void pc_load_rom() {

    int     cnt, offset = 0xf0000;
    FILE*   fp = fopen("bios/bios.bin", "rb");

    if (fp == NULL) {
        printf("bios/bios.bin not found\n"); exit(0);
    }

    do {

        cnt = fread(memory + offset, 1, 4096, fp);
        offset += 4096;

    } while (cnt > 0);
    
    // Инструкция JMP $F000:$0000
    WRITE_BYTE(0xffff, 0, 0xEA);
    WRITE_WORD(0xffff, 1, 0x0000);
    WRITE_WORD(0xffff, 3, 0xF000);

    fclose(fp);
}
