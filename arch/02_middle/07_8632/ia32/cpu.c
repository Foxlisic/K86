int opcode, cpu_repnz, cpu_repe, cpu_segment, cpu_reg32, 
    cpu_mem32,  cpu_lock, effective, cpu_modrm, cpu_bit,
    cpu_mod, cpu_rm, cpu_reg, Op1, Op2, seg_override;

    
/*
 * Процессор
 */

void init_cpu() {
    
    eax = 0x00001234; esp = 0x00000000;
    ebx = 0x00000000; ebp = 0x00000000; 
    ecx = 0x00000000; esi = 0x00000000; 
    edx = 0x00000000; edi = 0x00000000;
    eip = 0x00000000;
    
    es = 0x0000;
    cs = 0x0000;
    ds = 0x0000;
    ss = 0x0000;
    fs = 0x0000;
    gs = 0x0000;
    
    processor_mode = 0;
    default_reg    = 0;    
    
    dis_save_state();
}

// Получение значения регистра
int get_regval(int reg, int bit) {
    
    switch (reg) {
            
        case 0: 
        
            return (bit == 8 ? eax & 0xff :
                    bit == 16 ? eax & 0xffff : eax);
                    
        case 1: 
        
            return (bit == 8 ? ecx & 0xff :
                    bit == 16 ? ecx & 0xffff : ecx);

        case 2: 
        
            return (bit == 8 ? edx & 0xff :
                    bit == 16 ? edx & 0xffff : edx);

        case 3: 
        
            return (bit == 8 ? ebx & 0xff :
                    bit == 16 ? ebx & 0xffff : ebx);
        
        case 4: 
        
            return (bit == 8 ? (eax >> 8) & 0xff :
                    bit == 16 ? esp & 0xffff : esp);

        case 5: 
        
            return (bit == 8 ? (ecx >> 8) & 0xff :
                    bit == 16 ? ebp & 0xffff : ebp);

        case 6: 
        
            return (bit == 8 ? (edx >> 8) & 0xff :
                    bit == 16 ? esi & 0xffff : esi);

        case 7: 
        
            return (bit == 8 ? (ebx >> 8) & 0xff :
                    bit == 16 ? edi & 0xffff : edi);
    }
    
    return 0;
}

// Запись в регистр
void put_regval(int reg, uint value, int bit) {
    
    switch (reg) {
        
        case 0:
        
            if (bit == 8)  { eax = (eax & 0xffffff00) | (value & 0x00ff); return; }
            if (bit == 16) { eax = (eax & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { eax = (value); return; }
            break;
            
        case 1:
        
            if (bit == 8)  { ecx = (ecx & 0xffffff00) | (value & 0x00ff); return; }
            if (bit == 16) { ecx = (ecx & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { ecx = (value); return; }
            break;
        
        case 2:
        
            if (bit == 8)  { edx = (edx & 0xffffff00) | (value & 0x00ff); return; }
            if (bit == 16) { edx = (edx & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { edx = (value); return; }
            break;

        case 3:
        
            if (bit == 8)  { ebx = (ebx & 0xffffff00) | (value & 0x00ff); return; }
            if (bit == 16) { ebx = (ebx & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { ebx = (value); return; }
            break;

        case 4:
        
            if (bit == 8)  { eax = (eax & 0xffff00ff) | ((value & 0x00ff) << 8); return; }
            if (bit == 16) { esp = (esp & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { esp = (value); return; }
            break;

        case 5:
        
            if (bit == 8)  { ecx = (ecx & 0xffff00ff) | ((value & 0x00ff) << 8); return; }
            if (bit == 16) { ebp = (ebp & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { ebp = (value); return; }
            break;

        case 6:
        
            if (bit == 8)  { edx = (edx & 0xffff00ff) | ((value & 0x00ff) << 8); return; }
            if (bit == 16) { esi = (esi & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { esi = (value); return; }
            break;
            
        case 7:
        
            if (bit == 8)  { ebx = (ebx & 0xffff00ff) | ((value & 0x00ff) << 8); return; }
            if (bit == 16) { edi = (edi & 0xffff0000) | (value & 0xffff); return; }
            if (bit == 32) { edi = (value); return; }
            break;            
    }
}

// Получение опкода
int get_opcode() {
    
    int i, stop = 0;
    
    opcode       = 0;
    cpu_repnz    = 0;
    cpu_repe     = 0;
    cpu_reg32    = 0;
    cpu_mem32    = 0;
    cpu_lock     = 0;
    effective    = 0;
    cpu_modrm    = 0;    

    seg_override = 0;
    cpu_segment  = ds;
    
    /* Декодирование префиксов (макс 6) */
    for (i = 0; i < 6; i++) {

        int D = fetchb();

        switch (D) {
            
            case 0x0F: opcode |= 0x100; break;
            
            case 0x26: seg_override = 1; cpu_segment = es; break;
            case 0x2E: seg_override = 1; cpu_segment = cs; break;
            case 0x36: seg_override = 1; cpu_segment = ds;  break;
            case 0x3E: seg_override = 1; cpu_segment = ss; break;
            case 0x64: seg_override = 1; cpu_segment = fs; break;
            case 0x65: seg_override = 1; cpu_segment = gs; break;
            
            case 0x66: cpu_reg32 = cpu_reg32 ^ 1; break;
            case 0x67: cpu_mem32 = cpu_mem32 ^ 1; break;
            
            case 0xf0: cpu_lock = 1; break;
            case 0xf2: cpu_repnz = 1; break;
            case 0xf3: cpu_repe  = 1; break;
            
            default:   opcode |= D; stop = 1; break;
        }

        if (stop) break;
    }
    
    // Ошибка инструкции. Вызов Exception.
    if (stop == 0) {
        // exception();
    }
    
    /* Битность по умолчанию */
    cpu_bit = opcode & 1 ? (cpu_reg32 ? 32 : 16) : 8;
    
    return opcode;    
}

// Получение ModRM данных (и effective address)
void get_modrm() {
    
    int temp;
    
    cpu_modrm = fetchb();
        
    // Извлечение частей ModRM
    cpu_mod = (cpu_modrm >> 6);
    cpu_reg = (cpu_modrm & 0x38) >> 3;
    cpu_rm  = (cpu_modrm & 0x07);
    
    // Замена на SS: если нет segment override
    if (!seg_override) {
        
        // ss: для операции с BP
        if ((cpu_mod == 1 || cpu_mod == 2) && (cpu_rm == 2 || cpu_rm == 3 || cpu_rm == 6)) {
            cpu_segment = ss;
        }
        else if ((cpu_mod == 0) && (cpu_rm == 2 || cpu_rm == 3)) {
            cpu_segment = ss;
        }
    }
    
    // Регистровый операнд (битность из get_opcode)
    Op1 = get_regval(cpu_reg, cpu_bit);        

    // 16-битная адресация
    if (cpu_mem32 == 0) {
        
        switch (cpu_rm) {
            
            case 0: effective = (ebx + esi); break; 
            case 1: effective = (ebx + edi); break; 
            case 2: effective = (ebp + esi); break; 
            case 3: effective = (ebp + edi); break; 
            case 4: effective = (esi); break; 
            case 5: effective = (edi); break; 
            case 6: effective = (ebp); break; 
            case 7: effective = (ebx); break;                 
        }
        
        effective &= 0xffff;
        
        switch (cpu_mod) {
            
            /* none/disp16 */
            case 0: 
            
                if (cpu_rm == 6) { effective = fetchw(); } 
                Op2 = READ(cpu_bit, cpu_segment, effective);
                break;
            
            /* +disp8 */
            case 1: 
            
                temp = fetchb();
                effective += (temp & 0x80 ? temp - 0x100 : temp);
                Op2 = READ(cpu_bit, cpu_segment, effective);
                break;

            /* +disp16 */
            case 2: 
            
                temp = fetchw();
                effective += (temp & 0x8000 ? temp - 0x10000 : temp);
                Op2 = READ(cpu_bit, cpu_segment, effective);
                break;
            
            /* register */
            case 3: 
            
                Op2 = get_regval(cpu_rm, cpu_bit);  
                break;                
        }
        
    } else {
        
        // ...
    }
}

// ---------------------------------------------------------------------

// Записать результат обратно в байт ModRM
// [cpu_segment:effective] Адрес
// direction = 0 писать в r/m
//           = 1 писать в reg

void wmback(unsigned int value, int direction, int bit) {
    
    // Запись в r/m
    if (direction == 0) {
        
        if (cpu_mod == 3) {         
            put_regval(cpu_rm, value, bit); // Регистр R/M
        } else {
            WRITE(bit, cpu_segment, effective, value); // Память
        }        
    }
    // Запись в reg
    else {
        put_regval(cpu_reg, value, bit);    // Регистр REG
    }
}

// ---------------------------------------------------------------------

/* Шаг процессора */
void step() {
    
    u64 temp;
    
    // Сохранить предыдущее состояние
    dis_save_state();
    
    // Получить опкод
    opcode = get_opcode();    

    // Декодировать ModRM
    if (modrm_lookup[ opcode ]) {
        get_modrm();        
    }
    
    /* Исполнение инструкции */
    switch (opcode) {
        
        /* ADD */
        case 0x00: temp = INSTR_ADD(Op1, Op2, 8); wmback(temp, 0, 8); break;
        case 0x01: break;
        case 0x02: break;
        case 0x03: break;
        case 0x04: break;
        case 0x05: break;        
        case 0x06: break;
        case 0x07: break;
        
        /* OR */
        case 0x08: break;
        case 0x09: break;
        case 0x0A: break;
        case 0x0B: break;
        case 0x0C: break;
        case 0x0D: break;
        case 0x0E: break;
        case 0x0F: break;

        /* ADC */
        case 0x10: break;
        case 0x11: break;
        case 0x12: break;
        case 0x13: break;
        case 0x14: break;
        case 0x15: break;
        case 0x16: break;
        case 0x17: break;
        
        /* SBB */
        case 0x18: break;
        case 0x19: break;
        case 0x1A: break;
        case 0x1B: break;
        case 0x1C: break;
        case 0x1D: break;
        case 0x1E: break;
        case 0x1F: break;
        
        /* AND */
        case 0x20: break;
        case 0x21: break;
        case 0x22: break;
        case 0x23: break;
        case 0x24: break;
        case 0x25: break;
        case 0x26: break;
        case 0x27: break;
        
        /* SUB */
        case 0x28: break;
        case 0x29: break;
        case 0x2A: break;
        case 0x2B: break;
        case 0x2C: break;
        case 0x2D: break;
        case 0x2E: break;
        case 0x2F: break;
        
        /* XOR */
        case 0x30: break;
        case 0x31: break;
        case 0x32: break;
        case 0x33: break;
        case 0x34: break;
        case 0x35: break;
        case 0x36: break;
        case 0x37: break;
        
        /* CMP r16 */
        case 0x38: break;
        case 0x39: break;
        case 0x3A: break;
        case 0x3B: break;
        case 0x3C: break;
        case 0x3D: break;
        case 0x3E: break;
        case 0x3F: break;
                
        /* INC r16 */
        case 0x40: break;
        case 0x41: break;
        case 0x42: break;
        case 0x43: break;
        case 0x44: break;
        case 0x45: break;
        case 0x46: break;
        case 0x47: break;
        
        /* DEC r16 */
        case 0x48: break;
        case 0x49: break;
        case 0x4A: break;
        case 0x4B: break;
        case 0x4C: break;
        case 0x4D: break;
        case 0x4E: break;
        case 0x4F: break;
        
        /* PUSH r16 */
        case 0x50: break;
        case 0x51: break;
        case 0x52: break;
        case 0x53: break;
        case 0x54: break;
        case 0x55: break;
        case 0x56: break;
        case 0x57: break;
                
        /* POP r16 */
        case 0x58: break;
        case 0x59: break;
        case 0x5A: break;
        case 0x5B: break;
        case 0x5C: break;
        case 0x5D: break;
        case 0x5E: break;
        case 0x5F: break;
        
        case 0x60: break;
        case 0x61: break;
        case 0x62: break;
        case 0x63: break;
        case 0x64: break;
        case 0x65: break;
        case 0x66: break;
        case 0x67: break;
        case 0x68: break;
        case 0x69: break;
        case 0x6A: break;
        case 0x6B: break;
        case 0x6C: break;
        case 0x6D: break;
        case 0x6E: break;
        case 0x6F: break;
        
        
        case 0x70: break;
        case 0x71: break;
        case 0x72: break;
        case 0x73: break;
        case 0x74: break;
        case 0x75: break;
        case 0x76: break;
        case 0x77: break;
        case 0x78: break;
        case 0x79: break;
        case 0x7A: break;
        case 0x7B: break;
        case 0x7C: break;
        case 0x7D: break;
        case 0x7E: break;
        case 0x7F: break;
        
        case 0x80: break;
        case 0x81: break;
        case 0x82: break;
        case 0x83: break;
        case 0x84: break;
        case 0x85: break;
        case 0x86: break;
        case 0x87: break;
        case 0x88: break;
        case 0x89: break;
        case 0x8A: break;
        case 0x8B: break;
        case 0x8C: break;
        case 0x8D: break;
        case 0x8E: break;
        case 0x8F: break;
        
        case 0x90: break;
        case 0x91: break;
        case 0x92: break;
        case 0x93: break;
        case 0x94: break;
        case 0x95: break;
        case 0x96: break;
        case 0x97: break;
        case 0x98: break;
        case 0x99: break;
        case 0x9A: break;
        case 0x9B: break;
        case 0x9C: break;
        case 0x9D: break;
        case 0x9E: break;
        case 0x9F: break;
        
        case 0xA0: break;
        case 0xA1: break;
        case 0xA2: break;
        case 0xA3: break;
        case 0xA4: break;
        case 0xA5: break;
        case 0xA6: break;
        case 0xA7: break;
        case 0xA8: break;
        case 0xA9: break;
        case 0xAA: break;
        case 0xAB: break;
        case 0xAC: break;
        case 0xAD: break;
        case 0xAE: break;
        case 0xAF: break;
        
        case 0xB0: break;
        case 0xB1: break;
        case 0xB2: break;
        case 0xB3: break;
        case 0xB4: break;
        case 0xB5: break;
        case 0xB6: break;
        case 0xB7: break;
        case 0xB8: break;
        case 0xB9: break;
        case 0xBA: break;
        case 0xBB: break;
        case 0xBC: break;
        case 0xBD: break;
        case 0xBE: break;
        case 0xBF: break;
        
        case 0xC0: break;
        case 0xC1: break;
        case 0xC2: break;
        case 0xC3: break;
        case 0xC4: break;
        case 0xC5: break;
        case 0xC6: break;
        case 0xC7: break;
        case 0xC8: break;
        case 0xC9: break;
        case 0xCA: break;
        case 0xCB: break;
        case 0xCC: break;
        case 0xCD: break;
        case 0xCE: break;
        case 0xCF: break;
        
        case 0xD0: break;
        case 0xD1: break;
        case 0xD2: break;
        case 0xD3: break;
        case 0xD4: break;
        case 0xD5: break;
        case 0xD6: break;
        case 0xD7: break;
        case 0xD8: break;
        case 0xD9: break;
        case 0xDA: break;
        case 0xDB: break;
        case 0xDC: break;
        case 0xDD: break;
        case 0xDE: break;
        case 0xDF: break;
        
        case 0xE0: break;
        case 0xE1: break;
        case 0xE2: break;
        case 0xE3: break;
        case 0xE4: break;
        case 0xE5: break;
        case 0xE6: break;
        case 0xE7: break;
        case 0xE8: break;
        case 0xE9: break;
        case 0xEA: break;
        
        /* JMP r8 */
        case 0xEB: temp = fetchb(); eip = eip + (temp & 0x80 ? temp - 0x100 : temp); break;
        
        case 0xEC: break;
        case 0xED: break;
        case 0xEE: break;
        case 0xEF: break;
        
        case 0xF0: break;
        case 0xF1: break;
        case 0xF2: break;
        case 0xF3: break;
        case 0xF4: break;
        case 0xF5: break;
        case 0xF6: break;
        case 0xF7: break;
        case 0xF8: break;
        case 0xF9: break;
        case 0xFA: break;
        case 0xFB: break;
        case 0xFC: break;
        case 0xFD: break;
        case 0xFE: break;
        case 0xFF: break;
                
    }
    
}
