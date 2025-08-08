all:
	fasm bios.asm
	php hexer.php bios.bin > ../bios.hex
	cd .. && make
