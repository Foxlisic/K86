VLIB=/usr/share/verilator/include

all: apx
ica:
	iverilog -g2005-sv -DICARUS=1 -o main.qqq tb.v k86.v
	vvp main.qqq >> /dev/null
apx:
	g++ -o tb -I$(VLIB) $(VLIB)/verilated.cpp tb.cc -lSDL2
	./tb
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
