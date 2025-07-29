if (fasm bios.asm)
then

    dd conv=notrunc if=bios.bin of=bochs/disk.img bs=512 seek=1   
    php hex.php bios.bin > ../init/bios.hex
    cd ..
    sh make.sh
    cd bios/bochs
    
    # Для отладки включить
    bochs -f c.bxrc -q

fi
