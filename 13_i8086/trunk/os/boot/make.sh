if (fasm boot.asm) then
dd conv=notrunc if=boot.bin of=../../floppy.img bs=512 count=1
rm boot.bin
cd ../.. && ./i8086 --dump 7e00
fi
