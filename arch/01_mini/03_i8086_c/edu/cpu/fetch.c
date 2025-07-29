// Считывание опкода из памяти
byte FETCH_OPCODE() {

    byte i_len = 0; // Длина инструкции
    i_rep      = 0; // REP=1 (NZ), REP=2(Z)
    i_seg_over = 0; // Есть Override
    i_seg_val  = 0; // Значение сегмента

    do {

        byte op = FETCH_BYTE();

        switch (op) {

            case 0x26: /* ES: */ i_seg_over = 1; i_seg_val = ES; break;
            case 0x2E: /* CS: */ i_seg_over = 1; i_seg_val = CS; break;
            case 0x36: /* SS: */ i_seg_over = 1; i_seg_val = SS; break;
            case 0x3E: /* DS: */ i_seg_over = 1; i_seg_val = DS; break;
            case 0xF0: /* LOCK */ break;
            case 0xF2: /* REPNZ */ i_rep = 1; break;
            case 0xF3: /* REPZ  */ i_rep = 2; break;

            /* Получен опкод */
            default: return op;
        }
    }
    while ((++i_len) < 16);

    /* Исключительная ситуация неверного опкода */
    return 0x90;
}
