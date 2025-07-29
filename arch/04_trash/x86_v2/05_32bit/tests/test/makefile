FILE=unit.com
all:
	fasm unit.asm
	dd if=$(FILE) of=memory.bin bs=512 seek=62
	php ../../utils/bin2mif.php memory.bin 262144 > ../../de0/memory.mif
	mv $(FILE) ~/dosbox/main.com
	mv memory.bin ../../em
	dosbox
	cd ../../em && ./machine88
