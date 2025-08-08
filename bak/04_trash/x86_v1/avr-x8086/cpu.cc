/**
 * Это эмулятор 16-битного x86 с некоторыми дополнительными инструкциями
 */

#include "cpu.h"
#include "cpuexec.cc"

CPU::CPU() {
    
    byte d, c = 0;
    
    loadcs(0xf000);
    loadds(0x0000);
    loades(0x0000);
    loadss(0x0000);

    ip = 0xffff;    
    flags = 0x0000;
    
    do
    {
        d = (c>>4) ^ c;
        d = (d>>2) ^ d;
        d = (d>>1) ^ d;

        znptable8[c] = (d&1) ? 0 : P_FLAG;
        if (c == 0) znptable8[c] |= Z_FLAG;
        if (c&0x80) znptable8[c] |= N_FLAG;

        c++;
    }
    while (c != 0);
}

// ДОСТУП К ПАМЯТИ
// =============================================================================

// Чтение байта из физической или линейной памяти
byte CPU::read(dword seg, word offset) {    
    return machine_read(seg + offset);
}

// Запись байта в память
void CPU::write(dword seg, word offset, byte data) {
    machine_write(seg + offset, data);
}

// Чтение слова
word CPU::read_word(dword seg, word offset) {   
    return read(seg, offset) + read(seg, offset + 1)*256;
}

// Запись слова в память
void CPU::write_word(dword seg, word offset, word data) {
    
    write(seg, offset,   data);
    write(seg, offset+1, data>>8);    
}

// =============================================================================

// Прочитать следующий байт
byte CPU::fetch_byte() {   
    return read(seg_cs, ip++);
}

// Прочитать WORD | DWORD, зависит от opsize
word CPU::fetch_word() {
    
    byte a = fetch_byte();
    byte b = fetch_byte();
    return a | (b<<8);
}

// Базовые флаги N,Z,P после 8-битных инструкции
void CPU::setznp8(byte val) {

    flags &= ~0xC4;
    flags |= znptable8[val];
}

// Базовые флаги N,Z,P после 16-битных инструкции
void CPU::setznp16(word val) {

    flags &= ~0xC4;

    if (val & 0x8000) flags |= N_FLAG;
    if (val == 0)     flags |= Z_FLAG;
    flags |= (znptable8[val&0xff] & P_FLAG);
}

// Флаги после сложения 8 бит
byte CPU::setadd8(byte a, byte b) {

    word c = (word)a + (word)b;

    flags &= ~0x8D5;
    flags |= znptable8[c & 0xFF];

    if (c & 0x100) flags |= C_FLAG;
    if (!((a^b)&0x80)&&((a^c)&0x80)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)      flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
byte CPU::setadd8nc(byte a, byte b) {

    word c = (word)a + (word)b;

    flags &= ~0x8D4;
    flags |= znptable8[c&0xFF];

    if (!((a^b)&0x80)&&((a^c)&0x80)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)      flags |= A_FLAG;

    return c;
}

// Флаги после сложения 8 бит
byte CPU::setadc8(byte a, byte b, byte tempc) {

    word c = (word)a + (word)b + tempc;

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c & 0x100) flags |= C_FLAG;
    if (!((a^b)&0x80)&&((a^c)&0x80))  flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)       flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
word CPU::setadd16(word a, word b) {

    dword c = (dword)a + (dword)b;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c & 0x10000) flags |= C_FLAG;
    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит без CF
word CPU::setadd16nc(word a, word b) {

    dword c = (dword)a + (dword)b;

    flags &= ~0x8D4;
    setznp16(c & 0xffff);

    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
word CPU::setadc16(word a, word b, byte tempc) {

    dword c = (dword)a + (dword)b + tempc;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c & 0x10000) flags |= C_FLAG;
    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит
byte CPU::setsub8(byte a, byte b) {

    word c = (word)a - (word)b;

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c&0x100) flags|=C_FLAG;
    if ((a^b)&(a^c)&0x80)       flags|=V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags|=A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит без CF
byte CPU::setsub8nc(byte a, byte b) {

    word c=(word)a - (word)b;

    flags &= ~0x8D4;
    flags |= znptable8[c&0xFF];

    if ((a^b)&(a^c)&0x80)       flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит
byte CPU::setsbc8(byte a, byte b, byte tempc) {

    word c = (word)a - (((word)b) + tempc);

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c&0x100)                flags |= C_FLAG;
    if ((a^b)&(a^c)&0x80)       flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 16 бит
word CPU::setsub16(word a, word b) {

    dword c = (dword)a - (dword)b;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c&0x10000) flags |= C_FLAG;
    if ((a^b)&(a^c)&0x8000)     flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 16 бит без CF
word CPU::setsub16nc(word a, word b) {

    dword c = (dword)a - (dword)b;

    flags &= ~0x8D4;
    setznp16(c & 0xffff);
    flags &= ~0x4;
    flags |= (znptable8[c&0xFF]&4);

    if ((a^b)&(a^c)&0x8000)     flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 16 бит 
word CPU::setsbc16(word a, word b, byte tempc) {

    dword c = (dword)a - (((dword)b) + tempc);

    flags &= ~0x8D5;
    setznp16(c & 0xffff);
    flags &= ~0x4;
    flags |= (znptable8[c&0xFF]&4);

    if (c&0x10000)              flags |= C_FLAG;
    if ((a^b)&(a^c)&0x8000)     flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после операции OR 8 бит
byte CPU::setor8(byte a, byte b) {

    byte c = a | b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции OR 16 бит
word CPU::setor16(word a, word b) {

    word c = a | b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции AND 8 бит
byte CPU::setand8(byte a, byte b) {

    byte c = a & b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции AND 16 бит
word CPU::setand16(word a, word b) {

    word c = a & b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции XOR 8 бит
byte CPU::setxor8(byte a, byte b) {

    byte c = a ^ b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции XOR 16 бит
word CPU::setxor16(word a, word b) {

    word c = a ^ b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Десятичная коррекция после сложения
void CPU::daa() {

    byte  AL = AL_;
    word tempi;

    if ((flags & A_FLAG) || ((AL & 0xF) > 9))
    {
        tempi = ((word) AL) + 6;
        AL += 6;
        flags |= A_FLAG;
        if (tempi & 0x100) flags |= C_FLAG;
    }

    if ((flags & C_FLAG) || (AL > 0x9F))
    {
        AL += 0x60;
        flags |= C_FLAG;
    }

    setznp8(AL);
    setr8(REG_AL, AL);
}

// Десятичная коррекция после вычитания
void CPU::das() {

    byte  AL = regs[REG_AL];
    word tempi;

    if ((flags & A_FLAG) || ((AL & 0xF)>9))
    {
        tempi = ((word)AL) - 6;
        AL -= 6;
        flags |= A_FLAG;
        if (tempi & 0x100) flags |= C_FLAG;
    }

    if ((flags & C_FLAG) || (AL>0x9F))
    {
        AL -= 0x60;
        flags |= C_FLAG;
    }

    setznp8(AL);
    setr8(REG_AL, AL);
}

// ASCII-коррекция после сложения
void CPU::aaa() {

    byte  AL = regs[REG_AL];
    byte  AH = regs[REG_AX] >> 8;

    if ((flags & A_FLAG) || ((AL & 0xF) > 9))
    {
        AL+=6;
        AH++;
        flags |= (A_FLAG|C_FLAG);
    }
    else
       flags &= ~(A_FLAG|C_FLAG);

    setr16(REG_AX, (AL&15) + ((word)AH << 8));
}

// ASCII-коррекция после вычитания
void CPU::aas() {

    byte  AL = regs[REG_AL];
    byte  AH = regs[REG_AX] >> 8;

    if ((flags & A_FLAG) || ((AL & 0xF) > 9))
    {
        AL-=6;
        AH--;
        flags |= (A_FLAG|C_FLAG);
    }
    else
       flags &= ~(A_FLAG|C_FLAG);

    setr16(REG_AX, (AL&15) + ((word)AH<<8));
}

// Коррекция после умножения
void CPU::aam() {

    byte tb = fetch_byte();
    setr8(REG_AH, AL_ / tb);
    setr8(REG_AL, AL_ % tb);
    setznp16(AX_);
}

// Коррекция после деления
void CPU::aad() {

    byte tb = fetch_byte();
    AX_ = (AH_*tb + AL_) & 0x00FF;
    setznp16(AX_);
}

// УПРАВЛЕНИЕ ПРОЦЕССОРОМ
// =============================================================================

// Чтение из 8-битного регистра
byte CPU::getr8(byte id) { 
    return id & 4 ? regs[id&3] >> 8 : regs[id&3]; 
}

// Запись в 8-битный регистр
void CPU::setr8(byte id, byte v) {

    if (id & 4) {
        regs[id&3] = (regs[id&3] & 0x00ff) | ((word)v << 8);
    } else {
        regs[id&3] = (regs[id&3] & 0xff00) | v;
    }
}

// Чтение и запись в 16-битные регистры
word CPU::getr16(byte id) { 
    return regs[id]; 
}

void CPU::setr16(byte id, word v) { 
    regs[id] = v; 
}

// Прочитать эффективный адрес
void CPU::fetchea() {

    rmdat   = fetch_byte();
    cpu_mod = (rmdat >> 6) & 3;
    cpu_reg = (rmdat >> 3) & 7;
    cpu_rm  = rmdat & 7;
    eaaddr  = 0;

    // Расчет эффективного адреса
    switch (cpu_rm) {

        case 0: eaaddr = (BX_ + SI_); break;
        case 1: eaaddr = (BX_ + DI_); break;
        case 2: eaaddr = (BP_ + SI_); break;
        case 3: eaaddr = (BP_ + DI_); break;
        case 4: eaaddr =  SI_; break;
        case 5: eaaddr =  DI_; break;
        case 6: eaaddr =  BP_; break;
        case 7: eaaddr =  BX_; break;
    }

    // Выбор сегмента
    if (sel_seg == 0 && ((cpu_rm == 6 && cpu_mod) || (cpu_rm == 2) || (cpu_rm == 3)))
        segment = seg_ss;

    // Модифицирующие биты modrm
    switch (cpu_mod) {

        case 0: if (cpu_rm == 6) eaaddr = fetch_word(); break;
        case 1: eaaddr += (signed char) fetch_byte(); break;
        case 2: eaaddr += fetch_word(); break;
        case 3: eaaddr = 0; break;
    }
}

// Прочитать byte из r/m
byte CPU::geteab() {

    if (cpu_mod == 3)
        return getr8(cpu_rm);
    else
        return read(segment, eaaddr);
}

// Прочитать word из r/m
word CPU::geteaw() {

    if (cpu_mod == 3) return getr16(cpu_rm);
    return read_word(segment, eaaddr);
}

// Записать byte в r/m
void CPU::seteab(byte v) {

    if (cpu_mod == 3) {
        setr8(cpu_rm, v);
    } else {
        write(segment, eaaddr, v);
    }
}

// Записать word в r/m
void CPU::seteaw(word v) {

    if (cpu_mod == 3) {
        regs[cpu_rm] = v;
    } else {
        write_word(segment, eaaddr, v);
    }
}

// Запись в стек
void CPU::push(word v) {

    write_word(seg_ss, ((SP_ - 2) & 0xffff), v);
    SP_ -= 2;
}

// Извлечение из стека
word CPU::pop() {

    word r = read_word(seg_ss, SP_);
    SP_ += 2;
    return r;
}

// Вызов прерывания
void CPU::interrupt(byte int_id) {

    word a = (int_id<<2);
    word l = read_word(0, a);
    word h = read_word(0, a+2);

    push(flags | 0xF000);
    push(segs[SEG_CS]);
    push(ip);

    flags &= ~(I_FLAG | T_FLAG);
    loadcs(h); ip = l;
}

// Дальний вызов
void CPU::callfar(word _cs, word _ip) {

    word cs_ = segs[SEG_CS], ip_ = ip;
    ip = _ip;
    loadcs(_cs);
    push(cs_);
    push(ip_);
}

// Групповые операции АЛУ 8 бит
byte CPU::groupalu8(byte mode, byte a, byte b) {

    switch (mode) {

        case 0: return setadd8(a, b);
        case 1: return setor8 (a, b);
        case 2: return setadc8(a, b, flags & C_FLAG);
        case 3: return setsbc8(a, b, flags & C_FLAG);
        case 4: return setand8(a, b);
        case 5:
        case 7: return setsub8(a, b);
        case 6: return setxor8(a, b);
    }

    return 0;
}

// Групповые операции АЛУ 16 бит
word CPU::groupalu16(byte mode, word a, word b) {

    switch (mode) {

        case 0: return setadd16(a, b);
        case 1: return setor16 (a, b);
        case 2: return setadc16(a, b, flags & C_FLAG);
        case 3: return setsbc16(a, b, flags & C_FLAG);
        case 4: return setand16(a, b);
        case 5:
        case 7: return setsub16(a, b);
        case 6: return setxor16(a, b);
    }

    return 0;
}

// Сдвиговые операции
// * mode = 0..7
// * bit  = 0/1 (8/16)
// * temp = значение
// * n    = кол-во сдвигов
word CPU::groupshift(byte mode, byte bit, word temp, byte n) {

    byte tmpc = 0;
    word temp2;
    word sign_bit = bit ? 0x8000 : 0x80;
    word prev_bit = sign_bit >> 1;

    if (n == 0) return temp;

    switch (mode)
    {
        // ROL
        case 0: {

            flags &= ~(C_FLAG | V_FLAG);
            while (n > 0) {

                tmpc = !!(temp & sign_bit);
                temp = (temp << 1) | tmpc;
                n--;
            }

            if (tmpc) flags |= C_FLAG;
            if (!!(flags & C_FLAG) != !!(temp & sign_bit)) flags |= V_FLAG;
            break;
        }

        // ROR
        case 1: {

            flags &= ~(C_FLAG | V_FLAG);
            while (n > 0) {

                tmpc = temp & 1;
                temp >>= 1;
                if (tmpc) temp |= sign_bit;
                n--;
            }

            if (tmpc) flags |= C_FLAG;
            if ((temp ^ (temp >> 1)) & prev_bit) flags |= V_FLAG;
            break;
        }

        // RCL
        case 2: {

            flags &= ~(V_FLAG);
            while (n > 0) {

                tmpc  = flags & C_FLAG;
                if (temp & sign_bit) flags |= C_FLAG; else flags &= ~C_FLAG;
                temp  = (temp << 1) | tmpc;
                n--;
            }

            // Установить флаги после обновления
            if (!!(flags & C_FLAG) != !!(temp & sign_bit)) flags |= V_FLAG;
            break;
        }

        // RCR
        case 3: {

            flags &= ~(V_FLAG);
            while (n > 0) {

                tmpc  = flags&C_FLAG;
                temp2 = temp&1;
                temp >>= 1;
                if (temp2) flags |= C_FLAG; else flags &= ~C_FLAG;
                if (tmpc) temp |= sign_bit;
                n--;
            }

            if ((temp ^ (temp >> 1)) & prev_bit) flags |= V_FLAG;
            break;
        }

        // SHL
        case 4:
        case 6: {

            flags &= ~(C_FLAG);
            if (n > (bit ? 16 : 8)) {
                temp = 0;
            } else {
                if ((temp << (n-1)) & sign_bit) flags |= C_FLAG;
                temp <<= n;
            }

            if (bit) setznp16(temp); else setznp8(temp);
            flags |= A_FLAG;
            break;
        }

        // SHR
        case 5: {

            flags &= ~(C_FLAG);
            if (n > (bit ? 16 : 8)) {
                temp = 0;
            } else {
                if ((temp >> (n-1)) & 1) flags |= C_FLAG;
                temp >>= n;
            }

            if (bit) setznp16(temp); else setznp8(temp);
            flags |= A_FLAG;
            break;
        }

        // SAR
        case 7: {

            flags &= ~(C_FLAG);
            if ((temp >> (n-1)) & 1) flags |= C_FLAG;

            while (n > 0) {

                temp >>= 1;
                if (temp & prev_bit) temp |= sign_bit;
                n--;
            }

            if (bit) setznp16(temp); else setznp8(temp);
            flags |= A_FLAG;
            break;
        }
    }

    return temp;
}

// Автоинкремент для строковых инструкций
void CPU::autorep(byte flag_test) {

    // Есть префикс <REP | REPNZ | REPZ>
    if (rep) {

        CX_--;

        // Проверка на REPNZ, REPZ
        if (flag_test) {

            // Если REPZ, но не ZERO, переход к следующей инструкции
            if ((rep == REPZ)  && !(flags & Z_FLAG))
                return;

            // Если REPNZ, но ZERO, переход к следующей инструкции
            if ((rep == REPNZ) &&  (flags & Z_FLAG))
                return;
        }

        // Повтор инструкции
        if (CX_) ip = ip_start;
    }
}

// Undefined Instruction
void CPU::ud(byte code) {
    
    
}