if (fasm main.asm) then
    mv main.bin ../floppy/dos.sys
    cd .. && ./i8086
fi
