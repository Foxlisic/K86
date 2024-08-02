class CPU {

public:

    unsigned    char*   m;          // Указатель на память 1 Мб
    struct      Tregs   r;          // Регистры
    struct      Tflags  f;          // Флаги
    unsigned    int     ip;         // Указатель инструкции
    unsigned    int     start_ip;   // Для инструкции с REP:

    // Текущее состояние процессора
    int     cpu_halt;   // Процессор остановлен
    int     opcode;     // Прочитанный и разобранный опкод
    int     rep;        // Префикс REP = {0=None, 1=REPNZ, 2=REPZ}
    int     segment;    // Сегментный префикс: {-1=None, 0=ES, 1=CS, 2=SS, 3=DS, FS, GS}
    int     sizeo;      // =1 Расширение операнда
    int     sizea;      // =1 Расширение адреса
    int     lock;       // Блокировка шины
    int     mode;       // Режим АЛУ

    byte    mrm;        // Байт ModRM
    byte    mrm_mod;    // mod-часть 0..3
    byte    mrm_reg;    // reg-часть 0..7
    byte    mrm_rm;     // rm-часть  0..7

    uint    seg, ea;        // Эффективный адрес SEG:EA
    ulong   op1, op2, res;  // Опкод 1, 2 и результат

    // Взаимодействие с внешним устройством
    DisplaySDL* display;
    Machine*    machine;
    BIOS*       bios;

    // Количество пройденных состояний
    uint        tstates;
    int         dump_addr;

public:

    CPU() {

        r.ax = 0x00fe; r.sp = 0x0000; r.es = 0xb800;
        r.cx = 0x0000; r.bp = 0x0000; r.cs = 0x0000;
        r.dx = 0x0000; r.si = 0x0010; r.ss = 0x0000;
        r.bx = 0x0002; r.di = 0x0004; r.ds = 0xb800;

        f.o = 0; f.s = 0;
        f.d = 0; f.z = 1;
        f.i = 0; f.a = 0;
        f.t = 0; f.p = 0; f.c = 0;

        cpu_halt = 0;
        tstates  = 0;

        ip = 0x0000;
    }

    uint get_tstates() { return tstates; }
    void reset_tstates() { tstates = 0; }
    void set_memory(unsigned char* m_) { m = m_; }
    void set_machine(Machine* tm) { machine = tm; }
    void regs() { // Показать регистры

        printf("\n");
        printf("ax=%04x  bx=%04x  cx=%04x  dx=%04x\n", r.ax, r.bx, r.cx, r.dx);
        printf("sp=%04x  bp=%04x  si=%04x  di=%04x\n", r.sp, r.bp, r.si, r.di);
        printf("cs=%04x  es=%04x  ss=%04x  ds=%04x\n", r.cs, r.es, r.ss, r.ds);
        printf("ip=%04x  ", ip);

        printf("%s", f.o ? "O" : " ");
        printf("%s", f.d ? "D" : " ");
        printf("%s", f.i ? "I" : " ");
        printf("%s", f.t ? "T" : " ");
        printf("%s", f.s ? "S" : " ");
        printf("%s", f.z ? "Z" : " ");
        printf("%s", f.a ? "A" : " ");
        printf("%s", f.p ? "P" : " ");
        printf("%s", f.c ? "C" : " ");

        printf("\n\n");
    }
    void dump(int addr) { // Выдать дамп на экран

        int i, j;

        // \e[92m .. \e[39m
        printf("       +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

        for (i = 0; i < 4; i++) {
            printf("%05x: ", addr + i*16);
            for (j = 0; j < 16; j++) {
                printf("%02x ", m[addr + i*16 + j]);
            }
            printf("\n");
        }

    }
    void set_cs_ip(int cs, int ip_) { // Принудительно установить CS:IP

        r.cs = cs;
        ip   = ip;
    }

    void set_display(DisplaySDL* disp) { // Указатель на дисплей для вызова функции
        display = disp;
    }
    void set_bios(BIOS* bios_) { // Установка биоса
        bios = bios_;
    }
    void set_dump(int dump_) {
        dump_addr = dump_;
    }

    // Читать из памяти seg:offset
    byte read(int segment, int offset) {
        return m[ segment*16 + offset ];
    }
    word read16(int segment, int offset) {
        return read(segment, offset) + (read(segment, offset + 1) << 8);
    }
    void write(int segment, int offset, uint value) {

        int addr = segment*16 + offset;
        m[ addr ] = value & 0xff;

        display->write(addr);
    }
    void write16(int segment, int offset, uint value) {
        write(segment, offset,   value);
        write(segment, offset+1, value >> 8);
    }

    byte fetch() { // Прочитать следующий байт cs:ip

        byte x = read(r.cs, ip);
        ip = (ip + 1) & 0xffff;
        return x;
    }
    word fetch_word() { // Чтение 2-х байт

        byte l = fetch();
        byte h = fetch();
        return (h<<8) + l;
    }
    int fetch_signed() { // Прочитать знаковый байт

        byte x = fetch();
        return x < 128 ? x : (x - 256);
    }
    void fetch_opcode() { // Прочитать опкод, разобрать префиксы

        rep = 0;
        segment = -1;
        opcode = 0;
        sizeo = 0;
        sizea = 0;
        lock = 0;
        start_ip = ip;

        int end = 0, num = 0;

        do {

            byte nextb = fetch();          // Читать опкод или префикс

            // Проверка на префиксы
            switch (nextb) {

                case 0x0F: opcode = 0x100; break;       // Расширенный опкод
                case 0x26: segment = r.es; break;            // Префикс ES
                case 0x2E: segment = r.cs; break;
                case 0x36: segment = r.ss; break;
                case 0x3E: segment = r.fs; break;
                case 0x64: segment = r.fs; break;
                case 0x65: segment = r.gs; break;
                case 0x66: sizeo = 1; break;
                case 0x67: sizea = 1; break;
                case 0xF0: lock = 1; break;
                case 0xF2: rep = REPNZ; break;
                case 0xF3: rep = REPZ;  break;

                // Завершить чтение опкода
                default: opcode |= nextb; end = 1; break;
            }

            num++;

        } while (end == 0 && num < 16);

        // Буфер чтения переполнился
        if (num == 16) { printf("Error reading instruction"); exit(1); }
    }
    void fetch_modrm_16() { // Считать и разобрать байт modrm

        mrm = fetch();

        mrm_mod = (mrm & 0xC0) >> 6;
        mrm_reg = (mrm & 0x38) >> 3;
        mrm_rm  = (mrm & 0x07);

        // Сегмент по умолчанию
        seg = r.ds;

        // Эффективный адрес для всех
        switch (mrm_rm) {

            case 0: ea = (r.bx + r.si) & 0xffff; break;
            case 1: ea = (r.bx + r.di) & 0xffff; break;
            case 2: ea = (r.bp + r.si) & 0xffff; seg = r.ss; break;
            case 3: ea = (r.bp + r.di) & 0xffff; seg = r.ss; break;
            case 4: ea = r.si; break;
            case 5: ea = r.di; break;
            case 6: ea = 0;    break;
            case 7: ea = r.bx; break;
        }

        switch (mrm_mod) {

            // Адрес без displacement
            case 0:

                if (mrm_rm == 6) {
                    ea = get_Iv();
                }
                break;

            // +disp8
            case 1:

                if (mrm_rm == 6) { seg = r.ss; ea = r.bp; }
                ea = (ea + fetch_signed()) & 0xffff;
                break;

            // +disp16
            case 2:

                if (mrm_rm == 6) { seg = r.ss; ea = r.bp; }
                ea = (ea + get_Iv()) & 0xffff;
                break;

            // Это регистр
            case 3: ea = 0; break;
        }

        // Задан сегментный префикс
        if (segment >= 0) seg = segment;
    }

    uint get_reg(int id, int bit) { // Извлечь значение регистра

        if (bit == 8) {

            switch (id) {

                case 0: return  r.ax & 0xff;
                case 1: return  r.cx & 0xff;
                case 2: return  r.dx & 0xff;
                case 3: return  r.bx & 0xff;
                case 4: return (r.ax >> 8) & 0xff;
                case 5: return (r.cx >> 8) & 0xff;
                case 6: return (r.dx >> 8) & 0xff;
                case 7: return (r.bx >> 8) & 0xff;
                // Ошибка
                default: printf("Unexpected reg %d, 8bit\n", id); exit(2);
            }
        }
        else if (bit == 16) {

            switch (id) {

                case 0: return r.ax;
                case 1: return r.cx;
                case 2: return r.dx;
                case 3: return r.bx;
                case 4: return r.sp;
                case 5: return r.bp;
                case 6: return r.si;
                case 7: return r.di;
                // Ошибка
                default: printf("Unexpected reg %d, 16bit\n", id); exit(2);
            }
        }

        return 0;
    }
    void put_reg(int id, int bit, int value) { // Сохранить в регистр

        if (bit == 8) {

            value &= 0xff;

            switch (id) {

                case 0: r.ax = (r.ax & 0xff00) | (value); break;
                case 1: r.cx = (r.cx & 0xff00) | (value); break;
                case 2: r.dx = (r.dx & 0xff00) | (value); break;
                case 3: r.bx = (r.bx & 0xff00) | (value); break;
                case 4: r.ax = (r.ax & 0x00ff) | (value << 8); break;
                case 5: r.cx = (r.cx & 0x00ff) | (value << 8); break;
                case 6: r.dx = (r.dx & 0x00ff) | (value << 8); break;
                case 7: r.bx = (r.bx & 0x00ff) | (value << 8); break;
            }
        }
        else if (bit == 16) {

            value &= 0xffff;

            switch (id) {

                case 0: r.ax = value; break;
                case 1: r.cx = value; break;
                case 2: r.dx = value; break;
                case 3: r.bx = value; break;
                case 4: r.sp = value; break;
                case 5: r.bp = value; break;
                case 6: r.si = value; break;
                case 7: r.di = value; break;
            }
        }
    }

    uint get_al() {
        return r.ax & 0xff;
    }
    uint get_ax() {
        return r.ax;
    }
    void put_al(uint v) {
        r.ax = (r.ax & 0xff00) | (v & 0xff);
    }
    void put_ax(uint v) {
        r.ax = v & 0xffff;
    }

    // Извлечение и запись операндов modrm
    uint get_Eb() { // rm8

        if (mrm_mod == 3)
             return get_reg(mrm_rm, 8); // Чтение из 8-битного регистра
        else return read(seg, ea);
    }
    uint get_Ev() { // rm16
        if (mrm_mod == 3)
             return get_reg(mrm_rm, 16); // Чтение из 16-битного регистра
        else return read16(seg, ea);
    }
    uint get_Gb() { // reg8
        return get_reg(mrm_reg, 8);
    }
    uint get_Gv() { // reg16
        return get_reg(mrm_reg, 16);
    }
    byte get_Ib() { // [cs:ip++]
        return fetch();
    }
    word get_Iv() { // [cs:ip+2]
        return fetch_word();
    }
    word get_Ie() { // [cs:ip++] signextend
        int w = fetch();
        return (w & 0x80 ? w | 0xFF00 : w);
    }

    void put_Eb(uint v) { // rm8

        if (mrm_mod == 3)
             put_reg(mrm_rm, 8, v);
        else write(seg, ea, v);
    }
    void put_Ev(uint v) { // rm16

        if (mrm_mod == 3)
             put_reg(mrm_rm, 16, v);
        else write16(seg, ea, v);
    }
    void put_Gb(uint v) { // reg8
        put_reg(mrm_reg, 8, v);
    }
    void put_Gv(uint v) { // reg16
        put_reg(mrm_reg, 16, v);
    }

    // РАЗЛИЧНЫЕ ОПЕРАЦИИ
    void put_SS(int id, uint data) { // Запись в сегментный регистр 16-битной data

        switch (id) {

            case 0: r.es = data; break;
            case 1: /* UNDEFINED INSTRUCTION EXCEPTION */ break;
            case 2: r.ss = data; break;
            case 3: r.ds = data; break;
            case 4: r.fs = data; break;
            case 5: r.gs = data; break;
        }
    }
    uint get_SS(int id) { // Чтение из сегментного регистра

        switch (id) {

            case 0: return r.es;
            case 1: return r.cs;
            case 2: return r.ss;
            case 3: return r.ds;
            case 4: return r.fs;
            case 5: return r.gs;
        }

        return 0;
    }

    void push(uint data) { // Запись в стек

        r.sp = (r.sp - 2) & 0xffff;
        write16(r.ss, r.sp, data);
    }
    uint pop() { // Извлечь из стека

        uint data = read16(r.ss, r.sp);
        r.sp = (r.sp + 2) & 0xffff;
        return data;
    }

    // Проверка условного перехода
    int test_condition(int mode) {

        switch (mode & 0xF) {

            case 0:  return  f.o; // JO
            case 1:  return !f.o; // JNO
            case 2:  return  f.c; // JC
            case 3:  return !f.c; // JNC
            case 4:  return  f.z; // JZ
            case 5:  return !f.z; // JNZ
            case 6:  return  f.c ||  f.z; // JBE
            case 7:  return !f.c && !f.z; // JNBE
            case 8:  return  f.s; // JS
            case 9:  return !f.s; // JNS
            case 10: return  f.p; // JP
            case 11: return !f.p; // JNP
            case 12: return  f.s != f.o;         // JL
            case 13: return  f.s == f.o;         // JNL
            case 14: return  f.s != f.o ||  f.z; // JLE
            case 15: return  f.s == f.o && !f.z; // JNLE
        }

        return 0;
    }

    // ---------------- ИСПОЛНИТЕЛИ -------------------

    // Сложение op1 + op2 + carry, bit = 8/16
    uint ADC(uint op1, uint op2, int bit, int carry) {

        ALUBITMASK;

        uint res  = op1 + op2 + carry;
        uint dst  = res & mask;
        uint over = ((dst ^ op1) & (op1 ^ op2 ^ sign) & sign) & sign;

        SET_CARRY   (res > mask);           // Произошло переполнение
        SET_PARITY  (dst);                  // Установка флага четности
        SET_AUX     ((op1^op2^dst)&0x10);   // Установка половинного переполнения
        SET_ZERO    (dst);                  // Флаг нуля
        SET_SIGN    (dst & sign);           // Знак в 0x80 или в 0x8000
        SET_OVER    (over);                 // Переполнение знака

        return dst;
    }

    // Вычитание op1 - op2 - carry
    uint SBB(uint op1, uint op2, int bit, int carry) {

        ALUBITMASK;

        int sub  =  op1 - op2 - carry;
        int dst  = (sub & mask);

        SET_OVER   ((dst ^ op1) & (op1 ^ op2) & sign);
        SET_SIGN   (dst & sign);
        SET_ZERO   (dst);
        SET_AUX    ((op1 ^ op2 ^ dst) & 0x10);
        SET_PARITY (dst);
        SET_CARRY  (sub < 0);

        return dst;
    }

    // Логическое ИЛИ
    uint OR(uint op1, uint op2, int bit) {

        ALUBITMASK;

        uint dst = (op1 | op2) & mask;

        SET_CARRY   (0);
        SET_PARITY  (dst);
        SET_ZERO    (dst);
        SET_SIGN    (dst & sign);
        SET_OVER    (0);

        return dst;
    }

    // Логическое И
    uint AND(uint op1, uint op2, int bit) {

        ALUBITMASK;

        uint dst = (op1 & op2) & mask;

        SET_CARRY   (0);
        SET_PARITY  (dst);
        SET_ZERO    (dst);
        SET_SIGN    (dst & sign);
        SET_OVER    (0);

        return dst;
    }

    // Исключающее ИЛИ
    uint XOR(uint op1, uint op2, int bit) {

        ALUBITMASK;

        uint dst = (op1 ^ op2) & mask;

        SET_CARRY   (0);
        SET_PARITY  (dst);
        SET_ZERO    (dst);
        SET_SIGN    (dst & sign);
        SET_OVER    (0);

        return dst;
    }

    // ----------------------------

    // Циклический сдвиг влево `s`
    uint ROL(uint s, uint cnt, int bit) {

        ALUBITMASK;
        uint cf = 0, i;

        f.c = 0;
        f.o = 0;

        for (i = 1; i <= (cnt & 0x1F); i++) {

            cf = (s & sign) ? 1 : 0;
            s  = ((s << 1) | cf) & mask;
        }

        SET_OVER  ((cnt == 1) && (s & sign) && cf);
        SET_CARRY (cf);

        return s & mask;
    }

    // Циклический сдвиг вправо `s`
    uint ROR(uint s, uint cnt, int bit) {

        uint mask = ((1 << bit) - 1);
        uint i, cf = 0;

        s &= mask;
        for (i = 1; i <= (cnt & 0x1F); i++) {

            cf = s & 1;
            s  = ((s >> 1) | (cf << (bit-1))) & mask;
        }

        if (cnt == 1) {
            SET_OVER( (s >> (bit-1)) ^ ((s >> (bit-2)) & 1) );
        }

        SET_CARRY(cf);
        return s & mask;
    }

    // Сдвиг влево с заемом из CF
    uint RCL(uint s, uint cnt, int bit) {

        ALUBITMASK;
        uint oldcf, cf = f.c, i;

        for (i = 1; i <= (cnt & 0x1F); i++) {

            oldcf = cf;
            cf = (s & sign) ? 1 : 0;
            s  = ((s << 1) | oldcf) & mask;
        }

        if (cnt == 1) {
            SET_OVER( cf ^ ((s >> (bit-1)) & 1) );
        }

        SET_CARRY(cf);
        return s & mask;
    }

    // Сдвиг вправо с заемом из CF
    uint RCR(uint s, uint cnt, int bit) {

        uint mask = ((1 << bit) - 1);
        uint oldcf, cf = f.c, i;

        s &= mask;
        for (i = 1; i <= (cnt & 0x1F); i++) {

            oldcf = cf;
            cf = (s & 1);
            s  = ((s >> 1) | (oldcf << (bit-1))) & mask;
        }

        if (cnt == 1) {
            SET_OVER( (s >> (bit-1)) ^ ( (s >> (bit-2)) & 1) );
        }

        SET_CARRY(cf);
        return s & mask;
    }

    // Логический сдвиг влево
    uint SHL(uint s, uint cnt, int bit) {

        ALUBITMASK;
        uint cf = 0, i;

        for (i = 1; i <= cnt; i++) {

            cf = (s & sign) ? 1 : 0;
            s  = (s << 1) & mask;
        }

        SET_OVER   ( (cnt == 1) && (cf == (s >> (bit-1)) ) );
        SET_SIGN   ( s & sign );
        SET_ZERO   ( s );
        SET_PARITY ( s );
        SET_CARRY  ( cf );

        return s;
    }

    // Логический сдвиг вправо
    uint SHR(uint s, uint cnt, int bit) {

        ALUBITMASK;
        uint cf = 0, i;

        SET_OVER( (cnt == 1) && (s & sign) );
        for (i = 1; i <= cnt; i++) {

            cf = s & 1;
            s  = (s >> 1) & mask;
        }

        SET_SIGN   ( s & sign );
        SET_ZERO   ( s );
        SET_PARITY ( s );
        SET_CARRY  ( cf );

        return s;
    }

    // Логический сдвиг влево
    uint SAR(uint s, uint cnt, int bit) {

        ALUBITMASK;
        uint cf = 0, i, msb;

        s &= mask;
        for (i = 1; i <= cnt; i++) {

            msb = s & sign;
            cf  = s & 1;
            s   = ((s >> 1) | msb) & mask;
        }

        SET_OVER   ( 0 );
        SET_SIGN   ( s & sign );
        SET_ZERO   ( s );
        SET_PARITY ( s );
        SET_CARRY  ( cf );

        return s;
    }

    // Десятичная корректировка после сложения
    void DAA_op() {

        uint tmp;

        /* Раунд 1: Нижний ниббл */
        if (((r.ax & 0x0F) > 9) || f.a) {
            tmp = get_al() + 6;
            put_al   (tmp);
            SET_CARRY(tmp & 0xFF00);
            SET_AUX  (1);
        }

        /* Раунд 2: Верхний ниббл */
        if (((r.ax & 0xFF) > 0x9F) || f.c) {
            put_al    (get_al() + 0x60);
            SET_CARRY (1);
        }

        /* Установка флагов */
        tmp = get_al();
        SET_SIGN   (tmp & 0x80);
        SET_ZERO   (tmp);
        SET_PARITY (tmp);
    }

    // Десятичная корректировка после сложения
    void DAS_op() {

        uint tmp;

        /* Раунд 1: Нижний ниббл */
        if (((r.ax & 0x0F) > 9) || f.a) {
            tmp = get_al() - 6;
            put_al   (tmp);
            SET_CARRY(tmp & 0xFF00);
            SET_AUX  (1);
        } else {
            SET_AUX  (0);
        }

        /* Раунд 2: Верхний ниббл */
        if (((r.ax & 0xF0) > 0x90) || f.c) {
            put_al    (get_al() - 0x60);
            SET_CARRY (1);
        } else {
            SET_CARRY (0);
        }

        /* Установка флагов */
        tmp = get_al();
        SET_SIGN   (tmp & 0x80);
        SET_ZERO   (tmp);
        SET_PARITY (tmp);
    }

    // ASCII корректировка после сложения
    void AAA_op() {

        if (((r.ax & 0xF) > 9) || f.a) {

            put_reg  (REG_AL, 8, get_reg(REG_AL, 8) + 6);
            put_reg  (REG_AH, 8, get_reg(REG_AH, 8) + 1);
            SET_CARRY(1);
            SET_AUX  (1);

        } else {

            SET_CARRY(0);
            SET_AUX  (0);
        }

        r.ax &= 0xFF0F;
    }

    // ASCII корректировка после вычитания
    void AAS_op() {

        if (((r.ax & 0xF) > 9) || f.a) {

            put_reg  (REG_AL, 8, get_reg(REG_AL, 8) - 6);
            put_reg  (REG_AH, 8, get_reg(REG_AH, 8) - 1);
            SET_CARRY(1);
            SET_AUX  (1);

        } else {

            SET_CARRY(0);
            SET_AUX  (0);
        }

        r.ax &= 0xFF0F;
    }

    // Иначе не работает
    ulong get_wide(int bit) {

        switch (bit) {

            case 8:  return 0xffff;
            case 16: return 0xffffffff;
        }

        return 0xffffffff;
    }

    // Инкремент
    uint INC(int op, int bit) {

        uint cf  = f.c;
        uint res = ADC(op, 0, bit, 1);
        f.c = cf;
        return res;
    }

    // Декремент
    uint DEC(int op, int bit) {

        uint cf  = f.c;
        uint res = SBB(op, 0, bit, 1);
        f.c = cf;
        return res;
    }

    // Беззнаковое умножение
    uint MUL(uint op1, uint op2, int bit) {

        ALUBITMASK;

        ulong wide = get_wide(bit);

        // Умножение 8 или 16 бит
        ulong tmp = (op1 & mask) * (op2 & mask);

        // Ограничить результат умножения
        res = tmp & wide;

        // Установка стандартных флагов
        SET_SIGN   ( res & sign );
        SET_ZERO   ( res & mask );
        SET_PARITY ( res );

        if (r.ax & ~mask) {
            SET_CARRY(1);
            SET_OVER (1);
        } else {
            SET_CARRY(0);
            SET_OVER (0);
        }

        return res;
    }

    // Знаковое умножение
    uint IMUL(uint op1, uint op2, int bit) {

        ALUBITMASK;
        ulong wide = get_wide(bit), res;

        op1 &= mask;
        op2 &= mask;

        if (op1 & sign) op1 |= ~mask;
        if (op2 & sign) op2 |= ~mask;

        res = (op1 * op2) & wide;

        if (res & ~mask) {
            SET_OVER  (1);
            SET_CARRY (1);
        } else {
            SET_OVER  (0);
            SET_CARRY (0);
        }

        return res;
    }

    // Беззнаковое деление
    void DIV(uint op1, uint op2, int bit) {

        uint mask = (1 << bit) - 1, res = op1 / op2;

        if (op2 == 0) { interrupt86(0); return; }
        if (res > mask) { interrupt86(0); return; }

        if (bit == 8) {

            put_reg (REG_AL, 8, res);
            put_reg (REG_AH, 8, op1 % op2);

        } else {

            r.ax = (res) & 0xffff;
            r.dx = (op1 % op2) & 0xffff;
        }
    }

    // Знаковое деление
    void IDIV(uint op1, uint op2, int bit) {

        uint d1, d2, s1, s2, sign;

        if (op2 == 0) { interrupt86(0); return; }

        uint sig1 = (1 << (1*bit-1));
        uint sig2 = (1 << (2*bit-1));
        uint mask = (1 <<  1*bit) - 1;
        uint mas2 = get_wide(bit);
        uint hi   = ~mask;

        s1 = op1;
        s2 = op2;

        if (bit == 16) {
            s2  = (s2 & sig1) ? (s2 | hi) : s2;
        }

        sign = (((s1 ^ s2) & sig2) != 0);
        s1   = (s1 < sig2) ? s1 : ((~s1 + 1) & mas2);
        s2   = (s2 < sig2) ? s2 : ((~s2 + 1) & mas2);
        d1   = s1 / s2;
        d2   = s1 % s2;

        if (d1 & hi) { interrupt86(0); return; }

        if (sign) {
            d1 = (~d1 + 1) & mask;
            d2 = (~d2 + 1) & mask;
        }

        if (bit == 16) {
            r.ax = d1;
            r.dx = d2;
        } else {
            r.ax = (d1 & mask) + (d2 & mask)*256;
        }
    }

    // Выполнить инструкции АЛУ
    uint alu_grp(int id, uint op1, uint op2, int bit) {

        switch (id) {

            /* ADD */ case 0: return ADC(op1, op2, bit, 0);
            /* OR  */ case 1: return OR (op1, op2, bit);
            /* ADC */ case 2: return ADC(op1, op2, bit, f.c);
            /* SBB */ case 3: return SBB(op1, op2, bit, f.c);
            /* AND */ case 4: return AND(op1, op2, bit);
            /* SUB */ case 5: return SBB(op1, op2, bit, 0);
            /* XOR */ case 6: return XOR(op1, op2, bit);
            /* CMP */ case 7: return SBB(op1, op2, bit, 0);

            // Ошибка
            default: printf("Unexpected alu opcode %d\n", id); exit(2);
        }
    }

    // Выполнить сдвиговую инструкцию
    uint shift_grp(int id, uint op1, uint op2, int bit) {

        switch (id) {

            case 0: return ROL(op1, op2, bit);
            case 1: return ROR(op1, op2, bit);
            case 2: return RCL(op1, op2, bit);
            case 3: return RCR(op1, op2, bit);
            case 4: return SHL(op1, op2, bit);
            case 5: return SHR(op1, op2, bit);
            case 6: return SHL(op1, op2, bit);
            case 7: return SAR(op1, op2, bit);
        }

        return 0;
    }

    // Группы инструкции F6/F7
    void aluext_group(uint op1, uint bit) {

        uint res = 0, op2, tmp;

        switch (mrm_reg) {

            case 0:
            case 1: { /* TEST */

                op2 = (bit == 8 ? get_Ib() : get_Iv());
                AND(op1, op2, bit);
                break;
            }
            case 2: { /* NOT */

                res = ~op1;
                break;
            }
            case 3: { /* NEG */

                res = SBB(0, op1, bit, 0);
                SET_CARRY(res);
                break;
            }
            case 4: { /* MUL */

                // Вычисляем al*op8, ax*op16
                tmp  = MUL(r.ax, op1, bit);
                r.ax = tmp & 0xFFFF;
                r.dx = (bit == 16) ? (tmp >> 16) & 0xFFFF : r.dx;
                break;
            }
            case 5: { /* IMUL */

                // Вычисляем al*op8, ax*op16
                tmp = IMUL(r.ax, op1, bit);

                // Ставится в любом случае
                r.ax = (tmp & 0xFFFF);
                r.dx = (bit == 16) ? (tmp >> 16) & 0xFFFF : r.dx;
                break;
            }
            case 6: { /* DIV */

                DIV(r.ax, op1, bit);
                break;
            }
            case 7: { /* IDIV */

                IDIV(r.ax, op1, bit);
                break;
            }
        }

        // NEG / NOT
        if (mrm_reg == 2 || mrm_reg == 3) {
            if (bit == 8) put_Eb(res); else put_Ev(res);
        }
    }

    // Группа FE
    void incdec_group(uint op) {

        switch (mrm_reg) {

            case 0: put_Eb( INC(op, 8) ); break;
            case 1: put_Eb( DEC(op, 8) ); break;

            default: undefined_instr();
        }
    }

    // Группа с разнообразным содержанием
    void misc_group(uint op) {

        switch (mrm_reg) {

            case 0: { /* INC Ev */
                put_Ev(INC(op, 16));
                break;
            }
            case 1: { /* DEC Ev */
                put_Ev(DEC(op, 16));
                break;
            }
            case 2: { /* CALL Ev */
                push(ip);
                ip = op;
                break;
            }
            case 3: { /* CALL Mp */

                push( r.cs );
                push( ip );

                op    = get_Iv();
                r.cs  = fetch_word();
                ip    = op;
                break;
            }
            case 4: { /* JMP Ev */
                ip = op;
                break;
            }
            case 5: { /* JMP Mp */

                op   = get_Iv();
                r.cs = fetch_word();
                ip   = op;
                break;
            }
            case 6: { /* PUSH Ev */
                push( op );
                break;
            }
            case 7: { /* Undefined */
                undefined_instr();
                break;
            }
        }
    }

    // Условный короткий переход
    void JumpCondShort(int mode) {

        int b = fetch_signed();

        // Переход при совпадении условия
        if (test_condition(mode)) {
            ip = (ip + b) & 0xffff;
        }
    }

    // Длинный вызов процедуры
    void CallFar() {

        op1 = get_Iv();     // ip
        op2 = fetch_word(); // cs

        push(r.cs);
        push(ip);

        r.cs = op2;
        ip = op1;
    }

    // Длинный переход
    void JmpFar() {

        op1 = get_Iv(); // ip
        op2 = fetch_word(); // cs
        r.cs = op2; ip = op1;
    }

    // Переход, пока NZ или Z
    void LoopX(int zf) {

        int tmp = fetch_signed();
        r.cx = (r.cx - 1) & 0xffff;

        // LOOPNZ: Если ZF=0 и CX, переход
        // LOOPZ:  Если ZF=1 и CX, переход
        if (r.cx && (f.z == zf)) {
            ip = (ip + tmp) & 0xffff;
        }
    }

    // Переход, пока CX != 0
    void Loop() {

        int tmp = fetch_signed();
        r.cx = (r.cx - 1) & 0xffff;
        if (r.cx) {
            ip = (ip + tmp) & 0xffff;
        }
    }

    // Сохрание флагов в число
    int save_flags() {

        return  (f.o << 11)|
                (f.d << 10)|
                (f.i << 9)|
                (f.t << 8)|
                (f.s << 7)|
                (f.z << 6)|
                (f.a << 4)|
                (f.p << 2)|
                0x02|
                (f.c);
    }

    // Загрузка в нижний байт флагов
    void load_flags_lo(int t) {

        f.s = (t & (1 << 7)) ? 1 : 0;
        f.z = (t & (1 << 6)) ? 1 : 0;
        f.a = (t & (1 << 4)) ? 1 : 0;
        f.p = (t & (1 << 2)) ? 1 : 0;
        f.c = (t & (1 << 0)) ? 1 : 0;
    }

    // Загрузка флагов из числа t
    void load_flags(int t) {

        f.o = (t & (1 << 11)) ? 1 : 0;
        f.d = (t & (1 << 10)) ? 1 : 0;
        f.i = (t & (1 << 9))  ? 1 : 0;
        f.t = (t & (1 << 8))  ? 1 : 0;

        load_flags_lo(t);
    }

    // Строковое перемещение
    void MOVSx(int w) {

        // Не выполнять REP если cx=0
        if (rep && (r.cx == 0)) return;

        // Переместить байт
        if (w) write16(r.es, r.di, read16(SEGDEFAULT, r.si));
        else   write  (r.es, r.di, read  (SEGDEFAULT, r.si));

        int tmp = w ? 2 : 1; DINCREMENT; SINCREMENT;
        if (rep) { r.cx = (r.cx - 1) & 0xffff; ip = start_ip; }
    }

    // Строковое сравнение
    void CMPSx(int w) {

        if (rep && (r.cx == 0)) return;

        // Сравнить байт/слово
        op1 = w ? read16(SEGDEFAULT, r.si) : read(SEGDEFAULT, r.si);
        op2 = w ? read16(r.es,       r.di) : read(r.es,       r.di);

        SBB(op1, op2, w ? 16 : 8, 0);
        int tmp = w ? 2 : 1; DINCREMENT; SINCREMENT;

        if (rep) { r.cx = (r.cx - 1) & 0xffff; } // Если есть REPNZ/REPE
        if (rep == REPZ  && !f.z) return; // REPZ, но  NO ZERO
        if (rep == REPNZ &&  f.z) return; // REPNZ, но ZERO
        if (rep) ip = start_ip; // Повтор инструкции, если есть REP
    }

    // Запись по адресу
    void STOSx(int w) {

        if (rep && (r.cx == 0)) return;

        // Записать из AL/AX в память
        if (w) write16(r.es, r.di, r.ax);
          else write  (r.es, r.di, r.ax);

        int tmp = w ? 2 : 1; DINCREMENT;

        if (rep) { r.cx = (r.cx - 1) & 0xffff; ip = start_ip; }
    }

    // Загрузка строки
    void LODSx(int w) {

        if (rep && (r.cx == 0)) return;

        // Записать из AL/AX в память
        if (w) r.ax = read16(SEGDEFAULT, r.si);
        else   put_reg(REG_AL, 8, read(SEGDEFAULT, r.si));

        int tmp = w ? 2 : 1; SINCREMENT;
        if (rep) { r.cx = (r.cx - 1) & 0xffff; ip = start_ip; }
    }

    // Аналогично CMPSx, но op1 = al/ax
    void SCASx(int w) {

        if (rep && (r.cx == 0)) return;

        // Сравнить байт/слово
        op1 = w ? r.ax : get_al();
        op2 = w ? read16(r.es, r.di) : read(r.es, r.di);

        SBB(op1, op2, w ? 16 : 8, 0);
        int tmp = w ? 2 : 1; DINCREMENT; SINCREMENT;

        if (rep) { r.cx = (r.cx - 1) & 0xffff; } // Если есть REPNZ/REPE
        if (rep == REPZ  && !f.z) return; // REPZ, но  NO ZERO
        if (rep == REPNZ &&  f.z) return; // REPNZ, но ZERO
        if (rep) ip = start_ip; // Повтор инструкции, если есть REP
    }

    // Инструкция ENTER
    void enterproc() {

        uint stacksize = get_Iv();
        uint nestlev   = get_Ib();

        push( r.bp );
        uint frametemp = r.sp, i;

        if (nestlev) {

            for (i = 1; i < nestlev; i++) {

                r.bp = (r.bp - 2) & 0xffff;
                push( r.bp );
            }

            push( r.sp );
        }

        r.bp = frametemp;
        r.sp = (r.bp - stacksize) & 0xffff;
    }

    // Вызов прерывания
    void interrupt86(int n) {

        op1 = read16(0, n*4 + 0);
        op2 = read16(0, n*4 + 2);

        // Особый вызов процедуры
        if (op2 == 0xFFFF) {

            bios->r = r;
            bios->f = f;
            switch (op1) {

                /* INT 10h */ case 0x0: bios->int10_handler(); break;
                /* INT 13h */ case 0x3: bios->int13_handler(); break;
                default: regs(); panic("undefined interrupt call");

            }
            r = bios->r;
            f = bios->f;
            return;
        }

        // Сохранить флаги, cs:ip в стек
        push( save_flags() );
        push( r.cs );
        push( ip );

        // Вызвать новое значение cs:ip
        ip = op1; r.cs = op2;

        f.i = 0; f.t = 0;
    }

    // Коррекция после умножения
    void aam() {

        op1 = get_al();
        op2 = get_Ib();

        if (!op2) { interrupt86(0); return; }

        put_reg(REG_AH, 8, op1 / op2);
        put_reg(REG_AL, 8, op1 % op2);

        SET_SIGN   ( r.ax & 0x8000 );
        SET_ZERO   ( r.ax );
        SET_PARITY ( r.ax );
    }

    // Коррекция после деления
    void aad() {

        op1 = (r.ax >> 8) & 0xff;
        op2 = get_al();
        uint tmp = (op1 * get_Ib() + op2);

        put_reg(REG_AH, 8, tmp);
        put_reg(REG_AL, 8, 0);

        SET_SIGN   ( 0 );
        SET_ZERO   ( tmp );
        SET_PARITY ( tmp );
    }

    // Обработка FPU
    void fpu() {

        printf("panic: fpu not used yet\n");
        exit(0);
    }

    // Процессорное исключение UD
    void undefined_instr() {

        printf("Undefined opcode: %03x", opcode); exit(1);
    }

    // Статус остановки процессора
    void halted(int halt) {
        cpu_halt = halt;
    }

    // Один шаг
    void step() {

        // Прерывание может нарушить halt

        // Остановлен процессор
        if (cpu_halt) { return; }

        fetch_opcode();

        // Выполнить разбор modrm
        if (instruction_has_modrm[ opcode ]) {
            fetch_modrm_16();
        }

        // Исполнение опкодов
        switch (instructions[ opcode ]) {

            case NOP: break;
            case FPU: fpu(); break;

            // Арифметические инструкции
            case ALU_EbGb: ALU_GRP(get_Eb(), get_Gb(), put_Eb(res),  8);
            case ALU_EvGv: ALU_GRP(get_Ev(), get_Gv(), put_Ev(res), 16);
            case ALU_GbEb: ALU_GRP(get_Gb(), get_Eb(), put_Gb(res),  8);
            case ALU_GvEv: ALU_GRP(get_Gv(), get_Ev(), put_Gv(res), 16);
            case ALU_ALIb: ALU_GRP(get_al(), get_Ib(), put_al(res),  8);
            case ALU_AXIv: ALU_GRP(get_ax(), get_Iv(), put_ax(res), 16);
            case TESTEbIb: AND( get_Eb(), get_Ib(),  8 ); break;
            case TESTEvIv: AND( get_Ev(), get_Iv(), 16 ); break;
            case TESTALIb: AND( get_al(), get_Ib(),  8 ); break;
            case TESTAXIv: AND( get_ax(), get_Iv(), 16 ); break;

            // Групповые арифметические
            case AGEbIb: ALU_GEB(get_Eb(), get_Ib(), put_Eb(res),  8);
            case AGEbIv: ALU_GEB(get_Ev(), get_Iv(), put_Ev(res), 16);
            case AGEvIb: ALU_GEB(get_Ev(), get_Ie(), put_Ev(res), 16);
            case GRP1b:  aluext_group( get_Eb(), 8  ); break;
            case GRP1v:  aluext_group( get_Eb(), 16 ); break;
            case GRP2b:  incdec_group( get_Eb() ); break;
            case GRP2v:  misc_group  ( get_Ev() ); break;

            // Сдвиговые
            case SGRPEbIb: put_Eb( shift_grp(mrm_reg, get_Eb(), get_Ib(),  8) ); break;
            case SGRPEvIb: put_Ev( shift_grp(mrm_reg, get_Ev(), get_Ib(), 16) ); break;
            case SGRPEb1:  put_Eb( shift_grp(mrm_reg, get_Eb(), 1,  8) ); break;
            case SGRPEv1:  put_Ev( shift_grp(mrm_reg, get_Ev(), 1, 16) ); break;
            case SGRPEbCL: put_Eb( shift_grp(mrm_reg, get_Eb(), r.cx,  8) ); break;
            case SGRPEvCL: put_Ev( shift_grp(mrm_reg, get_Ev(), r.cx, 16) ); break;

            // Стек
            case PUSHss: push(get_SS(OPC43));  break;
            case POPss:  put_SS(OPC43, pop()); break;
            case PUSHGv: push( get_reg(OPC20, 16) ); break;
            case POPGv:  put_reg( OPC20, 16, pop() ); break;
            case POPEv:  put_Ev( pop() ); break;
            case PUSHF:  push(save_flags()); break;
            case POPF:   load_flags(pop()); break;
            case RETIv:  op1 = get_Iv(); ip = pop(); r.sp = (r.sp + op1) & 0xffff; break;
            case RETFIv: op1 = get_Iv(); ip = pop(); r.cs = pop(); r.sp = (r.sp + op1) & 0xffff; break;
            case RET:    ip  = pop(); break;
            case RETF:   ip  = pop(); r.cs = pop(); break;
            case ENTER:  enterproc(); break;
            case LEAVE:  r.sp = r.bp; r.bp = pop(); break;
            case PUSHIv: push( get_Iv() ); break;

            // Флаги
            case LAHF:   put_reg(REG_AH, 8, save_flags()); break;
            case SAHF:   load_flags_lo(r.ax >> 8); break;
            case CMC:    f.c ^= 1; break;
            case CLC:    f.c = 0; break;
            case STC:    f.c = 1; break;
            case CLI:    f.i = 0; break;
            case STI:    f.i = 1; break;
            case CLD:    f.d = 0; break;
            case STD:    f.d = 1; break;

            // Коррекции
            case DAA:    DAA_op(); break;
            case DAS:    DAS_op(); break;
            case AAA:    AAA_op(); break;
            case AAS:    AAS_op(); break;
            case CBW:    r.ax = r.ax & 0x80 ? (r.ax | 0xFF00) : r.ax; break;
            case CWD:    r.dx = r.ax & 0x8000 ? 0xFFFF : 0; break;
            case AAM:    aam(); break;
            case AAD:    aad(); break;
            case SALC:   put_reg(REG_AL, 8, f.c ? 0xff : 0); break;
            case XLATB:  op1 = (16*SEGDEFAULT + r.bx) + get_al(); put_al(m[ op1 ]); break;

            // Инкремент и декремент
            case INCGv:  INCDEC(INC, OPC20, 16);
            case DECGv:  INCDEC(DEC, OPC20, 16);

            // Переходы
            case JCOND8:   JumpCondShort(OPC30); break;
            case CALLFm32: CallFar(); break;
            case JMPFm32:  JmpFar(); break;
            case LOOPx:    LoopX(opcode & 1); break;
            case LOOP:     Loop(); break;
            case JCXZ:     op1 = fetch_signed(); if (r.cx == 0) ip = (ip + op1) & 0xffff; break;
            case CALLIv:   op1 = get_Iv(); push(ip); ip = (ip + op1) & 0xffff; break;
            case JMPIv:    op1 = get_Iv(); ip = (ip + op1) & 0xffff; break;
            case JMPIb:    op1 = fetch_signed(); ip = (ip + op1) & 0xffff; break;

            // Перемещения
            case XCHGEbGb:  op1 = get_Eb(); op2 = get_Gb(); put_Eb(op2); put_Gb(op1); break;
            case XCHGEvGv:  op1 = get_Ev(); op2 = get_Gv(); put_Ev(op2); put_Gv(op1); break;
            case XCHGRx:    op1 = get_reg(OPC20, 16); put_reg(OPC20, 16, r.ax); put_reg(0, 16, op1); break;
            case MOVEbGb:   put_Eb( get_Gb() ); break;
            case MOVEvGv:   put_Ev( get_Gv() ); break;
            case MOVGbEb:   put_Gb( get_Eb() ); break;
            case MOVGvEv:   put_Gv( get_Ev() ); break;
            case MOVEvS:    put_Ev( get_SS( mrm_reg ) ); break;
            case LEAGvM:    put_Gv( ea ); break;
            case MOVSEv:    put_SS( mrm_reg, get_Ev() ); break;
            case MOVALm16:  put_al ( read(   SEGDEFAULT, get_Iv() ) ); break;
            case MOVAXm16:  put_ax ( read16( SEGDEFAULT, get_Iv() ) ); break;
            case MOVm16AL:  write  ( SEGDEFAULT, get_Iv(), get_al() ); break;
            case MOVm16AX:  write16( SEGDEFAULT, get_Iv(), get_ax() ); break;
            case MOVGbIb:   put_reg( OPC20, 8,  get_Ib() ); break;
            case MOVGvIv:   put_reg( OPC20, 16, get_Iv() ); break;
            case LESGvEv:   LOADSEG( r.es ); break;
            case LDSGvEv:   LOADSEG( r.ds ); break;
            case MOVEbIb:   put_Eb( get_Ib() ); break;
            case MOVEvIv:   put_Ev( get_Iv() ); break;

            // Строковые
            case MOVS:  MOVSx(opcode & 1); break;
            case CMPS:  CMPSx(opcode & 1); break;
            case STOS:  STOSx(opcode & 1); break;
            case LODS:  LODSx(opcode & 1); break;
            case SCAS:  SCASx(opcode & 1); break;

            // Прерывания
            case INT1:  interrupt86(1); break;
            case INT3:  interrupt86(3); break;
            case INTIb: interrupt86(get_Ib()); break;
            case INTO:  if (f.o) interrupt86(4); break;
            case IRET:  ip = pop(); r.cs = pop(); load_flags( pop() ); break;

            // ОТЛАДКА
            case HLT:   ip = (ip - 1) & 0xffff; cpu_halt = 1; dump(dump_addr); regs(); break;

            // Порты
            case INbIb:  op1 = get_Ib(); put_al( machine->port_in(op1) ); break;
            case INbDx:  op1 = r.dx;     put_al( machine->port_in(op1) ); break;
            case INvIb:  op1 = get_Ib(); put_al( machine->port_in(op1) ); put_reg(REG_AH, 8, machine->port_in(op1) ); break;
            case INvDx:  op1 = r.dx;     put_al( machine->port_in(op1) ); put_reg(REG_AH, 8, machine->port_in(op1) ); break;

            case OUTbIb: op1 = get_Ib(); machine->port_out( op1, get_al() ); break;
            case OUTbDX: op1 = r.dx;     machine->port_out( op1, get_al() ); break;
            case OUTvIb: op1 = get_Ib(); machine->port_out( op1, get_al() ); machine->port_out( op1, r.ax >> 8 ); break;
            case OUTvDX: op1 = r.dx;     machine->port_out( op1, get_al() ); machine->port_out( op1, r.ax >> 8 ); break;

            default: undefined_instr(); break;
        }

        // При установленном TF=1, вызвать прерывание
        if (f.t) interrupt86(1);

        tstates++;
    }
};
