#include "machine.h"

// Одна инструкция
void machine::step() {

    dword t32, a32;
    byte  noint = 0;

    switch (opcode = get_opcode()) {

        case 0x00: { // ADD rm, r8

            fetch_modrm();
            put_eb(do_add(get_eb(), get_rb(), 0));
            break;
        }
        case 0x01: { // ADD rm, r16

            fetch_modrm();
            put_ev(do_add(get_ev(), get_rv(), 1));
            break;
        }
        case 0x02: { // ADD r8, rm

            fetch_modrm();
            put_rb(do_add(get_rb(), get_eb(), 0));
            break;
        }
        case 0x03: { // ADD r16, rm

            fetch_modrm();
            put_rv(do_add(get_rv(), get_ev(), 1));
            break;
        }
        case 0x04: { // ADD al, i8

            put_reg8(al, do_add(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x05: { // ADD ax, i16

            put_regv(ax, do_add(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x06: { // PUSH es

            push(segs[es], 0);
            break;
        }
        case 0x07: { // POP es

            load_seg(es, pop(0));
            break;
        }
        case 0x08: { // OR rm, r8

            fetch_modrm();
            put_eb(do_or(get_eb(), get_rb(), 0));
            break;
        }
        case 0x09: { // OR rm, r16

            fetch_modrm();
            put_ev(do_or(get_ev(), get_rv(), 1));
            break;
        }
        case 0x0A: { // OR r8, rm

            fetch_modrm();
            put_rb(do_or(get_rb(), get_eb(), 0));
            break;
        }
        case 0x0B: { // OR r16, rm

            fetch_modrm();
            put_rv(do_or(get_rv(), get_ev(), 1));
            break;
        }
        case 0x0C: { // OR al, i8

            put_reg8(al, do_or(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x0D: { // OR ax, i16

            put_regv(ax, do_or(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x0E: { // PUSH cs

            push(segs[cs], 0);
            break;
        }
        case 0x0F: { // extend:

            ud();
            break;
        }
        case 0x10: { // ADC rm, r8

            fetch_modrm();
            put_eb(do_adc(get_eb(), get_rb(), 0));
            break;
        }
        case 0x11: { // ADC rm, r16

            fetch_modrm();
            put_ev(do_adc(get_ev(), get_rv(), 1));
            break;
        }
        case 0x12: { // ADC r8, rm

            fetch_modrm();
            put_rb(do_adc(get_rb(), get_eb(), 0));
            break;
        }
        case 0x13: { // ADC r16, rm

            fetch_modrm();
            put_rv(do_adc(get_rv(), get_ev(), 1));
            break;
        }
        case 0x14: { // ADC al, i8

            put_reg8(al, do_adc(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x15: { // ADC ax, i16

            put_regv(ax, do_adc(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x16: { // PUSH ss

            push(segs[ss], 0);
            break;
        }
        case 0x17: { // POP ss

            load_seg(ss, pop(0));
            break;
        }
        case 0x18: { // SBB rm, r8

            fetch_modrm();
            put_rv(do_sbb(get_eb(), get_rb(), 0));
            break;
        }
        case 0x19: { // SBB rm, r16

            fetch_modrm();
            put_ev(do_sbb(get_ev(), get_rv(), 1));
            break;
        }
        case 0x1A: { // SBB r8, rm

            fetch_modrm();
            put_rb(do_sbb(get_rb(), get_eb(), 0));
            break;
        }
        case 0x1B: { // SBB r16, rm

            fetch_modrm();
            put_rv(do_sbb(get_rv(), get_ev(), 1));
            break;
        }
        case 0x1C: { // SBB al, i8

            put_reg8(al, do_sbb(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x1D: { // SBB ax, i16

            put_regv(ax, do_sbb(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x1E: { // PUSH ds

            push(segs[ds], 0);
            break;
        }
        case 0x1F: { // POP ds

            load_seg(ds, pop(0));
            break;
        }
        case 0x20: { // AND rm, r8

            fetch_modrm();
            put_eb(do_and(get_eb(), get_rb(), 0));
            break;
        }
        case 0x21: { // AND rm, r16

            fetch_modrm();
            put_ev(do_and(get_ev(), get_rv(), 1));
            break;
        }
        case 0x22: { // AND r8, rm

            fetch_modrm();
            put_rb(do_and(get_rb(), get_eb(), 0));
            break;
        }
        case 0x23: { // AND r16, rm

            fetch_modrm();
            put_rv(do_and(get_rv(), get_ev(), 1));
            break;
        }
        case 0x24: { // AND al, i8

            put_reg8(al, do_and(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x25: { // AND ax, i16

            put_regv(ax, do_and(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x26: { // ES:
            ud();
            break;
        }
        case 0x27: { // DAA
            daa();
            break;
        }
        case 0x28: { // SUB rm, r8

            fetch_modrm();
            put_rv(do_sub(get_eb(), get_rb(), 0));
            break;
        }
        case 0x29: { // SUB rm, r16

            fetch_modrm();
            put_ev(do_sub(get_ev(), get_rv(), 1));
            break;
        }
        case 0x2A: { // SUB r8, rm

            fetch_modrm();
            put_rb(do_sub(get_rb(), get_eb(), 0));
            break;
        }
        case 0x2B: { // SUB r16, rm

            fetch_modrm();
            put_rv(do_sub(get_rv(), get_ev(), 1));
            break;
        }
        case 0x2C: { // SUB al, i8

            put_reg8(al, do_sub(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x2D: { // SUB ax, i16

            put_regv(ax, do_sub(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x2E: { // CS:
            ud();
            break;
        }
        case 0x2F: { // DAS
            das();
            break;
        }
        case 0x30: { // XOR rm, r8

            fetch_modrm();
            put_eb(do_xor(get_eb(), get_rb(), 0));
            break;
        }
        case 0x31: { // XOR rm, r16

            fetch_modrm();
            put_ev(do_xor(get_ev(), get_rv(), 1));
            break;
        }
        case 0x32: { // XOR r8, rm

            fetch_modrm();
            put_rb(do_xor(get_rb(), get_eb(), 0));
            break;
        }
        case 0x33: { // XOR r16, rm

            fetch_modrm();
            put_rv(do_xor(get_rv(), get_ev(), 1));
            break;
        }
        case 0x34: { // XOR al, i8

            put_reg8(al, do_xor(get_reg8(al), fetch_byte(), 0));
            break;
        }
        case 0x35: { // XOR ax, i16

            put_regv(ax, do_xor(get_regv(al), fetch_gv(), 1));
            break;
        }
        case 0x36: { // SS:
            ud();
            break;
        }
        case 0x37: { // AAA
            aaa();
            break;
        }
        case 0x38: { // CMP rm, r8

            fetch_modrm();
            do_sub(get_eb(), get_rb(), 0);
            break;
        }
        case 0x39: { // CMP rm, r16

            fetch_modrm();
            do_sub(get_ev(), get_rv(), 1);
            break;
        }
        case 0x3A: { // CMP r8, rm

            fetch_modrm();
            do_sub(get_rb(), get_eb(), 0);
            break;
        }
        case 0x3B: { // CMP r16, rm

            fetch_modrm();
            do_sub(get_rv(), get_ev(), 1);
            break;
        }
        case 0x3C: { // CMP al, i8

            do_sub(get_reg8(al), fetch_byte(), 0);
            break;
        }
        case 0x3D: { // CMP ax, i16

            do_sub(get_regv(al), fetch_gv(), 1);
            break;
        }
        case 0x3E: { // DS:
            ud();
            break;
        }
        case 0x3F: { // AAS
            aas();
            break;
        }
        case 0x40:   // INC ax
        case 0x41:   // INC cx
        case 0x42:   // INC dx
        case 0x43:   // INC bx
        case 0x44:   // INC sp
        case 0x45:   // INC bp
        case 0x46:   // INC si
        case 0x47: { // INC di

            t32 = get_cf();
            put_regv(opcode & 7, do_add(get_regv(opcode & 7), 1, 1));
            set_cf(t32);
            break;
        }
        case 0x48:   // DEC ax
        case 0x49:   // DEC cx
        case 0x4A:   // DEC dx
        case 0x4B:   // DEC bx
        case 0x4C:   // DEC sp
        case 0x4D:   // DEC bp
        case 0x4E:   // DEC si
        case 0x4F: { // DEC di

            t32 = get_cf();
            put_regv(opcode & 7, do_sub(get_regv(opcode & 7), 1, 1));
            set_cf(t32);
            break;
        }
        case 0x50:   // PUSH ax
        case 0x51:   // PUSH cx
        case 0x52:   // PUSH dx
        case 0x53:   // PUSH bx
        case 0x54:   // PUSH sp
        case 0x55:   // PUSH bp
        case 0x56:   // PUSH si
        case 0x57: { // PUSH di

            push(get_regv(opcode & 7), opsize);
            break;
        }
        case 0x58:   // POP ax
        case 0x59:   // POP cx
        case 0x5A:   // POP dx
        case 0x5B:   // POP bx
        case 0x5C:   // POP sp
        case 0x5D:   // POP bp
        case 0x5E:   // POP si
        case 0x5F: { // POP di

            put_regv(opcode & 7, pop(opsize));
            break;
        }
        case 0x60: { // PUSHA[D]

            t32 = regs[esp];
            for (int i = 0; i < 8; i++)
                push(i == esp ? t32 : regs[i], opsize);

            break;
        }
        case 0x61: { // POPA[D]

            for (int i = 7; i >= 0; i--) {
                if (i == esp) t32 = pop(opsize);
                else put_regv(i, pop(opsize));
            }
            put_regv(esp, t32);
            break;
        }
        case 0x62: { // BOUND

            ud();
            break;
        }
        case 0x63: { // ARPL

            ud();
            break;
        }
        case 0x64:   // FS:
        case 0x65:   // GS:
        case 0x66:   // opsize:
        case 0x67: { // adsize:

            ud();
            break;
        }
        case 0x68: { // PUSH i16/32

            push(fetch_gv(), opsize);
            break;
        }
        case 0x6A: { // PUSH i16/32

            t32 = fetch_byte();
            if (t32 & 0x80) t32 |= 0xFFFFFF00;
            push(t32, opsize);
            break;
        }
        case 0x70:   // JO b8
        case 0x71:   // JNO b8
        case 0x72:   // JC b8
        case 0x73:   // JNC b8
        case 0x74:   // JZ b8
        case 0x75:   // JNZ b8
        case 0x76:   // JBE b8
        case 0x77:   // JNBE b8
        case 0x78:   // JS b8
        case 0x79:   // JNS b8
        case 0x7A:   // JP b8
        case 0x7B:   // JNP b8
        case 0x7C:   // JL b8
        case 0x7D:   // JNL b8
        case 0x7E:   // JLE b8
        case 0x7F: { // JNLE b8

            t32 = fetch_byte();
            if (condition(opcode & 15)) {
                load_eip(eip + (signed char)t32);
            }

            break;
        }
        case 0x80:   // ALU r8, i8
        case 0x82: { // ALU [алиас]

            fetch_modrm();
            t32 = group_alu(modrm_reg, get_eb(), fetch_byte(), 0);
            if (modrm_reg < 7) put_eb(t32);
            break;
        }
        case 0x81: { // ALU rm, i16

            fetch_modrm();
            t32 = group_alu(modrm_reg, get_ev(), fetch_gv(), 1);
            if (modrm_reg < 7) put_ev(t32);
            break;
        }
        case 0x83: { // ALU rm, signed(i8)

            fetch_modrm();
            t32 = fetch_byte();
            if (t32 & 0x80) t32 |= (opsize ? 0xFFFFFF00 : 0xFF00);
            t32 = group_alu(modrm_reg, get_ev(), t32, 1);
            if (modrm_reg < 7) put_ev(t32);
            break;
        }
        case 0x84: { // TEST rm, r8

            fetch_modrm();
            do_and(get_eb(), get_reg8(modrm_reg), 0);
            break;
        }
        case 0x85: { // TEST rm, r16

            fetch_modrm();
            do_and(get_ev(), get_regv(modrm_reg), 1);
            break;
        }
        case 0x86: { // XCHG rm,r8

            fetch_modrm();
            t32 = get_eb();
            put_eb  (get_reg8(modrm_reg));
            put_reg8(modrm_reg, t32);
            break;
        }
        case 0x87: { // XCHG rm,r16

            fetch_modrm();
            t32 = get_ev();
            put_ev  (get_regv(modrm_reg));
            put_regv(modrm_reg, t32);
            break;
        }
        case 0x88: { // MOV rm, r8

            fetch_modrm();
            put_eb(get_rb());
            break;
        }
        case 0x89: { // MOV rm, r16

            fetch_modrm();
            put_ev(get_rv());
            break;
        }
        case 0x8A: { // MOV r8, rm

            fetch_modrm();
            put_rb(get_eb());
            break;
        }
        case 0x8B: { // MOV r16, rm

            fetch_modrm();
            put_rv(get_ev());
            break;
        }
        case 0x8C: { // MOV w, sreg

            fetch_modrm();
            if (modrm_reg > 5) ud();
            else put_ev(segs[modrm_reg]); break;
            break;
        }
        case 0x8D: { // LEA r16, ea

            fetch_modrm();
            put_rv(ea);
            break;
        }
        case 0x8E: { // MOV sreg, r16

            fetch_modrm();
            noint = 1;
            if (modrm_reg == 1 || modrm_reg > 5) ud();
            else load_seg(modrm_reg, get_ev()); break;
            break;
        }
        case 0x8F: { // POP rm

            fetch_modrm();
            put_ev(pop(1));
            break;
        }
        case 0x90: { // NOP
            break;
        }
        case 0x91:   // XCHG ax, cx
        case 0x92:   // XCHG ax, dx
        case 0x93:   // XCHG ax, bx
        case 0x94:   // XCHG ax, sp
        case 0x95:   // XCHG ax, bp
        case 0x96:   // XCHG ax, si
        case 0x97: { // XCHG ax, di

            t32 = get_regv(opcode & 7);
            put_regv(opcode & 7, regs[eax]);
            put_regv(eax, t32);
            break;
        }
        case 0x98: { // CBW | CWDE

            t32 = regs[eax];

            if (opsize)
                 { if (t32 & 0x8000) t32 |= 0xFFFF0000; else t32 &= 0x0000FFFF; }
            else { if (t32 &   0x80) t32 |= 0xFFFFFF00; else t32 &= 0xFFFF00FF; }

            put_regv(eax, t32);
            break;
        }
        case 0x99: { // CWD | CDQ

            t32 = regs[eax] & (opsize ? 0x80000000 : 0x8000);
            put_regv(edx, t32 ? 0xFFFFFFFF : 0);
            break;
        }
        case 0x9A: { // CALL 16:16/32

            t32 = fetch_gv();
            a32 = fetch_word();
            do_call_far(a32, t32);
            break;
        }
        case 0x9B: { // FWAIT
            break;
        }
        case 0x9C: { // PUSHF

            push((eflags & ~0x2A) | 2, opsize);
            break;
        }
        case 0x9D: { // POPF

            eflags = pop(opsize) & 0xfff;
            break;
        }
        case 0x9E: { // SAHF

            eflags = (eflags & 0xFF00) | ((regs[eax] & 0xFF00) >> 8);
            break;
        }
        case 0x9F: { // LAHF

            put_reg8(ah, eflags);
            break;
        }
        case 0xA0: { // MOV al, [i16/32]

            put_reg8(al, read_byte(get_offset()));
            break;
        }
        case 0xA1: { // MOV ax, [i16/32]

            t32 = get_offset();
            put_regv(ax, opsize ? read_dword(t32) : read_word(t32));
            break;
        }
        case 0xA2: { // MOV [i16/32], al

            write_byte(get_offset(), get_reg8(al));
            break;
        }
        case 0xA3: { // MOV [i16/32], ax

            if (opsize) {
                write_dword(get_offset(), get_regv(eax));
            } else {
                write_word (get_offset(), get_regv(ax));
            }
            break;
        }
        case 0xA8: { // TEST al, i8

            do_and(regs[eax] & 0xFF, fetch_byte(), 0);
            break;
        }
        case 0xA9: { // TEST ax, i16

            do_and(regs[eax], fetch_gv(), 1);
            break;
        }
        case 0xB0:   // MOV al, i8
        case 0xB1:   // MOV cl, i8
        case 0xB2:   // MOV dl, i8
        case 0xB3:   // MOV bl, i8
        case 0xB4:   // MOV ah, i8
        case 0xB5:   // MOV ch, i8
        case 0xB6:   // MOV dh, i8
        case 0xB7: { // MOV bh, i8

            put_reg8(opcode & 7, fetch_byte());
            break;
        }
        case 0xB8:   // MOV ax, i16
        case 0xB9:   // MOV cx, i16
        case 0xBA:   // MOV dx, i16
        case 0xBB:   // MOV bx, i16
        case 0xBC:   // MOV sp, i16
        case 0xBD:   // MOV bp, i16
        case 0xBE:   // MOV si, i16
        case 0xBF: { // MOV di, i16

            put_regv(opcode & 7, fetch_gv());
            break;
        }
        case 0xC0: { // <ROT> rm8, i8

            fetch_modrm();
            t32 = fetch_byte();
            put_eb(groupshift(modrm_reg, 0, get_eb(), t32 & 7));
            break;
        }
        case 0xC1: { // <ROT> rm16, i8

            fetch_modrm();
            t32 = fetch_byte();
            put_ev(groupshift(modrm_reg, 1, get_ev(), t32 & 31));
            break;
        }
        case 0xC2: { // RET imm

            do_ret(fetch_gv());
            break;
        }
        case 0xC3: { // RET

            do_ret(0);
            break;
        }
        case 0xC4:   // LES r16/32, rm
        case 0xC5: { // LDS r16/32, rm

            fetch_modrm();

            a32 = phys_addr(segment, ea);
            t32 = opsize ? read_dword(a32) : read_word(t32);

            put_rv(t32);
            load_seg(opcode & 1 ? ds : es, read_dword(a32 + (opsize ? 4 : 2)));
            break;
        }
        case 0xC6: { // MOV rm, i8

            fetch_modrm();
            put_eb(fetch_byte());
            break;
        }
        case 0xC7: { // MOV rm, i16/32

            fetch_modrm();
            put_ev(fetch_gv());
            break;
        }
        case 0xC8: { // ENTER

            do_enter();
            break;
        }
        case 0xC9: { // LEAVE

            put_reg16(esp, regs[ebp], stack_size);
            put_regv(ebp, pop(opsize));
            break;
        }
        case 0xCA: { // RETF imm

            do_retf(fetch_gv());
            break;
        }
        case 0xCB: { // RETF

            do_retf(0);
            break;
        }
        case 0xCC: { // INT 3

            interrupt(3);
            break;
        }
        case 0xCD: { // INT imm8

            interrupt(fetch_byte());
            break;
        }
        case 0xCE: { // INTO

            if (eflags & O_FLAG) interrupt(4);
            break;
        }
        case 0xCF: { // IRET[D] 
            
            do_iret();            
            break;
        }
        case 0xD0: { // <ROT> rm8, 1

            fetch_modrm();
            put_eb(groupshift(modrm_reg, 0, get_eb(), 1));
            break;
        }
        case 0xD1: { // <ROT> rm16, 1

            fetch_modrm();
            put_ev(groupshift(modrm_reg, 1, get_ev(), 1));
            break;
        }
        case 0xD2: { // <ROT> rm8, CL

            fetch_modrm();
            put_eb(groupshift(modrm_reg, 0, get_eb(), regs[cx] & 7));
            break;
        }
        case 0xD3: { // <ROT> rm16, CL

            fetch_modrm();
            put_ev(groupshift(modrm_reg, 1, get_ev(), regs[cx] & 31));
            break;
        }
        case 0xD4: { // AAM
            aam();
            break;
        }
        case 0xD5: { // AAD
            aad();
            break;
        }
        case 0xD6: { // SALC [SBB AL,AL]
            put_reg8(al, eflags & C_FLAG ? 0xff : 00);
            break;
        }
        case 0xD7: { // XLATB

            t32 = adsize ? regs[ebx] : (regs[ebx] & 0xFFFF);
            put_reg8(al, read_byte(phys_addr(segment, t32 + (regs[eax] & 255))));
            break;
        }
        case 0xD8:
        case 0xD9:
        case 0xDA:
        case 0xDB:
        case 0xDC:
        case 0xDD:
        case 0xDE:
        case 0xDF: { // ESC 0-7
        
            ud();
            break;
        }
        case 0xE0:   // LOOPNZ b8
        case 0xE1:   // LOOPZ b8
        case 0xE2: { // LOOP b8

            a32 = fetch_byte();

            // eCX--
            put_reg16(ecx, regs[ecx] - 1, opsize);

            // Проверить на 0
            if (regs[ecx] & (opsize ? ~0 : 0xFFFF)) {

                switch (opcode) {
                    
                    case 0xE0: if (!(eflags & Z_FLAG)) load_eip(eip + (char)a32); break; // LOOPNZ
                    case 0xE1: if ( (eflags & Z_FLAG)) load_eip(eip + (char)a32); break; // LOOPZ
                    case 0xE2: load_eip(eip + (char)a32); break; // LOOP                   
                }
            }
            
            break;
        }
        case 0xE3: { // JCXZ 

            a32 = fetch_byte();
            if ((regs[ecx] & (opsize ? ~0 : 0xFFFF)) == 0) {
                load_eip(eip + (char)a32); 
            }
            
            break;
        }
        case 0xE4: 
        case 0xEC: { // IN AL, i8|dx
            
            a32 = opcode == 0xEC ? regs[edx] : fetch_byte();
            put_reg8(al, ioread(a32));
            break;            
        }
        case 0xE5: 
        case 0xED: { // IN eAX, i8|dx
            
            a32  = opcode == 0xED ? regs[edx] : fetch_byte();
            t32  =  ioread(a32);
            t32 |= (ioread(a32+1) << 8);
            
            if (opsize) {
                
                t32 |= (ioread(a32+2) << 16);
                t32 |= (ioread(a32+3) << 24);               
            }
            
            put_regv(eax, t32);
            break;
        }
        case 0xE6: 
        case 0xEE: { // OUT i8, AL
            
            a32 = opcode == 0xEE ? regs[edx] : fetch_byte();
            iowrite(a32, regs[eax]);
            break;
        }
        case 0xE7: 
        case 0xEF: { // OUT i8, eAX
            
            a32 = opcode == 0xEF ? regs[edx] : fetch_byte();
            
            iowrite(a32,   regs[eax]);
            iowrite(a32+1, regs[eax] >> 8);
            
            if (opsize) {
                
                iowrite(a32+2, regs[eax] >> 16);
                iowrite(a32+3, regs[eax] >> 24);
            }
            
            break;
        }
        case 0xE8: { // CALL a16
        
            a32 = fetch_gv();
            push(eip, opsize);
            load_eip(eip + a32);
            break;
        }
        case 0xE9: { // JMP a16
            
            a32 = fetch_gv();
            load_eip(eip + a32);
            break;
        }
        case 0xEA: { // JMP FAR 16:16/32

            op1 = fetch_gv();   // Смещение
            op2 = fetch_word(); // Селектор
            do_jmp_far(op2, op1);
            break;
        }
        case 0xEB: { // JMP b8
            
            a32 = fetch_byte();
            load_eip(eip + (char)a32);
            break;
        }
        case 0xF0:   // LOCK:
        case 0xF1: { // INT 1
            
            interrupt(1);
            break;
        }
        case 0xF2:   // REP:
        case 0xF3: { // REPNZ:
            ud();
            break;
        }
        case 0xF4: { // HALT

            eip--;
            halt = 1;
            break;
        }
        case 0xF5: { // CMC

            eflags ^= C_FLAG;
            break;
        }
        case 0xF8: { // CLC

            eflags &= ~C_FLAG;
            break;
        }
        case 0xF9: { // STC

            eflags |= C_FLAG;
            break;
        }
        case 0xFA: { // CLI

            eflags &= ~I_FLAG;
            break;
        }
        case 0xFB: { // STI

            eflags |= I_FLAG;
            break;
        }
        case 0xFC: { // CLD

            eflags &= ~D_FLAG;
            break;
        }
        case 0xFD: { // STD

            eflags |= D_FLAG;
            break;
        }
    }
}