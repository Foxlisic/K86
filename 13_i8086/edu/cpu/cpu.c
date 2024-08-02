// Запуск CPU
void INIT() {

    AX = 0x0000; BX = 0x0000; CX = 0x0000; DX = 0x0000;
    SP = 0x0000; BP = 0x0000; SI = 0x0000; DI = 0x0000;
    ES = 0x0000; CS = 0xF000; SS = 0x0000; DS = 0x0000;
    IP = 0xFFF0;
}

// Функции/макросы установки флагов (flag_*)
void SET_OVER   (uint value) { flag_over   = value ? 1 : 0; }        // Установка/сбро флага переполнения
void SET_SIGN   (uint value) { flag_sign   = value ? 1 : 0; }        // Флаг нуля
void SET_ZERO   (uint value) { flag_zero   = (value == 0) ? 1 : 0; } // Если равно 0, ставится ZF=1
void SET_AUX    (uint value) { flag_aux    = value ? 1 : 0; }        // Флаг полупереноса
void SET_CARRY  (uint value) { flag_carry  = value ? 1 : 0; }        // Флаг переноса
void SET_PARITY (uint dst) { // Вычисление флага четности

    byte par = ((dst & 0xf0)>>4) ^ (dst & 0x0f);
         par = ((par & 0x0c)>>2) ^ (par & 0x03);
         par = ((par & 0x02)>>1) ^ (par & 0x01);

    flag_parity = par ^ 1;
}

// Запись байта в память
void WRITE_BYTE(word segment, word address, byte data) {
    memory[ segment * 0x10 + address ] = (data) & 0xff;
}

// Чтение байта из памяти
byte READ_BYTE(word segment, word address) {
    return memory[ segment * 0x10 + address ];
}

// Запись слова в память
void WRITE_WORD(word segment, word address, word data) {

    WRITE_BYTE(segment, address+0, data);
    WRITE_BYTE(segment, address+1, data >> 8);
}

// Чтение байта из памяти
word READ_WORD(word segment, word address) {

    byte L = READ_BYTE(segment, address  );
    byte H = READ_BYTE(segment, address+1);
    return (H << 8) | L;
}

// Чтение байта из CS: IP
byte FETCH_BYTE() {

    byte L = READ_BYTE(CS, IP);
    IP = (IP + 1) & 0xffff;
    return L;
}

// Считывание -128..127
char FETCH_SIGNED_BYTE() {

    byte L = FETCH_BYTE();
    return (L < 0x80) ? L : 0x100 - L;
}

// Чтение слова из CS: IP
byte FETCH_WORD() {

    byte L = FETCH_BYTE();
    byte H = FETCH_BYTE();
    return (H << 8) | L;
}

// Получение 8-битного регистра
byte GET_REG8(byte id) {

    switch (id & 7) {

        /* AL */ case 0: return AX & 0xff;
        /* CL */ case 1: return CX & 0xff;
        /* DL */ case 2: return DX & 0xff;
        /* BL */ case 3: return BX & 0xff;
        /* AH */ case 4: return (AX >> 8) & 0xff;
        /* CH */ case 5: return (CX >> 8) & 0xff;
        /* DH */ case 6: return (DX >> 8) & 0xff;
        /* BH */ case 7: return (BX >> 8) & 0xff;
    }

    return 0;
}

// Получение 16-битного регистра
byte GET_REG16(byte id) {

    switch (id & 7) {

        case 0: return AX;
        case 1: return CX;
        case 2: return DX;
        case 3: return BX;
        case 4: return SP;
        case 5: return BP;
        case 6: return SI;
        case 7: return DI;
    }

    return 0;
}

// Сохранить в 8-битном регистре
void PUT_REG8(byte id, byte data) {

    switch (id & 7) {

        /* AL */ case 0: AX = (AX & 0xff00) | data; break;
        /* CL */ case 1: CX = (CX & 0xff00) | data; break;
        /* DL */ case 2: DX = (DX & 0xff00) | data; break;
        /* BL */ case 3: BX = (BX & 0xff00) | data; break;
        /* AH */ case 4: AX = (AX & 0x00ff) | (data << 8); break;
        /* CH */ case 5: CX = (CX & 0x00ff) | (data << 8); break;
        /* DH */ case 6: DX = (DX & 0x00ff) | (data << 8); break;
        /* BH */ case 7: BX = (BX & 0x00ff) | (data << 8); break;
    }
}

// Сохранить в 8-битном регистре
void PUT_REG16(byte id, word data) {

    switch (id & 7) {

        case 0: AX = data; break;
        case 1: CX = data; break;
        case 2: DX = data; break;
        case 3: BX = data; break;
        case 4: SP = data; break;
        case 5: BP = data; break;
        case 6: SI = data; break;
        case 7: DI = data; break;
    }
}

// Прочитать память или регистр
byte GET_EB() {

    if (modrm_mod == 3) {
        return GET_REG8(modrm_r_m);
    } else {
        return READ_BYTE(segment, modrm_ea);
    }
}

// Прочитать память или регистр
word GET_EV() {

    if (modrm_mod == 3) {
        return GET_REG16(modrm_r_m);
    } else {
        return READ_WORD(segment, modrm_ea);
    }
}

// Прочитать регистр 8 бит
byte GET_GB() {
    return GET_REG8(modrm_reg);
}

// Прочитать регистр 16 бит
word GET_GV() {
    return GET_REG16(modrm_reg);
}

// Запись байта в память/регистр
void PUT_EB(byte value) {

    if (modrm_mod == 3) {
        PUT_REG8(modrm_r_m, value);
    } else {
        WRITE_BYTE(segment, modrm_ea, value);
    }
}

// Запись слова в память/регистр
void PUT_EV(word value) {

    if (modrm_mod == 3) {
        PUT_REG16(modrm_r_m, value);
    } else {
        WRITE_WORD(segment, modrm_ea, value);
    }
}

// Запись в регистр 8 бит
void PUT_GB(byte value) {
    PUT_REG8(modrm_reg, value);
}

// Запись в регистр 16 бит
void PUT_GV(word value) {
    PUT_REG16(modrm_reg, value);
}
