
// Запуск в работу
word CPU::x86run(word instr_cnt) {

    tstates = 0;

    while (instr_cnt) {

        // Остановка процессора
        if (inhlt) return 1;

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
                case 0xA0: tempw = fetch_word(); setr8(REG_AX, machine_read(segment + tempw)); break;
                case 0xA1: tempw = fetch_word(); AX_ = read_word(segment, tempw); break;
                case 0xA2: tempw = fetch_word(); write     (segment, tempw, AX_); break;
                case 0xA3: tempw = fetch_word(); write_word(segment, tempw, AX_); break;

                // MOVSB: Переместить байт
                case 0xA4: {

                    REPINIT;
                    write(seg_es, DI_, machine_read(segment + SI_));
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
                    setsub8(machine_read(segment + SI_), machine_read(seg_es  + DI_));
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
                    setr8(REG_AL, machine_read(segment + SI_));
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
                    setsub8(AL_, machine_read(seg_es + DI_));
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
                case 0xD7: setr8(REG_AL, machine_read(segment + BX_ + (AX_ & 255))); break;

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
void CPU::extended_instr() {

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
