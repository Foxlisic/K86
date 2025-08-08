#include "machine.h"

// Целочисленное сложение
dword machine::do_add(dword op1, dword op2, byte size) {

    sizing_alu;

    qword r = op1 + op2;

    set_of  (((op1 ^ op2 ^ _s) & (op1 ^ r)) & _s);
    set_af  ((op1 ^ op2 ^ r) & 0x10);
    set_cf  (r & _c);
    set_szp (r, _c);

    return r & _m;
}

// Целочисленное сложение с переносом
dword machine::do_adc(dword op1, dword op2, byte size) {

    sizing_alu;

    qword r = op1 + op2 + get_cf();

    set_of  (((op1 ^ op2 ^ _s) & (op1 ^ r)) & _s);
    set_af  ((op1 ^ op2 ^ r) & 0x10);
    set_cf  (r & _c);
    set_szp (r, _c);

    return r & _m;
}

// Целочисленное вычитание
dword machine::do_sub(dword op1, dword op2, byte size) {

    sizing_alu;

    qword r = op1 - op2;

    set_of  (((op1 ^ op2) & (op1 ^ r)) & _s);
    set_af  ((op1 ^ op2 ^ r) & 0x10);
    set_cf  (r & _c);
    set_szp (r, _c);

    return r & _m;
}

// Целочисленное вычитание с переносом
dword machine::do_sbb(dword op1, dword op2, byte size) {

    sizing_alu;

    qword r = op1 - op2 - get_cf();

    set_of  (((op1 ^ op2) & (op1 ^ r)) & _s);
    set_af  ((op1 ^ op2 ^ r) & 0x10);
    set_cf  (r & _c);
    set_szp (r, _c);

    return r & _m;
}

// Операция XOR
dword machine::do_xor(dword op1, dword op2, byte size) {
    
    sizing_alu;

    qword r = op1 ^ op2;
    
    set_of  (0);
    set_af  (0);
    set_cf  (0);
    set_szp (r, _c);
    
    return r & _m;
}

// Операция OR
dword machine::do_or(dword op1, dword op2, byte size) {
    
    sizing_alu;

    qword r = op1 | op2;
    
    set_of  (0);
    set_af  (0);
    set_cf  (0);
    set_szp (r, _c);
    
    return r & _m;
}

// Операция AND
dword machine::do_and(dword op1, dword op2, byte size) {
    
    sizing_alu;

    qword r = op1 & op2;
    
    set_of  (0);
    set_af  (0);
    set_cf  (0);
    set_szp (r, _c);
    
    return r & _m;
}

// Десятичная коррекция после сложения
void machine::daa() {

    byte AL = regs[eax];
    word tempi;

    // Коррекция младшего ниббла
    if ((eflags & A_FLAG) || ((AL & 0xF) > 9)) {

        tempi = ((word) AL) + 6;
        AL += 6;
        eflags |= A_FLAG;
        if (tempi & 0x100) eflags |= C_FLAG;
    }

    // Коррекция старшего ниббла
    if ((eflags & C_FLAG) || (AL > 0x9F)) {

        AL += 0x60;
        eflags |= C_FLAG;
    }

    set_szp(AL, 0x100);
    put_reg8(al, AL);
}

// Десятичная коррекция после вычитания
void machine::das() {

    byte AL = regs[eax];
    word tempi;

    // Коррекция младшего ниббла
    if ((eflags & A_FLAG) || ((AL & 0x0F)>9)) {

        tempi = ((word)AL) - 6;
        AL -= 6;
        eflags |= A_FLAG;
        if (tempi & 0x100) eflags |= C_FLAG;
    }

    // Коррекция старшего ниббла
    if ((eflags & C_FLAG) || (AL > 0x9F)) {

        AL -= 0x60;
        eflags |= C_FLAG;
    }

    set_szp(AL, 0x100);
    put_reg8(al, AL);
}

// ASCII-коррекция после сложения
void machine::aaa() {

    byte AL = regs[eax];
    byte AH = regs[eax] >> 8;

    if ((eflags & A_FLAG) || ((AL & 0xF) > 9))
    {
        AL += 6;
        AH++;
        eflags |= (A_FLAG|C_FLAG);
    }
    else
       eflags &= ~(A_FLAG|C_FLAG);

    word temp = (AL&15) + ((word)AH << 8);
    regs[eax] = (regs[eax] & 0xFFFF0000) | temp;
}

// ASCII-коррекция после вычитания
void machine::aas() {

    byte AL = regs[eax];
    byte AH = regs[eax] >> 8;

    if ((eflags & A_FLAG) || ((AL & 0xF) > 9))
    {
        AL-=6;
        AH--;
        eflags |= (A_FLAG|C_FLAG);
    }
    else
       eflags &= ~(A_FLAG|C_FLAG);

    word temp = (AL&15) + ((word)AH<<8);
    regs[eax] = (regs[eax] & 0xFFFF0000) | temp;
}

// Коррекция после умножения
void machine::aam() {

    byte tb = fetch_byte();
    put_reg8(ah, get_reg8(al) / tb);
    put_reg8(al, get_reg8(al) % tb);
    set_szp(regs[eax] & 0xFFFF, 0x10000);
}

// Коррекция после деления
void machine::aad() {

    byte tb   = fetch_byte();    
    word temp = (get_reg8(ah)*tb + get_reg8(al)) & 0x00FF;
    regs[eax] = (regs[eax] & 0xFFFF0000) | temp;
    set_szp(regs[eax] & 0xFFFF, 0x10000);
}

// Групповые операции
dword machine::group_alu(int mode, dword a, dword b, int size) {
    
    switch (mode & 7) {

        case 0: return do_add(a, b, size);
        case 1: return do_or (a, b, size);
        case 2: return do_adc(a, b, size);
        case 3: return do_sbb(a, b, size);
        case 4: return do_and(a, b, size);
        case 5:
        case 7: return do_sub(a, b, size);
        case 6: return do_xor(a, b, size);
    }
    
    return 0;
}

// Сдвиговые операции
// * mode = 0..7
// * bit  = 0/1 (8 или 16/32)
// * temp = значение
// * n    = кол-во сдвигов
dword machine::groupshift(byte mode, byte bit, dword temp, byte n) {

    byte  tmpc = 0;
    dword temp2;
    dword sign_bit = bit ? (opsize ? 0x80000000 : 0x8000) : 0x80;
    dword prev_bit = sign_bit >> 1;
    qword carry    = sign_bit << 1;

    if (n == 0) {
        return temp;
    }

    switch (mode)
    {
        // ROL
        case 0: {

            eflags &= ~(C_FLAG | O_FLAG);
            while (n > 0) {

                tmpc = !!(temp & sign_bit);
                temp =   (temp << 1) | tmpc;
                n--;
            }

            if (tmpc) eflags |= C_FLAG;
            if (!!(eflags & C_FLAG) != !!(temp & sign_bit)) eflags |= O_FLAG;
            break;
        }

        // ROR
        case 1: {

            eflags &= ~(C_FLAG | O_FLAG);
            while (n > 0) {

                tmpc = temp & 1;
                temp >>= 1;
                if (tmpc) temp |= sign_bit;
                n--;
            }

            if (tmpc) eflags |= C_FLAG;
            if ((temp ^ (temp >> 1)) & prev_bit) eflags |= O_FLAG;
            break;
        }

        // RCL
        case 2: {

            eflags &= ~(O_FLAG);
            while (n > 0) {

                tmpc = eflags & C_FLAG;
                if (temp & sign_bit) eflags |= C_FLAG; else eflags &= ~C_FLAG;
                temp = (temp << 1) | tmpc;
                n--;
            }

            // Установить флаги после обновления
            if (!!(eflags & C_FLAG) != !!(temp & sign_bit)) eflags |= O_FLAG;
            break;
        }

        // RCR
        case 3: {

            eflags &= ~(O_FLAG);
            while (n > 0) {

                tmpc  = eflags & C_FLAG;
                temp2 = temp & 1;
                temp >>= 1;
                if (temp2) eflags |= C_FLAG; else eflags &= ~C_FLAG;
                if (tmpc) temp |= sign_bit;
                n--;
            }

            if ((temp ^ (temp >> 1)) & prev_bit) eflags |= O_FLAG;
            break;
        }

        // SHL
        case 4:
        case 6: {

            eflags &= ~(C_FLAG);
            if (n > (bit ? (opsize ? 32 : 16) : 8)) {
                temp = 0;
            } else {
                if ((temp << (n - 1)) & sign_bit) eflags |= C_FLAG;
                temp <<= n;
            }

            set_szp(temp, carry);
            eflags |= A_FLAG;
            break;
        }

        // SHR
        case 5: {

            eflags &= ~(C_FLAG);
            if (n > (bit ? 16 : 8)) {
                temp = 0;
            } else {
                if ((temp >> (n-1)) & 1) eflags|= C_FLAG;
                temp >>= n;
            }

            set_szp(temp, carry);
            eflags |= A_FLAG;
            break;
        }

        // SAR
        case 7: {

            eflags &= ~(C_FLAG);
            if ((temp >> (n-1)) & 1) eflags |= C_FLAG;

            while (n > 0) {

                temp >>= 1;
                if (temp & prev_bit) temp |= sign_bit;
                n--;
            }

            set_szp(temp, carry);
            eflags |= A_FLAG;
            break;
        }
    }

    return temp;
}

// Получение знакового числа из беззнакового
qword_s machine::get_signed_qword(dword a, int size) {
    
    if (size)
         return opsize ? (dword_s)a : (word_s)a;
    else return (signed char)a;
}

// Умножение двух чисел
qword machine::imul16(dword a, dword b) {
    
    qword m     = opsize ? 0xFFFFFFFF : 0xFFFF;
    qword_s sa  = get_signed_qword(a, 1);
    qword_s sb  = get_signed_qword(b, 1);
    qword_s r   = (qword_s)(a * b);   

    if ((qword) r & ~m)
         eflags |=  (C_FLAG | O_FLAG);
    else eflags &= ~(C_FLAG | O_FLAG);

    return r & m;
}