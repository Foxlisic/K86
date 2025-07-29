#include "machine.h"

void machine::regdump() {

    if (first_regdump)
    printf("+--------------+--------------------------\n");
    printf("| eax=%08x | esp=%08x | cs=%04x | eip=%08x (%08x)\n", regs[eax], regs[esp], segs[cs], eip, phys_addr(cs, eip));
    printf("| ebx=%08x | ebp=%08x | es=%04x | flags=%04x ", regs[ebx], regs[ebp], segs[es], eflags);
    printf("[%c%c%c%c%c%c%c%c%c]\n", 
        eflags&O_FLAG ? 'O' : ' ',
        eflags&D_FLAG ? 'D' : ' ',
        eflags&I_FLAG ? 'I' : ' ',
        eflags&T_FLAG ? 'T' : ' ',
        eflags&S_FLAG ? 'S' : ' ',
        eflags&Z_FLAG ? 'Z' : ' ',
        eflags&A_FLAG ? 'A' : ' ',
        eflags&P_FLAG ? 'P' : ' ',
        eflags&C_FLAG ? 'C' : ' ');
        
    printf("| ecx=%08x | esi=%08x | ds=%04x | fs=%04x\n", regs[ecx], regs[esi], segs[ds], segs[fs]);
    printf("| edx=%08x | edi=%08x | ss=%04x | gs=%04x\n", regs[edx], regs[edi], segs[ss], segs[gs]);
    printf("+--------------+--------------------------\n");
    
    first_regdump = 0;
}
