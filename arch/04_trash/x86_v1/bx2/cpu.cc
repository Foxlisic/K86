#include "step.cc"
#include "cpu.arith.cc"

// Сброс CPU
void cpu_reset() {

    // Переход к реальному режиму работы
    pmode           = 0;
    eip             = 0;
    eflags          = 0;
    segment         = &segs[REG_DS];

    // Перезагрузка сегментов
    load_segment(REG_CS, 0xFFFF);
    load_segment(REG_DS, 0);
    load_segment(REG_ES, 0);
    load_segment(REG_SS, 0);

    // Создает parity-таблицу
    for (int i = 0; i < 256; i++) {

        byte d;
        d = (i>>4) ^ i;
        d = (d>>2) ^ d;
        d = (d>>1) ^ d;
        znptable8[i] = (d&1) ? 0 : P_FLAG;
        if (i == 0) znptable8[i] |= Z_FLAG;
        if (i&0x80) znptable8[i] |= N_FLAG;
    }
}

// Загрузка нового сегментного регистра по селектору
void load_segment(byte segment_id, word selector) {

    // Получение ссылки на структуру сегмента
    Tsegment* seg = & segs[segment_id];

    // @TODO PROTECTED MODE

    // REAL MODE
    seg->selector   = selector;
    seg->base       = selector * 16;
    seg->limit      = 65535;
    seg->cpl        = 3;
    seg->defsize    = 0;
}

// Проверка лимитов и разрешений на память
dword read_address(struct Tsegment* seg, dword offset) {

    // General Protection Error
    if (offset > seg->limit) {

        exception = EXCEPTION_GENERAL;
        return 0;
    }

    return seg->base + offset;
}

// Чтение байта
byte read_byte(Tsegment* seg, dword offset) {
    return phy_read( read_address(seg, offset) );
}

// Чтение слова 16 бит
word read_word(Tsegment* seg, dword offset) {

    byte L = read_byte(seg, offset);
    byte H = read_byte(seg, offset+1);
    return (H<<8) | L;
}

// Чтение слова 32 бит
dword read_dword(Tsegment* seg, dword offset) {

    word L = read_word(seg, offset);
    word H = read_word(seg, offset+2);
    return (H<<16) | L;
}

// Сохранить в память 8 бит
void write_byte(Tsegment* seg, dword offset, byte data) {

    phy_write( read_address(seg, offset), data );
}

// Сохранить в память 16 бит
void write_word(Tsegment* seg, dword offset, word data) {

    write_byte(seg, offset,   data);
    write_byte(seg, offset+1, data >> 8);
}

// Сохранить в память 32 бит
void write_dword(Tsegment* seg, dword offset, dword data) {

    write_word(seg, offset,   data);
    write_word(seg, offset+2, data >> 16);
}

// Прочитывает следующий байт из потока CS:EIP
byte fetch() {

    // Получение адреса CS:EIP в зависимости от 16/32 битности
    byte  defsize = segs[REG_CS].defsize;

    dword a = defsize ? eip : (eip & 0xFFFF);
    byte  b = read_byte(&segs[REG_CS], a);

    // Если 16 бит, то +1 только в младшие 16 бит регистр
    if (defsize) eip++; else eip = ((eip+1)&0xffff) | (eip&0xffff0000);

    return b;
}

// Считывание Word 16 bit
word fetch_word() {

    byte L = fetch();
    byte H = fetch();
    return (H<<8) | L;
}

// Считывание Word 32 bit
dword fetch_dword() {

    word L = fetch_word();
    word H = fetch_word();
    return (H<<16) | L;
}

// Считывание 16/32 бита
dword fetch_iw() {
    return opsize ? fetch_dword() : fetch_word();
}

// Считывание modrm16/32
void fetch_modrm() {
    if (adsize) fetch_modrm32(); else fetch_modrm16();
}

// Раскодировать ModRM 16
void fetch_modrm16() {

    byte t  = fetch();

    mod_mm  = (t & 0xc0) >> 6;
    mod_reg = (t & 0x38) >> 3;
    mod_rm  = (t & 7);

    // Выбор памяти
    switch (mod_rm) {

        case 0: mod_ea = regs[REG_SI] + regs[REG_BX]; break;
        case 1: mod_ea = regs[REG_DI] + regs[REG_BX]; break;
        case 2: mod_ea = regs[REG_SI] + regs[REG_BX]; break;
        case 3: mod_ea = regs[REG_DI] + regs[REG_BX]; break;
        case 4: mod_ea = regs[REG_SI]; break;
        case 5: mod_ea = regs[REG_DI]; break;
        case 6: mod_ea = regs[REG_BP]; break;
        case 7: mod_ea = regs[REG_BX]; break;
    }

    // Получение Displacement
    switch (mod_mm) {

        // mod=0
        case 0:

            if (mod_rm == 6) mod_ea = fetch_word(); break;
            break;

        // mod=1 +sign8
        case 1:

            mod_ea += (signed char)fetch();
            break;

        // mod=2 +disp16
        case 2:

            mod_ea += fetch_word();
            break;
    }

    // При выборе BP, будет автоматически замещен текущий сегмент на SS:
    if (seg_override == 0) {
        if ((mod_mm && mod_rm == 6) || mod_rm == 2 || mod_rm == 3)
            segment = & segs[REG_SS];
    }

    // Вообще-то, за пределы тут может выйти
    mod_ea &= 0xffff;
}

// Раскодировать ModRM 32
void fetch_modrm32() {

    exit(2);
}

// Прочитать регистр 8 бит
byte get_regb(byte reg_id) {
    byte rb = reg_id & 3;
    return reg_id & 4 ? regs[rb] >> 8 : regs[rb];
}

// Регистр 16 или 32
dword get_regw(byte reg_id) {
    return opsize ? regs[reg_id] : (regs[reg_id] & 0xffff);
}

// Записать в регистр
void put_regb(byte reg_id, byte data) {

    byte rb = reg_id & 3;
    if (reg_id & 4)
        regs[rb] = (regs[rb] & 0xffff00ff) | (data << 8);
    else
        regs[rb] = (regs[rb] & 0xffffff00) | data;
}

// Сохранение в регистр 16/32
void put_regw(byte reg_id, dword data) {

    if (opsize) regs[reg_id] = data;
    else        regs[reg_id] = (regs[reg_id] & 0xffff0000) | (data & 0xffff);
}

// Получение rm-части (8 бит)
byte get_eb() {

    if (mod_mm == 3)
        return get_regb(mod_rm);
    else
        return read_byte(segment, mod_ea);
}

// Получение rm-части (16/32 бит)
dword get_ew() {

    if (mod_mm == 3)
        return get_regw(mod_rm);
    else if (opsize)
        return read_dword(segment, mod_ea);
    else
        return read_word(segment, mod_ea);
}

// Сохранить в rm-часть (8 бит)
void put_eb(byte data) {

    if (mod_mm == 3)
        put_regb(mod_rm, data);
    else
        write_byte(segment, mod_ea, data);
}

// Сохранить в rm-часть (16/32 бит)
void put_ew(dword data) {

    if (mod_mm == 3)
        put_regw(mod_rm, data);
    else if (opsize)
        write_dword(segment, mod_ea, data);
    else
        write_word(segment, mod_ea, data);
}

// Сохранит в reg-часть
void put_rb(byte data)  { put_regb(mod_reg, data); }
void put_rw(dword data) { put_regw(mod_reg, data); }

// Получение reg-части
byte  get_rb() { return get_regb(mod_reg); }
dword get_rw() { return get_regw(mod_reg); }

// Установка флагов
void set_carry  (byte v) { eflags = (eflags & ~C_FLAG) | (v ? C_FLAG : 0); }
void set_over   (byte v) { eflags = (eflags & ~V_FLAG) | (v ? V_FLAG : 0); }
void set_zero   (byte v) { eflags = (eflags & ~Z_FLAG) | (v ? 0 : Z_FLAG); }
void set_sign   (byte v) { eflags = (eflags & ~N_FLAG) | (v ? N_FLAG : 0); }
void set_aux    (byte v) { eflags = (eflags & ~A_FLAG) | (v ? A_FLAG : 0); }
void set_parity (byte v) { eflags = (eflags & ~P_FLAG) | (v ? P_FLAG : 0); }
byte get_carry() { return (eflags & C_FLAG); }

// Базовые 8-битные флаги ZNP
void set_znpb(byte d) {

    eflags &= ~0xC4;
    eflags |= znptable8[d];
}

// Базовые флаги N,Z,P после 16/32-битных инструкции
void set_znpw(dword d) {

    eflags &= ~0xC4;
    dword m = opsize ? 0xffffffff : 0xffff;
    dword s = opsize ? 0x80000000 : 0x8000;

    if (d & s)    eflags |= N_FLAG;
    if (!(d & m)) eflags |= Z_FLAG;

    eflags |= (znptable8[d & 0xff] & P_FLAG);
}

// Для 8/16/32 битных значений
void set_znpbw(dword d, byte size) {

    if (size) set_znpw(d);
    else      set_znpb(d);
}