BIN2MIF=php ../../../utils/bin2mif.php
MACHINE=../../../bx/machine88
DE0=../../de0

all:
	php valuegen.php > params.asm
	fasm main.asm bios.bin
	$(BIN2MIF) bios.bin 32768 > $(DE0)/bios.mif
	$(MACHINE)
