// Длинный прыжок
void JUMPFAR() {

    word ip = FETCH_WORD();
    word cs = FETCH_WORD();

    CS = cs;
    IP = ip;
}

void CMC() { flag_carry = !flag_carry; }
void CLC() { SET_CARRY(0); }
void STC() { SET_CARRY(1); }
void CLI() { flag_int = 0; }
void STI() { flag_int = 1; }
void CLD() { flag_dir = 0; }
void STD() { flag_dir = 1; }
