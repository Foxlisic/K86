all:
	fasm bios.asm bios.bin
	php ../cv.php 4 bios.bin ../de0/module/bios.mif
	../tb bios.bin
