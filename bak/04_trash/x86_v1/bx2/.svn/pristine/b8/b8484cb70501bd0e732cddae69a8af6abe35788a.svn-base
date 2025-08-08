
// 8 разрядная арифметика
// -----------------------------------------------------------------------------

// Сложение без переноса 8|16|32
dword addbw(dword a, dword b, byte size) {

    qword c = (qword)a + (qword)b;
    MAKE_SZMASK;
    ARITH_ZNPCA;
    ARITH_OVERFLOW_ADD;
    return c & m;
}

// Сложение с переносом
dword adcbw(dword a, dword b, byte size) {

    qword c = (qword)a + (qword)b + (qword)get_carry();
    MAKE_SZMASK;
    ARITH_ZNPCA;
    ARITH_OVERFLOW_ADD;
    return c & m;
}

// Вычитание без переноса
dword subbw(dword a, dword b, byte size) {

    qword c = (qword)a - (qword)b;
    MAKE_SZMASK;
    ARITH_ZNPCA;
    ARITH_OVERFLOW_SUB;
    return c & m;
}

// Вычитание с переносом
dword sbbbw(dword a, dword b, byte size) {

    qword c = (qword)a - (qword)b - (qword)get_carry();
    MAKE_SZMASK;
    ARITH_ZNPCA;
    ARITH_OVERFLOW_SUB;
    return c & m;
}

// Логическая операция AND
dword andbw(dword a, dword b, byte size) {

    dword c = a & b;
    ARITH_LOGIC;
    return c;
}

// Логическая операция XOR
dword xorbw(dword a, dword b, byte size) {

    dword c = a ^ b;
    ARITH_LOGIC;
    return c;
}

// Логическая операция OR
dword orbw(dword a, dword b, byte size) {

    dword c = a | b;
    ARITH_LOGIC;
    return c;
}

// Десятичная коррекция после сложения
void daa() {

    byte al = regs[REG_AL];
    word tempi;

    // Коррекция младшей части
    if ((eflags & A_FLAG) || ((al & 0x0F) > 9)) {

        tempi = ((word) al) + 6;
        al += 6;
        eflags |= A_FLAG;
        if (tempi & 0x100) eflags |= C_FLAG;
    }

    // Коррекция старшей части
    if ((eflags & C_FLAG) || (al > 0x9F)) {

        al += 0x60;
        eflags |= C_FLAG;
    }

    set_znpb(al);
    put_regb(REG_AL, al);
}

// Десятичная коррекция после вычитания
void das() {

    byte al = regs[REG_AL];
    word tempi;

    if ((eflags & A_FLAG) || ((al & 0x0F) > 9))
    {
        tempi = ((word)al) - 6;
        al -= 6;
        eflags |= A_FLAG;
        if (tempi & 0x100) eflags |= C_FLAG;
    }

    if ((eflags & C_FLAG) || (al > 0x9F))
    {
        al -= 0x60;
        eflags |= C_FLAG;
    }

    set_znpb(al);
    put_regb(REG_AL, al);
}

// ASCII-коррекция после сложения
void aaa() {

    byte al = regs[REG_AL];
    byte ah = regs[REG_AX] >> 8;

    if ((eflags & A_FLAG) || ((al & 0xF) > 9))
    {
        al += 6;
        ah++;
        eflags |= (A_FLAG|C_FLAG);
    }
    else
       eflags &= ~(A_FLAG|C_FLAG);

    opsize = 0;
    put_regw(REG_AX, (al & 15) + ((word)ah << 8));
}

// ASCII-коррекция после вычитания
void aas() {

    byte al = regs[REG_AL];
    byte ah = regs[REG_AX] >> 8;

    if ((eflags & A_FLAG) || ((al & 0xF) > 9))
    {
        al-=6;
        ah--;
        eflags |= (A_FLAG|C_FLAG);
    }
    else
        eflags &= ~(A_FLAG|C_FLAG);

    opsize = 0;
    put_regw(REG_AX, (al & 15) + ((word)ah << 8));
}

// Коррекция после умножения
void aam() {

    opsize = 0;
    byte tb = fetch();
    byte al = regs[REG_AL];
    put_regb(REG_AH, al / tb);
    put_regb(REG_AL, al % tb);
    set_znpw(regs[REG_AX] & 0xFFFF);
}

// Коррекция после деления
void aad() {

    opsize = 0;
    byte tb = fetch();
    byte al = regs[REG_AL];
    byte ah = (regs[REG_AX] >> 8);
    put_regw(REG_AX, (ah*tb + al) & 0x00FF);
    set_znpw(regs[REG_AX] & 0xFFFF);
}
