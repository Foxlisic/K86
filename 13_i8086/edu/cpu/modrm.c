// Прочитать байт ModRM и разобрать его, вычислить эффективный адрес
word FETCH_MODRM(byte override, word oversegment) {

    // Читать байт
    modrm     = FETCH_BYTE();
    modrm_mod = (modrm & 0xc0) >> 6;
    modrm_reg = (modrm & 0x38) >> 3;
    modrm_r_m = (modrm & 0x07);

    // Сегмент по умолчанию
    uint ea = 0;
    segment = (modrm_r_m == 2 || modrm_r_m == 3) ||
              (modrm_r_m == 6 && modrm_mod  > 0) ? SS : DS;

    // Эффективный адрес для всех
    switch (modrm_r_m) {

        case 0: ea = SI + BX; break;
        case 1: ea = DI + BX; break;
        case 2: ea = SI + BP; break;
        case 3: ea = DI + BP; break;
        case 4: ea = SI;      break;
        case 5: ea = DI;      break;
        case 6: ea = BP;      break;
        case 7: ea = BX;      break;
    }

    // Расчет эффективного адреса
    switch (modrm_mod) {

        /* +0  */ case 0: ea  = modrm_r_m == 6 ? FETCH_WORD() : ea; break;
        /* +8  */ case 1: ea += FETCH_SIGNED_BYTE(); break;
        /* +16 */ case 2: ea += FETCH_WORD(); break;
    }

    // Задан сегментный префикс
    if (override) segment = oversegment;

    return ea & 0xffff;
}
