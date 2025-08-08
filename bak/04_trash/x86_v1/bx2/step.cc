// Выполнение одной инструкции
void step() {
    
    byte tmp_a;
    byte has_prefix;
    
    segment         = & segs[REG_DS];
    opsize          = segs[REG_CS].defsize;
    adsize          = segs[REG_CS].defsize;
    seg_override    = 0;
    exception       = 0;
    
    do {

        opcode = fetch(); 
        has_prefix = 0;

        switch (opcode) {

            case 0x00: { // ADD Eb, Gb

                fetch_modrm();
                put_eb(addbw(get_eb(), get_rb(), BIT_BYTE));
                break;
            }
            case 0x01: { // ADD Ew, Gv
            
                fetch_modrm();
                put_ew(addbw(get_ew(), get_rw(), BIT_WORD));
                break;
            }
            case 0x02: { // ADD Gb, Eb

                fetch_modrm();
                put_rb(addbw(get_rb(), get_eb(), BIT_BYTE));
                break;
            }
            case 0x03: { // ADD Gv, Ew
            
                fetch_modrm();
                put_rw(addbw(get_rw(), get_ew(), BIT_WORD));
                break;
            }
            case 0x26: { // ES:
            
                segment = & segs[REG_ES];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }
            case 0x2E: { // CS:
            
                segment = & segs[REG_CS];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }
            case 0x36: { // SS:
            
                segment = & segs[REG_SS];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }
            case 0x3E: { // DS:
            
                segment = & segs[REG_DS];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }            
            case 0x40: case 0x41: case 0x42: case 0x43: // INC rw
            case 0x44: case 0x45: case 0x46: case 0x47: {
                
                tmp_a = get_carry();
                put_regw(opcode & 7, addbw(get_regw(opcode & 7), 1, BIT_WORD));
                set_carry(tmp_a);
                break;
            }
            case 0x48: case 0x49: case 0x4A: case 0x4B: // DEC rw
            case 0x4C: case 0x4D: case 0x4E: case 0x4F: {
                
                tmp_a = get_carry();
                put_regw(opcode & 7, subbw(get_regw(opcode & 7), 1, BIT_WORD));
                set_carry(tmp_a);
                break;
            }
            case 0x64: { // FS:
            
                segment = & segs[REG_FS];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }
            case 0x65: { // GS:
            
                segment = & segs[REG_GS];
                seg_override = 1;
                has_prefix = 1;
                break;  
            }
            case 0x66: { // Префикс расширения операнда

                opsize = ~opsize;
                has_prefix = 1;
                break;
            }
            case 0x67: { // Префикс расширения адреса

                adsize = ~adsize;
                has_prefix = 1;
                break;
            }
            case 0xB0: case 0xB1: case 0xB2: case 0xB3: // MOV rb, ib
            case 0xB4: case 0xB5: case 0xB6: case 0xB7: {

                put_regb(opcode & 7, fetch());
                break;
            }            
            case 0xB8: case 0xB9: case 0xBA: case 0xBB: // MOV rw, iw
            case 0xBC: case 0xBD: case 0xBE: case 0xBF: {
                
                put_regw(opcode & 7, fetch_iw());
                break;
            }
        }    
    }
    while (has_prefix);
}