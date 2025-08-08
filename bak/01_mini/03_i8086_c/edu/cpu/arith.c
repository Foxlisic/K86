byte ADD8(byte op1, byte op2) {

    uint res  = op1 + op2;
    byte dst  = res & 0xff;

    SET_OVER    ((op1 ^ op2 ^ 0x80) & (op1 ^ dst) & 0x80);
    SET_SIGN    (dst & 0x80);
    SET_ZERO    (dst);
    SET_AUX     ((op1 ^ op2 ^ dst) & 0x10);
    SET_PARITY  (dst);
    SET_CARRY   (res & 0x100);

    return dst;
}

word ADD16(word op1, word op2) {

    uint res  = op1 + op2;
    word dst  = res & 0xffff;

    SET_OVER    ((op1 ^ op2 ^ 0x8000) & (op1 ^ dst) & 0x8000);
    SET_SIGN    (dst & 0x8000);
    SET_ZERO    (dst);
    SET_AUX     ((op1 ^ op2 ^ dst) & 0x10);
    SET_PARITY  (dst);
    SET_CARRY   (res & 0x10000);

    return dst;
}

// Групповые инструкция АЛУ для 8/16 бит; size=1 => 16 bit
word Grp1A_bw(byte size, byte grp_id, byte op1, byte op2) {

    switch (grp_id) {

        case 0: return size ? ADD16(op1, op2) : ADD8(op1, op2);
        //case 1: return;
        //case 2:
        //case 3:
        //case 4:
        //case 5:
        //case 6:
        //case 7:
    }

    return 0;
}

// АЛУ-инструкции
void Grp1A() {

    byte size = (opcode & 1);
    byte dir  = (opcode & 2);
    byte num  = (opcode & 0x38) >> 3;
    word res;

    // Исполнить инструкцию
    res = Grp1A_bw
    (
        /* Размер */    (size),
        /* Операция */  (num),
        /* Операнд 1 */ (dir ? GET_GB() : GET_EB()),
        /* Операнд 2 */ (dir ? GET_EB() : GET_GB())
    );

    if (num < 7) {

        // Запись результата, только если это не CMP
        if (size) { if (dir) PUT_GV(res); else PUT_EV(res); } // 16
             else { if (dir) PUT_GB(res); else PUT_EB(res); } // 8
    }
}
