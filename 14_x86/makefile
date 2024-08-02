all:
	iverilog -g2005-sv -DICARUS=1 cpu.v main.v -o main.qqq
	vvp main.qqq >> /dev/null

wave:
	gtkwave main.vcd

gtk:
	gtkwave wave.gtkw
