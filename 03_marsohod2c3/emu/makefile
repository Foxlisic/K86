all: xtension
	fasm bios.asm bios.bin
	./emu86 bios.bin > disasm.log
xtension:
	g++ -Ofast -Wno-unused-result main.cpp -g -lSDL2 -o emu86

