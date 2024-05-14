VLIB=/usr/share/verilator/include

all: ica app
	./tb tb.bin
ica:
	fasm tb.asm tb.bin
	php tb.php
	iverilog -g2005-sv -DICARUS=1 -o main.qqq tb.v cpu.v
	vvp main.qqq >> /dev/null
app: com
	g++ -o tb -I${VLIB} ${VLIB}/verilated.cpp tb.cc \
		obj_dir/Vgpu__ALL.a \
		obj_dir/Vkbd__ALL.a \
		obj_dir/Vcpu__ALL.a \
		-lSDL2_mixer -lSDL2
com:
	verilator -cc gpu.v
	verilator -cc cpu.v
	verilator -cc kbd.v
	cd obj_dir && make -f Vgpu.mk
	cd obj_dir && make -f Vcpu.mk
	cd obj_dir && make -f Vkbd.mk
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
