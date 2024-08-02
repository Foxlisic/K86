if (fasm boot.asm)
then
    
    dd conv=notrunc if=boot.bin of=disk.img bs=512 count=1    
    
    # Основной bios
    fasm ../bios.asm
    
    # Записать sh
    dd conv=notrunc if=../bios.bin of=disk.img bs=512 seek=1   

    # запуск bochs
    bochs -f c.bxrc -q

fi
