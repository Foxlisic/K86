VLIB=/usr/share/verilator/include

all: ica
ica:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v fox86.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
