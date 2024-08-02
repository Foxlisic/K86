all:
	php valuegen.php > params.asm
	fasm main.asm
	dd if=main.com of=memory.bin bs=1 seek=31744
	php ../../utils/bin2mif.php main.com 262144 > ../../de0/memory.mif
	mv main.com ~/dosbox
	mv memory.bin ../../em
	cd ../../em && ./machine88
