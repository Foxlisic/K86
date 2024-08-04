VLIB=/usr/share/verilator/include

all: ica
ica:
	fasm boot.asm boot.bin
	php boot.php
	rm boot.bin
	iverilog -g2005-sv -DICARUS=1 -o app.qqq app.v k8088.v
	vvp app.qqq >> /dev/null
	rm app.qqq
vcd:
	gtkwave app.vcd
wav:
	gtkwave app.gtkw
