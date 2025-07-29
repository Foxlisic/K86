i386::i386(int argc, char** argv)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        exit(1);
    }

    SDL_ClearError();
    sdl_window            = SDL_CreateWindow("Intel 80386SX: Hyper Threading Technologies AMI BIOS Rev.1253",
                            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 2*640, 2*400, SDL_WINDOW_SHOWN);
    sdl_renderer          = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
    screen_buffer         = (Uint32*) malloc(640*400*sizeof(Uint32));
    sdl_screen_texture    = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, 640, 400);
    SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

    // Инициализация памяти и данных
    for (int i = 0; i < 65536; i++) ram[i] = 0;
    for (int i = 0; i < 4096; i++) ram[0xC800 + i] = charmap[i];

    // Инициализация процссора
    byte d, c = 0;
    FILE* fp;

    debug_on = 0;
    max_memory = 0xFFFF;

    // Очистка от скверны
    loadcs(0x0000); // CS=0
    loadds(0x0000); // DS=0
    loades(0x0000); // ES=0
    loadss(0x0000); // SS=0

    // Установка на православные поинтеры
    ip    = 0x0100;
    flags = 0x002;

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

    // Разбор входящих параметров
    d = 1;

    while (d < argc) {

        if (argv[d][0] == '-') {

            switch (argv[d][1])
            {
                case 'd': debug_on = 1; break;
            }

        } else {

            fp = fopen(argv[d], "rb");
            if (fp) {
                printf("LOADED %li\n", fread(ram + 0x100, 1, 65536, fp));
                fclose(fp);
            } else {
                printf("File not found\n"); exit(1);
            }
        }

        d++;
    }
}

// Основной цикл работы
int i386::main()
{
    SDL_Rect dstRect;

    dstRect.x = 0;
    dstRect.y = 0;
    dstRect.w = 2*640;
    dstRect.h = 2*400;

    for (;;) {

        // Прием событий
        while (SDL_PollEvent(& evt)) {

            // Событие выхода
            switch (evt.type) {

                case SDL_QUIT:

                    free(screen_buffer);
                    SDL_DestroyTexture(sdl_screen_texture);
                    SDL_FreeFormat(sdl_pixel_format);
                    SDL_DestroyRenderer(sdl_renderer);
                    SDL_DestroyWindow(sdl_window);
                    return 0;
            }
        }

        // Эмулятор
        Uint32 ticks = SDL_GetTicks();
        x86run(3000000);
        refresh();
        Uint32 freet = 16 - (SDL_GetTicks() - ticks);

        // После завершения фрейма обновить экран
        SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, 640*sizeof(Uint32));
        SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
        SDL_RenderClear         (sdl_renderer);
        SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
        SDL_RenderPresent       (sdl_renderer);

        // Расчет остатков от времени выполнения
        SDL_Delay(freet < 1 ? 1 : (freet > 16 ? 16 : freet));
    }
}

// Установка точки
void i386::pset(int x, int y, Uint32 cl)
{
    if (x < 0 || y < 0 || x >= 640 || y >= 400) {
        return;
    } else {
        screen_buffer[640*y + x] = cl;
    }
}

// Обновление экранной области
void i386::refresh()
{
    for (int i = 0; i < 25; i++)
    for (int j = 0; j < 80; j++) {

        int     a = 0xB800 + 2*j + 160*i;
        uint8_t b = ram[a], c = ram[a + 1];

        for (int y = 0; y < 16; y++) {

            int d = ram[0xC800 + 16*b + y];
            for (int x = 0; x < 8; x++) {
                pset(j*8 + x, i*16 + y, dac[d & (0x80 >> x) ? c & 15 : c >> 4]);
            }
        }
    }
}


// ДОСТУП К ПАМЯТИ
// =============================================================================

// Чтение байта из физической или линейной памяти
byte i386::read(dword seg, word offset) {
    return ram[(seg + offset) & 0xFFFF];
}

// Запись байта в память
void i386::write(dword seg, word offset, byte data) {
    ram[(seg + offset) & 0xFFFF] = data;
}

byte i386::io_read(word address) {
    return 0xFF;
}

void i386::io_write(word address, byte data) {
}

// Чтение слова
word i386::read_word(dword seg, word offset) {
    return read(seg, offset) + read(seg, offset + 1)*256;
}

// Запись слова в память
void i386::write_word(dword seg, word offset, word data) {

    write(seg, offset,   data);
    write(seg, offset+1, data>>8);
}

// =============================================================================

// Прочитать следующий байт
byte i386::fetch_byte() {
    return read(seg_cs, ip++);
}

// Прочитать WORD | DWORD, зависит от opsize
word i386::fetch_word() {

    byte a = fetch_byte();
    byte b = fetch_byte();
    return a | (b<<8);
}

// Базовые флаги N,Z,P после 8-битных инструкции
void i386::setznp8(byte val) {

    flags &= ~0xC4;
    flags |= znptable8[val];
}

// Базовые флаги N,Z,P после 16-битных инструкции
void i386::setznp16(word val) {

    flags &= ~0xC4;

    if (val & 0x8000) flags |= N_FLAG;
    if (val == 0)     flags |= Z_FLAG;
    flags |= (znptable8[val&0xff] & P_FLAG);
}

// Флаги после сложения 8 бит
byte i386::setadd8(byte a, byte b) {

    word c = (word)a + (word)b;

    flags &= ~0x8D5;
    flags |= znptable8[c & 0xFF];

    if (c & 0x100) flags |= C_FLAG;
    if (!((a^b)&0x80)&&((a^c)&0x80)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)      flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
byte i386::setadd8nc(byte a, byte b) {

    word c = (word)a + (word)b;

    flags &= ~0x8D4;
    flags |= znptable8[c&0xFF];

    if (!((a^b)&0x80)&&((a^c)&0x80)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)      flags |= A_FLAG;

    return c;
}

// Флаги после сложения 8 бит
byte i386::setadc8(byte a, byte b, byte tempc) {

    word c = (word)a + (word)b + tempc;

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c & 0x100) flags |= C_FLAG;
    if (!((a^b)&0x80)&&((a^c)&0x80))  flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)       flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
word i386::setadd16(word a, word b) {

    dword c = (dword)a + (dword)b;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c & 0x10000) flags |= C_FLAG;
    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит без CF
word i386::setadd16nc(word a, word b) {

    dword c = (dword)a + (dword)b;

    flags &= ~0x8D4;
    setznp16(c & 0xffff);

    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после сложения 16 бит
word i386::setadc16(word a, word b, byte tempc) {

    dword c = (dword)a + (dword)b + tempc;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c & 0x10000) flags |= C_FLAG;
    if (!((a^b)&0x8000)&&((a^c)&0x8000)) flags |= V_FLAG;
    if (((a&0xF)+(b&0xF))&0x10)          flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит
byte i386::setsub8(byte a, byte b) {

    word c = (word)a - (word)b;

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c&0x100) flags|=C_FLAG;
    if ((a^b)&(a^c)&0x80)       flags|=V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags|=A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит без CF
byte i386::setsub8nc(byte a, byte b) {

    word c=(word)a - (word)b;

    flags &= ~0x8D4;
    flags |= znptable8[c&0xFF];

    if ((a^b)&(a^c)&0x80)       flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 8 бит
byte i386::setsbc8(byte a, byte b, byte tempc) {

    word c = (word)a - (((word)b) + tempc);

    flags &= ~0x8D5;
    flags |= znptable8[c&0xFF];

    if (c&0x100)                flags |= C_FLAG;
    if ((a^b)&(a^c)&0x80)       flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 16 бит
word i386::setsub16(word a, word b) {

    dword c = (dword)a - (dword)b;

    flags &= ~0x8D5;
    setznp16(c & 0xffff);

    if (c&0x10000) flags |= C_FLAG;
    if ((a^b)&(a^c)&0x8000)     flags |= V_FLAG;
    if (((a&0xF)-(b&0xF))&0x10) flags |= A_FLAG;

    return c;
}

// Флаги после вычитания 16 бит без CF
word i386::setsub16nc(word a, word b) {

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
word i386::setsbc16(word a, word b, byte tempc) {

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
byte i386::setor8(byte a, byte b) {

    byte c = a | b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции OR 16 бит
word i386::setor16(word a, word b) {

    word c = a | b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции AND 8 бит
byte i386::setand8(byte a, byte b) {

    byte c = a & b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции AND 16 бит
word i386::setand16(word a, word b) {

    word c = a & b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции XOR 8 бит
byte i386::setxor8(byte a, byte b) {

    byte c = a ^ b;

    setznp8(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Флаги после операции XOR 16 бит
word i386::setxor16(word a, word b) {

    word c = a ^ b;

    setznp16(c);
    flags &=~ (C_FLAG | V_FLAG | A_FLAG);

    return c;
}

// Десятичная коррекция после сложения
void i386::daa() {

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
void i386::das() {

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
void i386::aaa() {

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
void i386::aas() {

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
void i386::aam() {

    byte tb = fetch_byte();
    setr8(REG_AH, AL_ / tb);
    setr8(REG_AL, AL_ % tb);
    setznp16(AX_);
}

// Коррекция после деления
void i386::aad() {

    byte tb = fetch_byte();
    AX_ = (AH_*tb + AL_) & 0x00FF;
    setznp16(AX_);
}

// УПРАВЛЕНИЕ ПРОЦЕССОРОМ
// =============================================================================

// Чтение из 8-битного регистра
byte i386::getr8(byte id) {
    return id & 4 ? regs[id&3] >> 8 : regs[id&3];
}

// Запись в 8-битный регистр
void i386::setr8(byte id, byte v) {

    if (id & 4) {
        regs[id&3] = (regs[id&3] & 0x00ff) | ((word)v << 8);
    } else {
        regs[id&3] = (regs[id&3] & 0xff00) | v;
    }
}

// Чтение и запись в 16-битные регистры
word i386::getr16(byte id) {
    return regs[id];
}

void i386::setr16(byte id, word v) {
    regs[id] = v;
}

// Прочитать эффективный адрес
void i386::fetchea() {

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
byte i386::geteab() {

    if (cpu_mod == 3)
        return getr8(cpu_rm);
    else
        return read(segment, eaaddr);
}

// Прочитать word из r/m
word i386::geteaw() {

    if (cpu_mod == 3) return getr16(cpu_rm);
    return read_word(segment, eaaddr);
}

// Записать byte в r/m
void i386::seteab(byte v) {

    if (cpu_mod == 3) {
        setr8(cpu_rm, v);
    } else {
        write(segment, eaaddr, v);
    }
}

// Записать word в r/m
void i386::seteaw(word v) {

    if (cpu_mod == 3) {
        regs[cpu_rm] = v;
    } else {
        write_word(segment, eaaddr, v);
    }
}

// Запись в стек
void i386::push(word v) {

    write_word(seg_ss, ((SP_ - 2) & 0xffff), v);
    SP_ -= 2;
}

// Извлечение из стека
word i386::pop() {

    word r = read_word(seg_ss, SP_);
    SP_ += 2;
    return r;
}

// Вызов прерывания
void i386::interrupt(byte int_id) {

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
void i386::callfar(word _cs, word _ip) {

    word cs_ = segs[SEG_CS], ip_ = ip;
    ip = _ip;
    loadcs(_cs);
    push(cs_);
    push(ip_);
}

// Групповые операции АЛУ 8 бит
byte i386::groupalu8(byte mode, byte a, byte b) {

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
word i386::groupalu16(byte mode, word a, word b) {

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
word i386::groupshift(byte mode, byte bit, word temp, byte n) {

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
void i386::autorep(byte flag_test) {

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
void i386::ud(byte code) {


}

// Запуск в работу
word i386::x86run(word instr_cnt) {

    tstates = 0;
    char    offset;


    while (instr_cnt) {

        // Остановка процессора
        if (inhlt) {
            return 1;
        }

        if (debug_on) {
            disassemble(segs[SEG_CS]*16 + ip);
            printf("%04X:%04X %s\n", segs[SEG_CS], ip, dis_row);
        }

        rep     = 0;
        sel_seg = 0;
        noint   = 0;
        p66     = 0;
        p67     = 0;
        segment = seg_ds;
        trap    = flags & T_FLAG;
        tempc   = flags & C_FLAG;
        ip_start = ip;

        tstates++;

        do {

            rdtsc++;
            cont   = 0;
            opcode = fetch_byte();

            switch (opcode) {

                // ADD
                case 0x00: fetchea(); seteab(setadd8 (geteab(), getr8 (cpu_reg))); break;
                case 0x01: fetchea(); seteaw(setadd16(geteaw(), getr16(cpu_reg))); break;
                case 0x02: fetchea(); setr8 (cpu_reg, setadd8 (getr8 (cpu_reg), geteab())); break;
                case 0x03: fetchea(); setr16(cpu_reg, setadd16(getr16(cpu_reg), geteaw())); break;
                case 0x04: setr8 (REG_AL, setadd8 (regs[REG_AL], fetch_byte())); break;
                case 0x05: setr16(REG_AX, setadd16(regs[REG_AX], fetch_word())); break;
                case 0x06: push(segs[SEG_ES]); break;
                case 0x07: loades(pop()); break;

                // OR
                case 0x08: fetchea(); seteab(setor8 (geteab(), getr8 (cpu_reg))); break;
                case 0x09: fetchea(); seteaw(setor16(geteaw(), getr16(cpu_reg))); break;
                case 0x0A: fetchea(); setr8 (cpu_reg, setor8 (getr8 (cpu_reg), geteab())); break;
                case 0x0B: fetchea(); setr16(cpu_reg, setor16(getr16(cpu_reg), geteaw())); break;
                case 0x0C: setr8 (REG_AL, setor8 (regs[REG_AL], fetch_byte())); break;
                case 0x0D: setr16(REG_AX, setor16(regs[REG_AX], fetch_word())); break;
                case 0x0E: push(segs[SEG_CS]); break;
                case 0x0F: extended_instr(); break;

                // ADС
                case 0x10: fetchea(); seteab(setadc8 (geteab(), getr8 (cpu_reg), tempc)); break;
                case 0x11: fetchea(); seteaw(setadc16(geteaw(), getr16(cpu_reg), tempc)); break;
                case 0x12: fetchea(); setr8 (cpu_reg, setadc8 (getr8 (cpu_reg), geteab(), tempc)); break;
                case 0x13: fetchea(); setr16(cpu_reg, setadc16(getr16(cpu_reg), geteaw(), tempc)); break;
                case 0x14: setr8 (REG_AL, setadc8 (regs[REG_AL], fetch_byte(), tempc)); break;
                case 0x15: setr16(REG_AX, setadc16(regs[REG_AX], fetch_word(), tempc)); break;
                case 0x16: push(segs[SEG_SS]); break;
                case 0x17: loadss(pop()); noint = 1; break;

                // SBB
                case 0x18: fetchea(); seteab(setsbc8 (geteab(), getr8 (cpu_reg), tempc)); break;
                case 0x19: fetchea(); seteaw(setsbc16(geteaw(), getr16(cpu_reg), tempc)); break;
                case 0x1A: fetchea(); setr8 (cpu_reg, setsbc8 (getr8 (cpu_reg), geteab(), tempc)); break;
                case 0x1B: fetchea(); setr16(cpu_reg, setsbc16(getr16(cpu_reg), geteaw(), tempc)); break;
                case 0x1C: setr8 (REG_AL, setsbc8 (regs[REG_AL], fetch_byte(), tempc)); break;
                case 0x1D: setr16(REG_AX, setsbc16(regs[REG_AX], fetch_word(), tempc)); break;
                case 0x1E: push(segs[SEG_DS]); break;
                case 0x1F: loadds(pop()); break;

                // AND
                case 0x20: fetchea(); seteab(setand8 (geteab(), getr8 (cpu_reg))); break;
                case 0x21: fetchea(); seteaw(setand16(geteaw(), getr16(cpu_reg))); break;
                case 0x22: fetchea(); setr8 (cpu_reg, setand8 (getr8 (cpu_reg), geteab())); break;
                case 0x23: fetchea(); setr16(cpu_reg, setand16(getr16(cpu_reg), geteaw())); break;
                case 0x24: setr8 (REG_AL, setand8 (regs[REG_AL], fetch_byte())); break;
                case 0x25: setr16(REG_AX, setand16(regs[REG_AX], fetch_word())); break;
                case 0x26: sel_seg = 1; segment = seg_es; cont = 1; break;
                case 0x27: daa(); break;

                // SUB
                case 0x28: fetchea(); seteab(setsub8 (geteab(), getr8 (cpu_reg))); break;
                case 0x29: fetchea(); seteaw(setsub16(geteaw(), getr16(cpu_reg))); break;
                case 0x2A: fetchea(); setr8 (cpu_reg, setsub8 (getr8 (cpu_reg), geteab())); break;
                case 0x2B: fetchea(); setr16(cpu_reg, setsub16(getr16(cpu_reg), geteaw())); break;
                case 0x2C: setr8 (REG_AL, setsub8 (regs[REG_AL], fetch_byte())); break;
                case 0x2D: setr16(REG_AX, setsub16(regs[REG_AX], fetch_word())); break;
                case 0x2E: sel_seg = 1; segment = seg_cs; cont = 1; break;
                case 0x2F: das(); break;

                // XOR
                case 0x30: fetchea(); seteab(setxor8 (geteab(), getr8 (cpu_reg))); break;
                case 0x31: fetchea(); seteaw(setxor16(geteaw(), getr16(cpu_reg))); break;
                case 0x32: fetchea(); setr8 (cpu_reg, setxor8 (getr8 (cpu_reg), geteab())); break;
                case 0x33: fetchea(); setr16(cpu_reg, setxor16(getr16(cpu_reg), geteaw())); break;
                case 0x34: setr8 (REG_AL, setxor8 (regs[REG_AL], fetch_byte())); break;
                case 0x35: setr16(REG_AX, setxor16(regs[REG_AX], fetch_word())); break;
                case 0x36: sel_seg = 1; segment = seg_ss; cont = 1; break;
                case 0x37: aaa(); break;

                // CMP
                case 0x38: fetchea(); setsub8 (geteab(), getr8 (cpu_reg)); break;
                case 0x39: fetchea(); setsub16(geteaw(), getr16(cpu_reg)); break;
                case 0x3A: fetchea(); setsub8 (getr8 (cpu_reg), geteab()); break;
                case 0x3B: fetchea(); setsub16(getr16(cpu_reg), geteaw()); break;
                case 0x3C: setsub8 (regs[REG_AL], fetch_byte()); break;
                case 0x3D: setsub16(regs[REG_AX], fetch_word()); break;
                case 0x3E: sel_seg = 1; segment = seg_ds; cont = 1; break;
                case 0x3F: aas(); break;

                // INC r16
                case 0x40: case 0x41: case 0x42: case 0x43:
                case 0x44: case 0x45: case 0x46: case 0x47: {

                    regs[opcode&7] = setadd16nc(regs[opcode&7], 1);
                    break;
                }

                // DEC r16
                case 0x48: case 0x49: case 0x4A: case 0x4B:
                case 0x4C: case 0x4D: case 0x4E: case 0x4F: {

                    regs[opcode&7] = setsub16nc(regs[opcode&7], 1);
                    break;
                }

                // PUSH r16
                case 0x50: case 0x51: case 0x52: case 0x53:
                case 0x54: case 0x55: case 0x56: case 0x57: {

                    push(regs[opcode&7]);
                    break;
                }

                // POP r16
                case 0x58: case 0x59: case 0x5A: case 0x5B:
                case 0x5C: case 0x5D: case 0x5E: case 0x5F: {

                    regs[opcode&7] = pop();
                    break;
                }

                // PUSHA
                case 0x60: {

                    tempw = regs[REG_SP];
                    for (int i = 0; i < 8; i++)
                        push(i == REG_SP ? tempw : regs[i]);

                    break;
                }

                // POPA
                case 0x61: {

                    for (int i = 7; i >= 0; i--) {
                        if (i == REG_SP) tempw = pop();
                        else regs[i] = pop();
                    }
                    regs[REG_SP] = tempw;
                    break;
                }

                // FS: GS:
                case 0x64: sel_seg = 1; segment = seg_fs; cont = 1; break;
                case 0x65: sel_seg = 1; segment = seg_gs; cont = 1; break;

                // opsize, adsize
                case 0x66: p66 = ~p66; cont = 1; break;
                case 0x67: p67 = ~p67; cont = 1; break;

                // PUSH imm16
                case 0x68: push(fetch_word()); break;
                case 0x6a: tempw = fetch_byte(); tempw = (tempw & 0x80 ? 0xff00 : 0) | tempw; push(tempw); break;

                // IMUL r16,rm,i16
                case 0x69: {

                    fetchea();
                    tempw = fetch_word();
                    templ = (long)((int)geteaw()) * (long)((int)tempw);
                    setr16(cpu_reg, templ);

                    if (templ & 0xffff0000)
                         flags |=  (C_FLAG | V_FLAG);
                    else flags &= ~(C_FLAG | V_FLAG);

                    break;
                }

                // IMUL r16,rm,i8
                case 0x6B: {

                    fetchea();
                    tempw = fetch_byte();
                    tempw = tempw & 0x80 ? (0xff00 | tempw) : tempw;
                    templ = (long)((int)geteaw()) * (long)((int)tempw);
                    setr16(cpu_reg, templ);

                    if (templ & 0xffff0000)
                         flags |=  (C_FLAG | V_FLAG);
                    else flags &= ~(C_FLAG | V_FLAG);

                    break;
                }

                // JO, JNO
                case 0x70: offset = (char)fetch_byte(); if   (flags&V_FLAG)  ip += offset; break;
                case 0x71: offset = (char)fetch_byte(); if (!(flags&V_FLAG)) ip += offset; break;

                // JB, JNB
                case 0x72: offset = (char)fetch_byte(); if   (flags&C_FLAG)  ip += offset; break;
                case 0x73: offset = (char)fetch_byte(); if (!(flags&C_FLAG)) ip += offset; break;

                // JZ, JNZ
                case 0x74: offset = (char)fetch_byte(); if   (flags&Z_FLAG)  ip += offset; break;
                case 0x75: offset = (char)fetch_byte(); if (!(flags&Z_FLAG)) ip += offset; break;

                // JBE, JNBE
                case 0x76: offset = (char)fetch_byte(); if   (flags&(C_FLAG|Z_FLAG))  ip += offset; break;
                case 0x77: offset = (char)fetch_byte(); if (!(flags&(C_FLAG|Z_FLAG))) ip += offset; break;

                // JS, JNS
                case 0x78: offset = (char)fetch_byte(); if   (flags&N_FLAG)  ip += offset; break;
                case 0x79: offset = (char)fetch_byte(); if (!(flags&N_FLAG)) ip += offset; break;

                // JP, JNP
                case 0x7A: offset = (char)fetch_byte(); if   (flags&P_FLAG)  ip += offset; break;
                case 0x7B: offset = (char)fetch_byte(); if (!(flags&P_FLAG)) ip += offset; break;

                // JL, JNL
                case 0x7C: offset = (char)fetch_byte(); if (!!(flags&N_FLAG) != !!(flags&V_FLAG)) ip += offset; break;
                case 0x7D: offset = (char)fetch_byte(); if (!!(flags&N_FLAG) == !!(flags&V_FLAG)) ip += offset; break;

                // JLE, JNLE: ZF=1 OR (SF!=OF); ZF=0 AND (SF=OF)
                case 0x7E: offset = (char)fetch_byte(); if ( (flags&Z_FLAG) ||  !!(flags&N_FLAG) != !!(flags&V_FLAG))  ip += offset; break;
                case 0x7F: offset = (char)fetch_byte(); if (!(flags&Z_FLAG) && (!!(flags&N_FLAG) == !!(flags&V_FLAG))) ip += offset; break;

                // GRP#1 e,#8
                case 0x80:
                case 0x82: {

                    fetchea();
                    tempb  = geteab();
                    tempb2 = fetch_byte();
                    tempb = groupalu8(cpu_reg, tempb, tempb2);
                    if (cpu_reg < 7) seteab(tempb);
                    break;
                }

                // GRP#1 e,#16
                case 0x81: {

                    fetchea();
                    tempw  = geteaw();
                    tempw2 = fetch_word();
                    tempw = groupalu16(cpu_reg, tempw, tempw2);
                    if (cpu_reg < 7) seteaw(tempw);
                    break;
                }

                // GRP#1 e16,#8
                case 0x83: {

                    fetchea();
                    tempw = geteaw();
                    tempb = fetch_byte();
                    tempw = groupalu16(cpu_reg, tempw, tempb | (tempb&0x80 ? 0xFF00 : 0));
                    if (cpu_reg < 7) seteaw(tempw);
                    break;
                }

                // TEST 8/16,r
                case 0x84: fetchea(); setand8 (geteab(), getr8 (cpu_reg)); break;
                case 0x85: fetchea(); setand16(geteaw(), getr16(cpu_reg)); break;

                // XCHG 8/16,r
                case 0x86: fetchea(); tempb = geteab(); seteab(getr8 (cpu_reg)); setr8 (cpu_reg, tempb); break;
                case 0x87: fetchea(); tempw = geteaw(); seteaw(getr16(cpu_reg)); setr16(cpu_reg, tempw); break;

                // MOV modrm
                case 0x88: fetchea(); seteab(getr8 (cpu_reg)); break;
                case 0x89: fetchea(); seteaw(getr16(cpu_reg)); break;
                case 0x8A: fetchea(); setr8 (cpu_reg, geteab()); break;
                case 0x8B: fetchea(); setr16(cpu_reg, geteaw()); break;

                // MOV w, sreg
                case 0x8C: {

                    fetchea();
                    switch (rmdat & 0x38) {
                        case 0x00: seteaw(segs[SEG_ES]); break;
                        case 0x08: seteaw(segs[SEG_CS]); break;
                        case 0x10: seteaw(segs[SEG_SS]); break;
                        case 0x18: seteaw(segs[SEG_DS]); break;
                        case 0x20: seteaw(segs[SEG_FS]); break;
                        case 0x28: seteaw(segs[SEG_GS]); break;
                    }
                    break;
                }

                // LEA r16, ea
                case 0x8D: fetchea(); regs[cpu_reg] = eaaddr; break;

                // MOV sreg, r16
                case 0x8E: {

                    fetchea();
                    noint = 1;
                    switch (rmdat & 0x38) {
                        case 0x00: loades(geteaw()); break;
                        case 0x08: ud(6); break;
                        case 0x10: loadss(geteaw()); break;
                        case 0x18: loadds(geteaw()); break;
                        case 0x20: loadfs(geteaw()); break;
                        case 0x28: loadgs(geteaw()); break;
                    }
                    break;
                }

                // POP rm
                case 0x8F: fetchea(); seteaw(pop()); break;

                // XCHG ax, r16
                case 0x90: case 0x91: case 0x92: case 0x93:
                case 0x94: case 0x95: case 0x96: case 0x97: {

                    tempw = regs[opcode&7];
                    regs[opcode&7] = regs[REG_AX];
                    regs[REG_AX] = tempw;
                    break;
                }

                // CBW, CWD
                case 0x98: AX_ = (AX_ & 0x0080  ? 0xff00 : 0) | (AX_ & 0xff); break;
                case 0x99: DX_ = (AX_ & 0x8000) ? 0xffff : 0; break;

                // CALL cs:ip
                case 0x9A: tempw = fetch_word(); callfar(fetch_word(), tempw); break;
                case 0x9B: /* FWAIT */ break;

                // PUSHF/POPF
                case 0x9C: push((flags & ~0x2A) | 2); break;
                case 0x9D: flags = pop() & 0xfff; break;

                // SAHF, LAHF
                case 0x9E: flags = (flags & 0xFF00) | (AX_ >> 8); break;
                case 0x9F: setr8(REG_AH, flags); break;

                // MOV acc,16
                case 0xA0: tempw = fetch_word(); setr8(REG_AX, read(segment, tempw)); break;
                case 0xA1: tempw = fetch_word(); AX_ = read_word(segment, tempw); break;
                case 0xA2: tempw = fetch_word(); write     (segment, tempw, AX_); break;
                case 0xA3: tempw = fetch_word(); write_word(segment, tempw, AX_); break;

                // MOVSB: Переместить байт
                case 0xA4: {

                    REPINIT;
                    write(seg_es, DI_, read(segment, SI_));
                    REPINC(SI_,1);
                    REPINC(DI_,1);
                    autorep(0);
                    break;
                }

                // MOVSW: Переместить слово
                case 0xA5: {

                    REPINIT;
                    write_word(seg_es, DI_, read_word(segment, SI_));
                    REPINC(SI_, p66 ? 4 : 2);
                    REPINC(DI_, p66 ? 4 : 2);
                    autorep(0);
                    break;
                }

                // CMPSB
                case 0xA6: {

                    REPINIT;
                    setsub8(read(segment, SI_), read(seg_es, DI_));
                    REPINC(SI_,1);
                    REPINC(DI_,1);
                    autorep(0);
                    break;
                }

                // CMPSW
                case 0xA7: {

                    REPINIT;
                    setsub16(read_word(segment, SI_), read_word(seg_es,  DI_));
                    REPINC(SI_, p66 ? 4 : 2);
                    REPINC(DI_, p66 ? 4 : 2);
                    autorep(0);
                    break;
                }

                // TEST al,#8
                case 0xA8: setand8 (AX_, fetch_byte()); break;
                case 0xA9: setand16(AX_, fetch_word()); break;

                // STOSB
                case 0xAA: {

                    REPINIT;
                    write(seg_es, DI_, AL_);
                    REPINC(DI_, 1);
                    autorep(0);
                    break;
                }

                // STOSW
                case 0xAB: {

                    REPINIT;
                    write_word(seg_es, DI_, AX_);
                    REPINC(DI_, p66 ? 4 : 2);
                    autorep(0);
                    break;
                }

                // LODSB
                case 0xAC: {

                    REPINIT;
                    setr8(REG_AL, read(segment, SI_));
                    REPINC(SI_, 1);
                    autorep(0);
                    break;
                }

                // LODSW
                case 0xAD: {

                    REPINIT;
                    AX_ = read_word(segment, SI_);
                    REPINC(SI_, p66 ? 4 : 2);
                    autorep(0);
                    break;
                }

                // SCASB
                case 0xAE: {

                    REPINIT;
                    setsub8(AL_, read(seg_es, DI_));
                    REPINC(DI_, 1);
                    autorep(1);
                    break;
                }

                // SCASW
                case 0xAF: {

                    REPINIT;
                    setsub16(AX_, read_word(seg_es,  DI_));
                    REPINC(DI_, p66 ? 4 : 2);
                    autorep(1);
                    break;
                }

                // MOV r8, #8
                case 0xB0: case 0xB1: case 0xB2: case 0xB3:
                case 0xB4: case 0xB5: case 0xB6: case 0xB7: {

                    setr8(opcode&7, fetch_byte());
                    break;
                }

                // MOV r16, #16
                case 0xB8: case 0xB9: case 0xBA: case 0xBB:
                case 0xBC: case 0xBD: case 0xBE: case 0xBF: {

                    regs[opcode&7] = fetch_word();
                    break;
                }

                // Grp#shift
                case 0xC0: fetchea(); tempb = fetch_byte(); seteab(groupshift(cpu_reg, 0, geteab(), tempb & 7)); break;
                case 0xC1: fetchea(); tempb = fetch_byte(); seteaw(groupshift(cpu_reg, 1, geteaw(), tempb & 31)); break;

                // RET #16/RET
                case 0xC2: tempw = fetch_word(); ip = pop(); SP_ += tempw; break;
                case 0xC3: ip = pop(); break;

                // LES, LDS
                case 0xC4: fetchea(); setr16(cpu_reg, read_word(segment, eaaddr)); loades(read_word(segment, eaaddr+2)); break;
                case 0xC5: fetchea(); setr16(cpu_reg, read_word(segment, eaaddr)); loadds(read_word(segment, eaaddr+2)); break;

                // MOV e, #8/16
                case 0xC6: fetchea(); seteab(fetch_byte()); break;
                case 0xC7: fetchea(); seteaw(fetch_word()); break;

                // ENTER / LEAVE
                case 0xC8: ud(4); break;
                case 0xC9: ud(5); break;

                // RETF [#16]
                case 0xCA: tempw = fetch_word(); tempw2 = pop(); loadcs(pop()); ip = tempw; SP_ += tempw; break;
                case 0xCB: tempw = fetch_word(); tempw2 = pop(); loadcs(pop()); ip = tempw; break;

                // INT xx
                case 0xCC: interrupt(3); break;
                case 0xCD: interrupt(fetch_byte()); break;
                case 0xCE: if (flags & V_FLAG) interrupt(4); break;

                // IRET
                case 0xCF: tempw = pop(); tempw2 = pop(); flags = pop() & 0xfff; loadcs(tempw2); ip = tempw; break;

                // Сдвиговые
                case 0xD0: fetchea(); seteab(groupshift(cpu_reg, 0, geteab(), 1)); break;
                case 0xD1: fetchea(); seteaw(groupshift(cpu_reg, 1, geteaw(), 1)); break;
                case 0xD2: fetchea(); seteab(groupshift(cpu_reg, 0, geteab(), CX_&7));  break;
                case 0xD3: fetchea(); seteaw(groupshift(cpu_reg, 1, geteaw(), CX_&31)); break;

                // AAM, AAD
                case 0xD4: aam(); break;
                case 0xD5: aad(); break;

                // SALC, XLAT
                case 0xD6: setr8(REG_AL, flags & C_FLAG ? 0xff : 00);
                case 0xD7: setr8(REG_AL, read(segment, BX_ + (AX_ & 255))); break;

                // ESC-последовательности
                case 0xD8: case 0xD9: case 0xDA: case 0xDB:
                case 0xDC: case 0xDD: case 0xDE: case 0xDF: {

                    fetchea();
                    break;
                }

                // LOOP[NZ|Z] JCXZ
                case 0xE0: offset = (char) fetch_byte(); CX_--; if ( CX_ && !(flags & Z_FLAG)) ip += offset; break;
                case 0xE1: offset = (char) fetch_byte(); CX_--; if ( CX_ &&  (flags & Z_FLAG)) ip += offset; break;
                case 0xE2: offset = (char) fetch_byte(); CX_--; if ( CX_) ip += offset; break;
                case 0xE3: offset = (char) fetch_byte();        if (!CX_) ip += offset; break;

                // IN/OUT #8
                case 0xE4: tempb = fetch_byte(); setr8(REG_AL, io_read(tempb)); break;
                case 0xE5: tempb = fetch_byte(); setr8(REG_AL, io_read(tempb)); setr8(REG_AH, io_read(tempb+1)); break;
                case 0xE6: tempb = fetch_byte(); io_write(tempb, AL_); break;
                case 0xE7: tempb = fetch_byte(); io_write(tempb, AL_); io_write(tempb+1, AH_); break;

                // CALL, JMP #8/16
                case 0xE8: tempw = fetch_word(); push(ip); ip += tempw; break;
                case 0xE9: tempw = fetch_word(); ip += tempw; break;
                case 0xEA: tempw = fetch_word(); tempw2 = fetch_word(); loadcs(tempw2); ip = tempw; break;
                case 0xEB: tempb = fetch_byte(); ip += (tempb & 0x80 ? tempb - 256 : tempb); break;

                // IN/OUT dx
                case 0xEC: setr8(REG_AL, io_read(DX_)); break;
                case 0xED: setr8(REG_AL, io_read(DX_)); setr8(REG_AH, io_read(DX_+1)); break;
                case 0xEE: io_write(DX_, AL_); break;
                case 0xEF: io_write(DX_, AL_); io_write(DX_+1, AH_); break;

                // LOCK: INT1, REP, HLT, CMC
                case 0xF0: cont = 1; break;
                case 0xF1: interrupt(1); break;
                case 0xF2: rep = REPNZ; cont = 1; break;
                case 0xF3: rep = REPZ; cont = 1; break;
                case 0xF4: inhlt = 1; ip--; break;
                case 0xF5: flags ^= C_FLAG; break;

                // Групповые инструкции #byte
                case 0xF6: {

                    fetchea(); tempb = geteab();
                    switch (cpu_reg) {

                        // TEST/NOT/NEG b
                        case 0:
                        case 1: setand8(tempb, fetch_byte()); break;
                        case 2: seteab(~tempb); break;
                        case 3: seteab(setsub8(0, tempb)); break;

                        // MUL AL, b
                        case 4: {

                            setznp8(AL_);
                            AX_ = AL_ * tempb;
                            if (AX_) flags &= ~Z_FLAG;           else flags |= Z_FLAG;
                            if (AH_) flags |= (C_FLAG | V_FLAG); else flags &= ~(C_FLAG|V_FLAG);
                            break;
                        }

                        // IMUL AL, b
                        case 5: {

                            setznp8(AL_);
                            AX_ = (int)((char)AL_)*(int)((char)tempb);
                            if (AX_) flags &= ~Z_FLAG;         else flags |= Z_FLAG;
                            if (AH_) flags |= (C_FLAG|V_FLAG); else flags &= ~(C_FLAG|V_FLAG);
                            break;
                        }

                        // DIV AL, b
                        case 6: {

                            tempw = AX_;
                            if (tempb) {

                                tempw2 = tempw % tempb;
                                tempw /= tempb;
                                setr8(REG_AH, tempw2);
                                setr8(REG_AL, tempw);

                            } else interrupt(0);

                            break;
                        }

                        // IDIV AL, b
                        case 7: {

                            tempws = (int) AX_;
                            if (tempb) {

                                tempw2  = tempws % (int)((char)tempb);
                                tempws /= (int)((char)tempb);
                                setr8(REG_AH, tempw2);
                                setr8(REG_AL, tempws);

                            } else interrupt(0);

                            break;
                        }
                    }
                    break;
                }

                // Групповые инструкции #word
                case 0xF7: {

                    fetchea();
                    tempw = geteaw();

                    switch (cpu_reg) {

                        // TEST/NOT/NEG w
                        case 0:
                        case 1: setand16(tempw, fetch_word()); break;
                        case 2: seteaw(~tempw); break;
                        case 3: seteaw(setsub16(0, tempw)); break;

                        // MUL AX, w
                        case 4: {

                            setznp16(AX_);
                            templ = AX_ * tempw;
                            AX_ = templ;
                            DX_ = templ >> 16;
                            if (AX_ | DX_)   flags &= ~Z_FLAG; else flags |= Z_FLAG;
                            if (DX_) flags |= (C_FLAG|V_FLAG); else flags &= ~(C_FLAG|V_FLAG);
                            break;
                        }

                        // IMUL AX, w
                        case 5: {

                            setznp16(AX_);
                            templ = (long)((int)AX_) * (long)((int)tempw);

                            AX_ = templ;
                            DX_ = (word)(templ >> 16);

                            if (AX_ && DX_ != 0xFFFF)
                                 flags |=  (C_FLAG | V_FLAG);
                            else flags &= ~(C_FLAG | V_FLAG);

                            if (AX_ | DX_) flags &= ~Z_FLAG; else flags |= Z_FLAG;
                            break;
                        }

                        // DIV AX, w
                        case 6: {

                            templ = ((dword)DX_ << 16) | AX_;
                            if (tempw)
                            {
                                tempw2 = templ % tempw;
                                templ /= tempw;
                                DX_ = tempw2;
                                AX_ = templ;
                            }
                            else interrupt(0);
                            break;
                        }

                        // IDIV AX, w
                        case 7: {

                            if (DX_ != 0 && DX_ != 0xFFFF) {
                                interrupt(0);
                                break;
                            }

                            templs = (int)(((long)DX_ << 16) | AX_);

                            if (tempw)
                            {
                                tempw2  = templs % (long)(int)tempw;
                                templs /= (long)(int)tempw;
                                DX_ = tempw2;
                                AX_ = templs;
                            }
                            else interrupt(0);
                            break;
                        }
                    }
                    break;
                }

                // CLC, STC, CLI, STI
                case 0xF8: flags &= ~C_FLAG; break;
                case 0xF9: flags |=  C_FLAG; break;
                case 0xFA: flags &= ~I_FLAG; break;
                case 0xFB: flags |=  I_FLAG; break;
                case 0xFC: flags &= ~D_FLAG; break;
                case 0xFD: flags |=  D_FLAG; break;

                // INC/DEC b8
                case 0xFE: {

                    fetchea();
                    tempb = geteab();
                    switch (cpu_reg) {

                        case 0: seteab(setadd8nc(tempb, 1)); break;
                        case 1: seteab(setsub8nc(tempb, 1)); break;
                        default: ud(3);
                    }
                    break;
                }

                // Групповые смешанные
                case 0xFF: {

                    fetchea();
                    tempw = geteaw();
                    switch (cpu_reg) {

                        case 0: seteaw(setadd16nc(tempw, 1)); break;
                        case 1: seteaw(setsub16nc(tempw, 1)); break;

                        // CALL
                        case 2: push(ip); ip = tempw; break;

                        // CALL far
                        case 3: {

                            tempw  = read_word(segment, eaaddr);
                            tempw2 = read_word(segment, eaaddr + 2);
                            callfar(tempw2, tempw);
                            break;
                        }

                        // JMP
                        case 4: ip = tempw; break;

                        // JMP far
                        case 5: {

                            tempw  = read_word(segment, eaaddr);
                            tempw2 = read_word(segment, eaaddr+2);
                            loadcs(tempw2); ip = tempw;
                            break;
                        }

                        // PUSH w
                        case 6: push(geteaw()); break;

                        default: ud(1);
                    }
                    break;
                }

                default: ud(2); break;
            }
        }
        while (cont);

        // Если вызван trap
        if (trap && (flags & T_FLAG) && !noint) interrupt(1);

        instr_cnt--;
    }

    return 0;
}

// Расширенные инструкции
void i386::extended_instr() {

    opcode = fetch_byte();
    word offset;

    switch (opcode) {

        // RDTSC
        case 0x31: AX_ = rdtsc&0xffff; DX_ = 0; break;

        // JO, JNO
        case 0x80: offset = (word)fetch_word(); if   (flags&V_FLAG)  ip += offset; break;
        case 0x81: offset = (word)fetch_word(); if (!(flags&V_FLAG)) ip += offset; break;

        // JB, JNB
        case 0x82: offset = (word)fetch_word(); if   (flags&C_FLAG)  ip += offset; break;
        case 0x83: offset = (word)fetch_word(); if (!(flags&C_FLAG)) ip += offset; break;

        // JZ, JNZ
        case 0x84: offset = (word)fetch_word(); if   (flags&Z_FLAG)  ip += offset; break;
        case 0x85: offset = (word)fetch_word(); if (!(flags&Z_FLAG)) ip += offset; break;

        // JBE, JNBE
        case 0x86: offset = (word)fetch_word(); if   (flags&(C_FLAG|Z_FLAG))  ip += offset; break;
        case 0x87: offset = (word)fetch_word(); if (!(flags&(C_FLAG|Z_FLAG))) ip += offset; break;

        // JS, JNS
        case 0x88: offset = (word)fetch_word(); if   (flags&N_FLAG)  ip += offset; break;
        case 0x89: offset = (word)fetch_word(); if (!(flags&N_FLAG)) ip += offset; break;

        // JP, JNP
        case 0x8A: offset = (word)fetch_word(); if   (flags&P_FLAG)  ip += offset; break;
        case 0x8B: offset = (word)fetch_word(); if (!(flags&P_FLAG)) ip += offset; break;

        // JL, JNL
        case 0x8C: offset = (word)fetch_word(); if (!!(flags&N_FLAG) != !!(flags&V_FLAG)) ip += offset; break;
        case 0x8D: offset = (word)fetch_word(); if (!!(flags&N_FLAG) == !!(flags&V_FLAG)) ip += offset; break;

        // JLE, JNLE: ZF=1 OR (SF!=OF); ZF=0 AND (SF=OF)
        case 0x8E: offset = (word)fetch_word(); if ( (flags&Z_FLAG) ||  !!(flags&N_FLAG) != !!(flags&V_FLAG))  ip += offset; break;
        case 0x8F: offset = (word)fetch_word(); if (!(flags&Z_FLAG) && (!!(flags&N_FLAG) == !!(flags&V_FLAG))) ip += offset; break;

        // MOVZX r16, rm8/16
        case 0xB6: fetchea(); setr16(cpu_reg, geteab()); break;
        case 0xB7: fetchea(); setr16(cpu_reg, geteaw()); break;

        default:

            ud(7);
            break;
    }
}

// Дизассемблирование
int i386::readb(int address) {
    return ram[address & max_memory];
}

int i386::fetchb() {

    int a = readb(eip);
    eip = (eip + 1) & max_memory;
    return a;
}

int i386::fetchw() { int a = fetchb(); int b = fetchb(); return b*256 + a; }
int i386::fetchd() { int a = fetchw(); int b = fetchw(); return b*65536 + a; }

// Дизассемблирование modrm
int i386::disas_modrm(int reg32, int mem32) {

    int n = 0, b, w;

    /* Очистка */
    dis_rg[0] = 0;
    dis_rm[0] = 0;

    b = fetchb(); n++;

    rm  = (b & 0x07);
    reg = (b & 0x38) >> 3;
    mod = (b & 0xc0);

    /* Печать регистра 8/16/32 */
    switch (reg32) {
        case 0x08: sprintf(dis_rg, "%s", regnames[ reg ]); break;
        case 0x10: sprintf(dis_rg, "%s", regnames[ reg + 0x08 ]); break;
        case 0x20: sprintf(dis_rg, "%s", regnames[ reg + 0x10 ]); break;
        default:   sprintf(dis_rg, "<unknown>"); break;
    }

    // 16 бит
    if (mem32 == 0) {

        /* Rm-часть */
        switch (mod) {

            /* Индекс без disp или disp16 */
            case 0x00:

                if (rm == 6) {
                    w = fetchw(); n += 2;
                    sprintf(dis_rm, "[%s%04x]", dis_px, w);
                } else {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                }

                break;

            /* + disp8 */
            case 0x40:

                b = fetchb(); n++;
                if (b & 0x80) {
                    sprintf(dis_rm, "[%s%s-%02x]", dis_px, rm16names[ rm ], (0xff ^ b) + 1);
                } else if (b == 0) {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                } else {
                    sprintf(dis_rm, "[%s%s+%02x]", dis_px, rm16names[ rm ], b);
                }

                break;

            /* + disp16 */
            case 0x80:

                w = fetchw(); n += 2;
                if (w & 0x8000) {
                    sprintf(dis_rm, "[%s%s-%04x]", dis_px, rm16names[ rm ], (0xFFFF ^ w) + 1);
                } else if (w == 0) {
                    sprintf(dis_rm, "[%s%s]", dis_px, rm16names[ rm ]);
                } else {
                    sprintf(dis_rm, "[%s%s+%04x]", dis_px, rm16names[ rm ], w);
                }

                break;

            /* Регистровая часть */
            case 0xc0:

                switch (reg32) {
                    case 0x08: sprintf(dis_rm, "%s", regnames[ rm ]); break;
                    case 0x10: sprintf(dis_rm, "%s", regnames[ rm + 0x08 ]); break;
                    case 0x20: sprintf(dis_rm, "%s", regnames[ rm + 0x10 ]); break;
                }

                break;
        }
    }
    // 32 бит
    else {

        int sib = 0, sibhas = 0;

        switch (mod) {

            case 0x00:

                if (rm == 5) {

                    w = fetchd(); n += 4;
                    sprintf(dis_rm, "[%s%08x]", dis_px, w);

                } else if (rm == 4) { /* SIB */

                    sib = fetchb(); n++;
                    sibhas = 1;

                } else {
                    sprintf(dis_rm, "[%s%s]", dis_px, regnames[0x10 + rm]);
                }

                break;

            /* + disp8 */
            case 0x40:


                if (rm == 4) {

                    sib = fetchb(); n++;
                    sibhas = 1;

                } else {

                    b = fetchb(); n++;

                    if (b & 0x80) {
                        sprintf(dis_rm, "[%s%s-%02x]", dis_px, regnames[ 0x10 + rm ], (0xff ^ b) + 1);
                    } else if (b == 0) {
                        sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + rm ]);
                    } else {
                        sprintf(dis_rm, "[%s%s+%02x]", dis_px, regnames[ 0x10 + rm ], b);
                    }
                }

                break;

            /* + disp32 */
            case 0x80:


                if (rm == 4) {

                    sib = fetchb(); n++;
                    sibhas = 1;

                } else {

                    w = fetchd(); n += 4;

                    if (w & 0x80000000) {
                    sprintf(dis_rm, "[%s%s-%04x]", dis_px, regnames[ 0x10 + rm ], (0xFFFFFFFF ^ w) + 1);
                    } else if (w == 0) {
                        sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + rm ]);
                    } else {
                        sprintf(dis_rm, "[%s%s+%04x]", dis_px, regnames[ 0x10 + rm ], w);
                    }
                }

                break;

            // Регистровая часть
            case 0xc0:

                switch (reg32) {
                    case 0x08: sprintf(dis_rm, "%s", regnames[ rm ]); break;
                    case 0x10: sprintf(dis_rm, "%s", regnames[ rm + 0x08 ]); break;
                    case 0x20: sprintf(dis_rm, "%s", regnames[ rm + 0x10 ]); break;
                }

                break;
        }

        // Имеется байт SIB
        if (sibhas) {

            char cdisp32[16]; cdisp32[0] = 0;

            int disp = 0;
            int sib_ss = (sib & 0xc0);
            int sib_ix = (sib & 0x38) >> 3;
            int sib_bs = (sib & 0x07);

            /* Декодирование Displacement */
            switch (mod) {

                case 0x40:

                    disp = fetchb(); n += 1;

                    if (disp & 0x80) {
                        sprintf(cdisp32, "-%02X", (disp ^ 0xff) + 1);
                    } else {
                        sprintf(cdisp32, "+%02X", disp);
                    }

                    break;

               case 0x80:
               case 0xc0:

                    disp = fetchd(); n += 4;
                    if (disp & 0x80000000) {
                        sprintf(cdisp32, "-%08X", (disp ^ 0xffffffff) + 1);
                    } else {
                        sprintf(cdisp32, "+%08X", disp);
                    }
                    break;
            }

            /* Декодирование Index */
            if (sib_ix == 4) {

                sprintf(dis_rm, "[%s%s]", dis_px, regnames[ 0x10 + sib_bs ]);

            } else {

                switch (sib_ss) {

                    case 0x00:

                        sprintf(dis_rm, "[%s%s+%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ]);
                        break;

                    case 0x40:

                        sprintf(dis_rm, "[%s%s+2*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32);
                        break;

                    case 0x80:

                        sprintf(dis_rm, "[%s%s+4*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32);
                        break;

                    case 0xc0:

                        sprintf(dis_rm, "[%s%s+8*%s%s]", dis_px, regnames[ 0x10 + sib_bs ], regnames[ 0x10 + sib_ix ], cdisp32);
                        break;
                }
            }
        }
    }

    return n;
}

// Дизассемблировать строку
int i386::disassemble(int address) {

    eip = address & max_memory;

    int  ereg = 0;
    int  emem = 0;
    int  stop = 0;
    char dis_pf[8];
    char dis_cmd [32];
    char dis_cmd2[64];
    char dis_ops[256];
    char dis_dmp[128];
    char dis_sfx[8];

    int n = 0, i, j, d, opcode = 0;
    int elock = 0;

    // Очистить префикс
    dis_px[0]  = 0; // Сегментный префикс
    dis_pf[0]  = 0; // Префикс
    dis_ops[0] = 0; // Операнды
    dis_dmp[0] = 0; // Минидамп
    dis_sfx[0] = 0; // Суффикс

    /* Декодирование префиксов (до 6 штук) */
    for (i = 0; i < 6; i++) {

        d = fetchb();
        n++;

        switch (d) {
            case 0x0F: opcode |= 0x100; break;
            case 0x26: sprintf(dis_px, "%s", "es:"); break;
            case 0x2E: sprintf(dis_px, "%s", "cs:"); break;
            case 0x36: sprintf(dis_px, "%s", "ss:"); break;
            case 0x3E: sprintf(dis_px, "%s", "ss:"); break;
            case 0x64: sprintf(dis_px, "%s", "fs:"); break;
            case 0x65: sprintf(dis_px, "%s", "gs:"); break;
            case 0x66: ereg = ereg ^ 1; break;
            case 0x67: emem = emem ^ 1; break;
            case 0xf0: elock = 1; break;
            case 0xf2: sprintf(dis_pf, "%s", "repnz "); break;
            case 0xf3: sprintf(dis_pf, "%s", "rep "); break;
            default:   opcode |= d; stop = 1; break;
        }

        if (stop) break;
    }

    int opdec    = ops[ opcode & 255 ];
    int hasmodrm = modrm_lookup[ opcode ];

    // Типичная мнемоника
    if (opdec != 0xff) {
        sprintf(dis_cmd, "%s", mnemonics[ opdec ] );
    }

    // Байт имеет modrm
    if (hasmodrm) {

        // Размер по умолчанию 8 бит, если opcode[0] = 1, то либо 16, либо 32
        int regsize = opcode & 1 ? (ereg ? 32 : 16) : 8;
        int swmod   = opcode & 2; // Обмен местами dis_rm и dis_rg

        if (opcode == /* BOUND */ 0x62) regsize = (ereg ? 32 : 16);

        // SWmod
        if (opcode == /* ARPL */ 0x63) swmod = 0;
        if (opcode == /* LEA */ 0x8D || opcode == 0xC4 /* LES */ || opcode == 0xC5) swmod = 1;

        // Regsize
        if (opcode == /* SREG */ 0x8C || opcode == 0x8E ||
            opcode == /* LES */ 0xC4) regsize = (ereg ? 32 : 16);

        // Получить данные из modrm
        n += disas_modrm(regsize, emem ? 0x20 : 0x00);

        // GRP-1 8
        if (opcode == 0x80 || opcode == 0x82) {

            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }

        // GRP-1 16/32
        else if (opcode == 0x81) {

            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );

            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, fetchw()); n += 2;
            }
        }

        // GRP-1 16/32: Расширение 8 бит до 16/32
        else if (opcode == 0x83) {

            int b8 = fetchb(); n++;
            sprintf(dis_cmd, "%s", mnemonics[ reg ]  );

            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, b8 | (b8 & 0x80 ? 0xFFFFFF00 : 0));
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, b8 | (b8 & 0x80 ? 0xFF00 : 0));
            }
        }

        // IMUL imm16
        else if (opcode == 0x69) {

            if (ereg) {
                sprintf(dis_ops, "%s, %s, %08X", dis_rg, dis_rm, fetchd() ); n += 4;
            } else {
                sprintf(dis_ops, "%s, %s, %04X", dis_rg, dis_rm, fetchw() ); n += 2;
            }
        }
        // Групповые инструкции #2: Byte
        else if (opcode == 0xF6) {

            sprintf(dis_cmd, "%s", grp2[ reg ]  );
            if (reg < 2) { /* TEST */
                sprintf(dis_ops, "%s, %02X", dis_rm, fetchb() ); n++;
            } else {
                sprintf(dis_ops, "%s", dis_rm);
            }
        }

        // Групповые инструкции #2: Word/Dword
        else if (opcode == 0xF7) {

            sprintf(dis_cmd, "%s", grp2[ reg ]  );

            if (reg < 2) { /* TEST */
                if (ereg) {
                    sprintf(dis_ops, "%s, %08X", dis_rm, fetchd() ); n += 4;
                } else {
                    sprintf(dis_ops, "%s, %04X", dis_rm, fetchw() ); n += 2;
                }
            } else {
                sprintf(dis_ops, "%s", dis_rm);
            }
        }

        // Групповые инструкции #3: Byte
        else if (opcode == 0xFE) {

            if (reg < 2) {
                sprintf(dis_cmd, "%s", grp3[ reg ]  );
                sprintf(dis_ops, "byte %s", dis_rm );
            } else {
                sprintf(dis_cmd, "(unk)");
            }
        }
        // Групповые инструкции #3: Word / Dword
        else if (opcode == 0xFF) {

            sprintf(dis_cmd, "%s", grp3[ reg ]  );
            sprintf(dis_ops, "%s %s", ereg ? "dword" : "word", dis_rm );

        }

        // Сегментные и POP r/m
        else if (opcode == 0x8C) { sprintf(dis_ops, "%s, %s", dis_rm, regnames[ 0x18 + reg ] ); }
        else if (opcode == 0x8E) { sprintf(dis_ops, "%s, %s", regnames[ 0x18 + reg ], dis_rm ); }
        else if (opcode == 0x8F) { sprintf(dis_ops, "%s %s", ereg ? "dword" : "word", dis_rm ); }

        // GRP-2: imm
        else if (opcode == 0xC0 || opcode == 0xC1) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }
        // 1
        else if (opcode == 0xD0 || opcode == 0xD1) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, 1", dis_rm);
        }
        // cl
        else if (opcode == 0xD2 || opcode == 0xD3) {
            sprintf(dis_cmd, "%s", mnemonics[ 0x66 + reg ]);
            sprintf(dis_ops, "%s, cl", dis_rm);
        }
        // mov r/m, i8/16/32
        else if (opcode == 0xC6) {
            sprintf(dis_ops, "%s, %02X", dis_rm, fetchb()); n++;
        }
        else if (opcode == 0xC7) {
            if (ereg) {
                sprintf(dis_ops, "%s, %08X", dis_rm, fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04X", dis_rm, fetchw()); n += 2;
            }
        }
        // Обычные
        else {
            sprintf(dis_ops, "%s, %s", swmod ? dis_rg : dis_rm, swmod ? dis_rm : dis_rg);
        }

    } else {

        // [00xx_x10x] АЛУ AL/AX/EAX, i8/16/32
        if ((opcode & 0b11000110) == 0b00000100) {

            if ((opcode & 1) == 0) { // 8 bit
                sprintf(dis_ops, "al, %02X", fetchb()); n++;
            } else if (ereg == 0) { // 16 bit
                sprintf(dis_ops, "ax, %04X", fetchw()); n += 2;
            } else {
                sprintf(dis_ops, "eax, %08X", fetchd()); n += 4;
            }
        }

        // [000x x11x] PUSH/POP
        else if ((opcode & 0b11100110) == 0b00000110) {
            sprintf(dis_ops, "%s", regnames[0x18 + ((opcode >> 3) & 3)] );
        }

        // [0100_xxxx] INC/DEC/PUSH/POP
        else if ((opcode & 0b11100000) == 0b01000000) {
            sprintf(dis_ops, "%s", regnames[ (ereg ? 0x10 : 0x08) + (opcode & 7)] );
        }
        else if (opcode == 0x60 && ereg) { sprintf(dis_cmd, "pushad"); }
        else if (opcode == 0x61 && ereg) { sprintf(dis_cmd, "popad"); }

        // PUSH imm16/32
        else if (opcode == 0x68) {

            if (ereg) {
                sprintf(dis_ops, "%08X", fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%04X", fetchw()); n += 2;
            }
        }
        // PUSH imm8
        else if (opcode == 0x6A) { int t = fetchb(); sprintf(dis_ops, "%04X", t | ((t & 0x80) ? 0xFF00 : 0)); n++; }
        // Jccc rel8
        else if (((opcode & 0b11110000) == 0b01110000) || (opcode >= 0xE0 && opcode <= 0xE3) || (opcode == 0xEB)) {
            int br = fetchb(); n++;
            sprintf(dis_ops, "%08X", (br & 0x80 ? (eip + br - 256) : eip + br ));
        }
        else if (opcode == 0x6c) sprintf(dis_cmd, "insb");
        else if (opcode == 0x6d) sprintf(dis_cmd, ereg ? "insd" : "insw");
        else if (opcode == 0x6e) sprintf(dis_cmd, "outsb");
        else if (opcode == 0x6f) sprintf(dis_cmd, ereg ? "outsd" : "outsw");
        // XCHG ax, r16/32
        else if (opcode > 0x90 && opcode <= 0x97) {
            if (ereg) {
                sprintf(dis_ops, "eax, %s", regnames[ 0x10 + (opcode & 7) ] );
            } else {
                sprintf(dis_ops, "ax, %s", regnames[ 0x8 + (opcode & 7) ] );
            }
        }
        else if (opcode == 0x98 && ereg) sprintf(dis_cmd, "cwde");
        else if (opcode == 0x99 && ereg) sprintf(dis_cmd, "cdq");

        // CALLF/JMPF
        else if (opcode == 0x9A || opcode == 0xEA) {

            int dw = ereg ? fetchd() : fetchw();
            n += (ereg ? 4 : 2);

            int sg = fetchw();
            n += 2;

            if (ereg) sprintf(dis_ops, "%04X:%08X", sg, dw);
                else  sprintf(dis_ops, "%04X:%04X", sg, dw);
        }
        // MOV
        else if (opcode == 0xA0) { sprintf(dis_ops, "al, [%04X]", fetchw()); n += 2; }
        else if (opcode == 0xA1) { sprintf(dis_ops, "ax, [%04X]", fetchw()); n += 2; }
        else if (opcode == 0xA2) { sprintf(dis_ops, "[%04X], al", fetchw()); n += 2; }
        else if (opcode == 0xA3) { sprintf(dis_ops, "[%04X], ax", fetchw()); n += 2; }
        else if (opcode == 0xA8) { sprintf(dis_ops, "al, %02X", fetchb()); n++; }
        // TEST
        else if (opcode == 0xA9) {
            if (ereg) {
                sprintf(dis_ops, "eax, %08X", fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "ax, %04X", fetchw()); n += 2;
            }
        }
        else if ((opcode >= 0xA4 && opcode <= 0xA7) || (opcode >= 0xAA && opcode <= 0xAF)) {
            sprintf(dis_sfx, opcode&1 ? (ereg ? "d" : "w") : "b");
        }
        else if (opcode >= 0xB0 && opcode <= 0xB7) {
            sprintf(dis_ops, "%s, %02x", regnames[ opcode & 7 ], fetchb()); n++;
        }
        else if (opcode >= 0xB8 && opcode <= 0xBF) {
            if (ereg) {
                sprintf(dis_ops, "%s, %08x", regnames[ 0x10 + (opcode & 7) ], fetchd()); n += 4;
            } else {
                sprintf(dis_ops, "%s, %04x", regnames[ 0x08 + (opcode & 7) ], fetchw()); n += 2;
            }
        }
        // RET / RETF
        else if (opcode == 0xc2 || opcode == 0xca) {
            sprintf(dis_ops, "%04X", fetchw()); n += 2;
        }
        // ENTER
        else if (opcode == 0xC8) {

            int aa = fetchw();
            int ab = fetchb();
            sprintf(dis_ops, "%04x, %02X", aa, ab); n += 3;
        }
        // INT
        else if (opcode == 0xCD) { sprintf(dis_ops, "%02X", fetchb()); n++; }
        // IO/OUT
        else if (opcode == 0xE4) { sprintf(dis_ops, "al, %02X", fetchb()); n++; }
        else if (opcode == 0xE5) { sprintf(dis_ops, "%s, %02X", ereg ? "eax" : "ax", fetchb()); n++; }
        else if (opcode == 0xE6) { sprintf(dis_ops, "%02X, al", fetchb()); n++; }
        else if (opcode == 0xE7) { sprintf(dis_ops, "%02X, %s", fetchb(), ereg ? "eax" : "ax"); n++; }
        else if (opcode == 0xEC) { sprintf(dis_ops, "al, dx"); }
        else if (opcode == 0xED) { sprintf(dis_ops, "%s, dx", ereg ? "eax" : "ax"); }
        else if (opcode == 0xEE) { sprintf(dis_ops, "dx, al"); }
        else if (opcode == 0xEF) { sprintf(dis_ops, "dx, %s", ereg ? "eax" : "ax"); }
        // CALL / JMP rel16
        else if (opcode == 0xE8 || opcode == 0xE9) {
            if (ereg) {

                int m = fetchd(); n += 4;
                    m = (m & 0x80000000) ? m - 0x100000000 : m;
                sprintf(dis_ops, "%08X", m);

            } else {
                int m = fetchw(); n += 2;
                    m = (m & 0x8000) ? m - 0x10000 : m;
                sprintf(dis_ops, "%04X", m + (eip & 0xffff));
            }
        }
    }

    // Максимальное кол-во байт должно быть не более 6
    for (i = 0; i < 6; i++) {
        if (i == 5 && n > 5) {
            sprintf(dis_dmp + 2*i, "..");
        } else if (i < n) {
            sprintf(dis_dmp + 2*i, "%02X", readb(address + i));
        } else {
            sprintf(dis_dmp + 2*i, "  ");
        }
    }

    // Суффикс команды
    sprintf(dis_cmd2, "%s%s", dis_cmd, dis_sfx);

    // Дополнить пробелами мнемонику
    for (i = 0; i < 8; i++) {
        if (dis_cmd2[i] == 0) {
            for (j = i; j < 8; j++) {
                dis_cmd2[j] = ' ';
            }
            dis_cmd2[8 - 1] = 0;
            break;
        }
    }

    // Формирование строки вывода
    // Дамп инструкции, команда, операнды
    sprintf(dis_row, "%s %s%s%s %s", dis_dmp, elock ? "lock " : "", dis_pf, dis_cmd2, dis_ops);
    return n;
}

