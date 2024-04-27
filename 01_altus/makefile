VLIB=/usr/share/verilator/include

all: ica
ica:
	fasm tb.asm tb.bin
	php tb.php tb.bin tb.hex
	iverilog -g2005-sv -DICARUS=1 -o main.qqq tb.v k86.v
	vvp main.qqq >> /dev/null
apx: vex
	g++ -o tb -I$(VLIB) $(VLIB)/verilated.cpp tb.cc obj_dir/Vvideo__ALL.a -lSDL2
	./tb
vex:
	verilator -cc video.v
	cd obj_dir && make -f Vvideo.mk
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
