all: ica
ica: asm
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v ../c86.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
asm:
	fasm bios.asm bios.bin
	php ../utils/bin2hex.php bios.bin bios.hex
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
