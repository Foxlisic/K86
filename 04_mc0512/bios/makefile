all:
	fasm bios.asm bios.bin
	php ../cv.php 4 bios.bin ../de0/bios.mif
	../tb bios.bin
