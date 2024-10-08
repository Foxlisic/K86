void preload(int argc, char* argv[]) {
    
    FILE * f;
    
    // Загрузка образа диска
    if (argc == 2) {
        
        disk_file = fopen(argv[1], "r");
        if (disk_file == NULL) { printf("File %s not found\n", argv[1]); exit(1); }
        
        // Установить указатели
        eip        = 0x7C00;
        addr_start = eip;
        cursor_at  = eip;
        
        // Загрузка MBR
        fread(RAM + 0x7C00, 1, 512, disk_file);            
        fclose(disk_file);
        
    } else {
    
        f = fopen("bios.bin", "r");
        if (f == NULL) { printf("bios.bin not found"); exit(1); }        
        fread(RAM, 1, 65536, f);    
        fclose(f);
    }
}
