void UD() { 

    printf("UNDEFINED OPCODE!\n");
    
    IP = (IP - 1) & 0xffff;
    pc_regs(); pc_dump(CS*16 + IP); exit(1);    
} 
