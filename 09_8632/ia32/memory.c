#define MAX_PHYSMEM     4 * 1024 * 1024

/* Количество памяти 4 Мб */
unsigned char RAM[ MAX_PHYSMEM ];

/* Чтение байта памяти */
unsigned char readb(Uint32 address) {
    
    if (address >= MAX_PHYSMEM) {
        return 0;
    }
    
    return RAM[ address ];
}

/* Чтение слова (16 бит) */
unsigned int readw(Uint32 address) {    
    return readb(address) + (readb(address + 1) << 8);
}

/* Чтение слова (32 бит) */
unsigned int readd(Uint32 address) {    
    return readw(address) + (readw(address + 2) << 16);
}

/* Запись байта */
void writeb(Uint32 address, Uint8 value) {
    if (address < MAX_PHYSMEM) {
        RAM[ address ] = value;
    }
}

/* Запись слова */
void writew(Uint32 address, Uint16 value) {
    
    writeb(address + 0, value & 0xff);
    writeb(address + 1, (value >> 8) & 0xff);
}

/* Запись двойного слова */
void writed(Uint32 address, Uint16 value) {
    
    writew(address + 0, value & 0xffff);
    writew(address + 2, (value >> 16) & 0xffff);
}

/* Чтение из сегмента : адреса */
unsigned int READ(Uint8 w, Uint16 segment, Uint32 address) {
    
    switch (processor_mode) {
        
        /* Real Mode */
        case 0: 
        
            address = segment * 16 + address;
            
            switch (w) {
                case 0: 
                case 8: return readb( address );
                case 16: return readw( address );
                case 32: return readd( address );
            }        
    }   
    
    return 0; 
}

void WRITE(Uint8 w, Uint16 segment, Uint32 address, Uint32 value) {
    
    switch (processor_mode) {
        
        /* Real Mode */
        case 0: 
        
            address = segment * 16 + address;
            
            switch (w) {
                case 0: 
                case 8:  writeb( address, value ); break;
                case 16: writew( address, value ); break;
                case 32: writed( address, value ); break;
            }        
    } 
    
    
}

// Прочитать байт из cs:ip / cs:eip
unsigned int fetchb() {
    
    int fd;
    
    switch (processor_mode) {
        
        /* RM */ 
        case 0: 
        
            fd = cs * 0x10 + (eip & 0xffff);
            eip++; 
            eip &= 0xffff;
            break;
    
    }
    
    return readb( fd );
};

unsigned int fetchw() {
    
    int a = fetchb();
    int b = fetchb();
    return a + b*256;
}

unsigned int fetchd() {

    int a = fetchw();
    int b = fetchw();
    return a + b*65536;

}
