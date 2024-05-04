VLIB=/usr/share/verilator/include

all: ica
ica: fsm
	iverilog -g2005-sv -DICARUS=1 -o main.qqq tb.v core.v
	vvp main.qqq >> /dev/null
fsm:
	fasm tb.asm tb.bin
	php tb.php
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
