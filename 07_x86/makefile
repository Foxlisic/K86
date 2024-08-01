all:
	iverilog -g2005-sv -DICARUS=1 -o main.qqq main.v
	vvp main.qqq >> /dev/null

wave:
	gtkwave main.vcd

gtkw:
	gtkwave main.gtkw
