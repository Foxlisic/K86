#include "machine.h"

// -----------------------------------------------------------------
// Процессорный модуль
// -----------------------------------------------------------------

// Сброс процессора
void machine::reset() {

    int i;

    for (i = 0; i < 8; i++) regs[i] = 0;
    for (i = 0; i < 4; i++) load_seg(i, 0);

    eflags  = 0;
    halt    = 0;
    gdt_offset = 0;

    eip     = 0xfff0;
    load_seg(cs, 0xf000);

    stack_size      = 0;
    default_size    = 0;
    first_regdump   = 1;

    // Генерация флага четности
    for (i = 0; i < 256; i++) {

        byte x = i ^ (i >> 4);
             x = x ^ (x >> 2);
             x = x ^ (x >> 1);

        if (x & 1 == 0) parity[i] = P_FLAG;
    }
}

int machine::halted() { return halt; }

// Установка флагов
void machine::set_of(dword x) { if ( x) eflags |= O_FLAG; else eflags &= ~O_FLAG; }
void machine::set_sf(dword x) { if ( x) eflags |= S_FLAG; else eflags &= ~S_FLAG; }
void machine::set_zf(dword x) { if (!x) eflags |= Z_FLAG; else eflags &= ~Z_FLAG; }
void machine::set_af(dword x) { if ( x) eflags |= A_FLAG; else eflags &= ~A_FLAG; }
void machine::set_pf(dword x) { eflags &= ~P_FLAG; eflags |= parity[x & 0xff]; }
void machine::set_cf(dword x) { if ( x) eflags |= C_FLAG; else eflags &= ~C_FLAG; }
int  machine::get_cf() { return eflags & C_FLAG; }

// Установка флагов SZP, r-результат, c-бит переноса
void machine::set_szp(qword r, qword c) {

    qword s = c >> 1;
    qword m = c - 1;

    set_pf(r);
    set_zf(r & m);
    set_sf(r & s);
}

// REAL-MODE 16 BIT
dword machine::phys_addr(word selector, dword address) {
    return segs[selector]*16 + address;
}

// Данные из памяти 64 mb
byte  machine::read_byte(dword address) { return memory[ address & (MAX_MEMORY-1) ]; }
word  machine::read_word(dword address) { return read_byte(address) + 256*read_byte(address+1); }
dword machine::read_dword(dword address) { return read_word(address) + 65536*read_word(address+2); }

// Обновить память
void machine::write_byte(dword address, byte data) {

    // Если запись идет в CGA/Text, это можно проверить
    memory[ address & (MAX_MEMORY-1) ] = data;
}

// 16-бит
void machine::write_word(dword address, word data) {

    write_byte(address,   data);
    write_byte(address+1, data>>8);
}

// 32-бит
void machine::write_dword(dword address, dword data) {

    write_byte(address,   data);
    write_byte(address+1, data>>8);
    write_byte(address+2, data>>16);
    write_byte(address+3, data>>24);
}

// Получение адреса для MOV [offset16/32]
dword machine::get_offset() {

    dword t32 = adsize ? fetch_dword() : fetch_word();
    return phys_addr(segment, t32);
}

// Читать следующий байт из CS:EIP
byte machine::fetch_byte() {

    byte x = read_byte(phys_addr(cs, eip));
    eip = (eip + 1);
    return x;
}

// Прочитать слово (2 байта)
word machine::fetch_word() {

    byte x = fetch_byte();
    byte y = fetch_byte();
    return ((word)y<<8) | x;
}

// Прочитать двойное слово (4 байта)
dword machine::fetch_dword() {

    word x = fetch_word();
    word y = fetch_word();
    return (y*65536) + x;
}

// Считывает либо 16, либо 32 битное слово
dword machine::fetch_gv() {
    return opsize ? fetch_dword() : fetch_word();
}

// Чтение регистра 8-bit из регистрой части
byte machine::get_rb() {
    return get_reg8(modrm_reg);
}

// Чтение регистра 16/32-bit из регистрой части
dword machine::get_rv() {
    return get_regv(modrm_reg);
}

// Прочитать операнд из памяти или регистра
byte machine::get_eb() {

    if (modrm_mod == 3) {
        return get_reg8(modrm_rm);
    } else {
        return read_byte(phys_addr(segment, ea));
    }
}

// Прочитать операнд из памяти или регистра 16/32 bit
dword machine::get_ev() {

    if (modrm_mod == 3) {
        return get_regv(modrm_rm);
    } else {
        if (opsize) {
            return read_dword(phys_addr(segment, ea));
        } else {
            return read_word(phys_addr(segment, ea));
        }
    }
}

// 8-бит rm-часть
void machine::put_eb(byte data) {

    if (modrm_mod == 3) {
        put_reg8(modrm_rm, data);
    } else {
        write_byte(phys_addr(segment, ea), data);
    }
}

// 16/32 rm-часть
void machine::put_ev(dword data) {

    if (modrm_mod == 3) {
        put_regv(modrm_rm, data);
    } else {
        if (opsize) {
            write_dword(phys_addr(segment, ea), data);
        } else {
            write_word(phys_addr(segment, ea), data);
        }
    }
}

// Сохранить в modrm reg-часть [8 bit]
void machine::put_rb(byte data) {
    put_reg8(modrm_reg, data);
}

// Сохранить в modrm reg-часть [16/32 bit]
void machine::put_rv(dword data) {
    put_regv(modrm_reg, data);
}

// Прочесть регистр 8 бит
byte machine::get_reg8(int reg_id) {

    if (reg_id & 4) {
        return (regs[reg_id & 3] >> 8) & 0xff;
    } else {
        return (regs[reg_id & 3]) & 0xff;
    }
}

// Чтение 16 или 32 бита
dword machine::get_regv(int reg_id) {

    if (opsize) {
        return regs[reg_id & 7];
    } else {
        return regs[reg_id & 7] & 0xffff;
    }
}

// Сохранить в 8-битный регистр
void machine::put_reg8(int reg_id, byte data) {

    if (reg_id & 4) {
        regs[reg_id & 3] = (regs[reg_id & 3] & (~0xFF00)) | (data << 8);
    } else {
        regs[reg_id & 3] = (regs[reg_id & 3] & (~0x00FF)) | (data);
    }
}

// Сохранить 16|32 бита
void machine::put_reg16(int reg_id, dword data, int size) {

    if (size) {
        regs[reg_id & 7] = data;
    } else {
        regs[reg_id & 7] = (regs[reg_id & 7] & 0xFFFF0000) | (data & 0xFFFF);
    }
}

// Сохранить в 16/32 битный регистр
void machine::put_regv(int reg_id, dword data) {

    reg_id &= 7;

    if (opsize) {
        regs[reg_id] = data;
    } else {
        regs[reg_id] = (regs[reg_id] & (~0xFFFF)) | (data & 0xFFFF);
    }
}

// Загрузка сегментов
void machine::load_seg(byte segment_id, word data) {

    segs[segment_id & 7] = data;
}

// Это на случай Protected Mode 32 bit
void machine::load_eip(dword new_eip) {

    if (default_size)
         eip = new_eip;
    else eip = (eip & 0xFFFF0000) | (new_eip & 0xFFFF);
}

// Undefined Instuction!
void machine::ud() {

    // пока ничего не делать, выйти
    exit(1);
}

// Запись в стек Word | DWord
void machine::push(dword v, byte size) {

    dword espv = regs[esp] - (size ? 4 : 2);
    put_reg16(esp, espv, stack_size);
    dword address = phys_addr(ss, stack_size ? espv : (espv & 0xFFFF));

    if (size) {
        write_dword(address, v);
    } else {
        write_word(address, v);
    }
}

// Извлечь из стека
dword machine::pop(byte size) {

    dword espv    = regs[esp];
    dword address = phys_addr(ss, stack_size ? espv : (espv & 0xFFFF));
    dword temp;

    if (size) {
        temp = read_dword(address);
    } else {
        temp = read_word(address);
    }

    put_reg16(esp, espv + (size ? 4 : 2), stack_size);

    return temp;
}

// Прочитаь опкод вместе с префиксами
word machine::get_opcode() {

    overseg     = 0;
    rep         = 0;
    opsize      = default_size;
    adsize      = default_size;
    segment     = ds;
    eipstart    = eip;

    for (int i = 0; i < 16; i++) {

        opcode = fetch_byte();

        switch (opcode) {

            case 0x0F: return fetch_byte() + 0x100;
            case 0x26: overseg = 1; segment = es; break;
            case 0x2E: overseg = 1; segment = cs; break;
            case 0x36: overseg = 1; segment = ss; break;
            case 0x3E: overseg = 1; segment = ds; break;
            case 0x64: overseg = 1; segment = fs; break;
            case 0x65: overseg = 1; segment = gs; break;
            case 0x66: opsize  = !opsize; break;
            case 0x67: adsize  = !adsize; break;
            case 0xF0: break;
            case 0xF2: rep = 1; break;
            case 0xF3: rep = 2; break;
            default: return opcode;
        }
    }

    ud();
    return -1;
}

// Считывание 16 или 32 битного ModRM
dword machine::fetch_modrm() {

    modrm     = fetch_byte();
    modrm_rm  = (modrm & 0x07);
    modrm_reg = (modrm & 0x38) >> 3;
    modrm_mod = (modrm & 0xc0) >> 6;

    // 32-битный
    if (adsize) {

        exit(2); // !TODOING!

    }
    // 16-битный
    else {

        switch (modrm_rm) {

            case 0: ea = regs[ebx] + regs[esi]; break;
            case 1: ea = regs[ebx] + regs[edi]; break;
            case 2: ea = regs[ebp] + regs[esi]; break;
            case 3: ea = regs[ebp] + regs[edi]; break;
            case 4: ea = regs[esi]; break;
            case 5: ea = regs[edi]; break;
            case 6: ea = regs[ebp]; break;
            case 7: ea = regs[ebx]; break;
        }

        // Выбор по умолчанию SS:
        if (overseg == 0) {

            if ((modrm_rm == 6 && modrm_mod) || (modrm_rm == 2) || (modrm_rm == 3)) {
                segment = ss;
            }
        }

        // Модифицирующие биты modrm
        switch (modrm_mod) {

            case 0: if (modrm_rm == 6) ea = fetch_word(); break;
            case 1: ea += (signed char) fetch_byte(); break;
            case 2: ea += fetch_word(); break;
            case 3: ea = 0; break;
        }

        ea &= 0xffff;
    }

    return ea;
}

// Вычисление условия перехода
byte machine::condition(int num) {

    switch (num & 15) {

        case 0: return   eflags & O_FLAG;           // JO
        case 1: return !(eflags & O_FLAG);          // JNO
        case 2: return   eflags & C_FLAG;           // JC
        case 3: return !(eflags & C_FLAG);          // JNC
        case 4: return   eflags & Z_FLAG;           // JZ
        case 5: return !(eflags & Z_FLAG);          // JNZ
        case 6: return  (eflags & (C_FLAG|Z_FLAG)); // JBE
        case 7: return !(eflags & (C_FLAG|Z_FLAG)); // JNBE
        case 8:  return   eflags & S_FLAG;          // JS
        case 9:  return !(eflags & S_FLAG);         // JNS
        case 10: return  (eflags & P_FLAG);         // JP
        case 11: return !(eflags & P_FLAG);         // JNP
        case 12: return (!!(eflags & S_FLAG) != !!(eflags & O_FLAG)); // JL
        case 13: return (!!(eflags & S_FLAG) == !!(eflags & O_FLAG)); // JNL
        case 14: return  (eflags & Z_FLAG) || (!!(eflags & S_FLAG) != !!(eflags & O_FLAG)); // JLE:  ZF=1 OR  (SF!=OF);
        case 15: return !(eflags & Z_FLAG) && (!!(eflags & S_FLAG) == !!(eflags & O_FLAG)); // JNLE: ZF=0 AND (SF==OF)
    }

    return 0;
}

// Процедура RET. Она может быть очень сложной
void machine::do_ret(dword imm) {

    load_eip(pop(opsize));
    put_regv(esp, get_regv(esp) + imm);
}

// Процедура дальнего возврата
void machine::do_retf(dword imm) {

    load_eip(pop(opsize));
    load_seg(cs, pop(0));
    put_regv(esp, get_regv(esp) + imm);
}

// Перейти к дальней метке
void machine::do_jmp_far(word new_cs, dword new_eip) {

    load_eip(new_eip);
    load_seg(cs, new_cs);
}

// Вызов дальней процедуры
void machine::do_call_far(word new_cs, dword new_eip) {

    push(segs[cs], 0);
    push(eip, opsize);

    load_eip(new_eip);
    load_seg(cs, new_cs);
}

// Операция ENTER
void machine::do_enter() {

    dword size   = fetch_gv();
    word  nested = fetch_byte() & 31;

    // Сохранить старый eBP
    push(regs[ebp], opsize);

    // Определить новое положение eSP
    dword frame_temp = regs[esp];

    // Вложенные уровни
    if (nested) {

        dword _ebp = regs[ebp];

        // Создать вложенные уровни
        for (int i = 1; i < nested; ++i) {

            _ebp -= (opsize ? 4 : 2);
            push(stack_size ? _ebp : (word) _ebp, opsize);
        }

        // Обновить [E]BP
        put_reg16(ebp, _ebp, stack_size);

        // Сохранить frame_temp
        push(frame_temp, opsize);
    }

    // Сохранение в eBP указателя на фрейм
    put_reg16(ebp, frame_temp, stack_size);

    // Выделить место на стеке
    put_reg16(esp, frame_temp - size, stack_size);
}

// Вызов прерывания [16 bit]
void machine::interrupt(int id) {

    // Real Mode
    dword a32 = (id << 4) + gdt_offset;

    // Зависит от текущего режима работы прерываний, пока что 16 битный
    word  l16 = read_word(a32);
    word  h16 = read_word(a32 + 2);

    push(eflags & 0x0FFF, default_size);
    push(segs[cs], 0);
    push(eip, default_size);

    eflags &= ~(I_FLAG | T_FLAG);

    load_seg(cs, h16);
    load_eip(l16);
}

// IRET
void machine::do_iret() {

    dword a32 = pop(default_size); 
    word  t16 = pop(0); 
    eflags = pop(default_size) & 0xfff; 
    load_seg(cs, t16); 
    load_eip(a32);
}