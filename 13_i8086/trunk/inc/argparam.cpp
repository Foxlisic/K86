class ArgParam {

protected:

    int     argc;
    char**  argv;

    char    param_romfile [256];
    char    param_floppy  [256];
    int     param_romaddr;
    int     param_dump;
    
public:

    // Парсер параметров запроса
    ArgParam (int _argc, char** _argv) {

        int i;

        argc = _argc;
        argv = _argv;

        // Значения по умолчанию
        strcpy(param_romfile, "bios/rom.bin");
        strcpy(param_floppy,  "floppy.img");
        
        param_romaddr  = 0xF0000;
        param_dump     = 0x00000;

        // Перебор аргументов
        for (i = 0; i < argc; i++) {

            // Задание rombios
            if (strcmp(argv[i], "--rom") == 0) {
                strcpy(param_romfile, argv[++i]);
            }
            // Начало ROM: парсинг 16-разрядного числа
            else if (strcmp(argv[i], "--romaddr") == 0) {
                sscanf(argv[++i], "%x", & param_romaddr);
            }
            // Флоппи-диск
            else if (strcmp(argv[i], "--floppy") == 0) {
                strcpy(param_floppy, argv[++i]);
            }
            // Выдать отладку с адреса
            else if (strcmp(argv[i], "--dump") == 0) {
                sscanf(argv[++i], "%x", & param_dump);            
            }
        }
    }
    
    int   get_romaddr() { return param_romaddr; }
    int   get_dump()    { return param_dump; }
    char* get_romfile() { return param_romfile; }
    char* get_floppy()  { return param_floppy; }
};
