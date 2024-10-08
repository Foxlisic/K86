VINC=/usr/share/verilator/include

all: ica tbc
	./tb tb.bin
ica:
	fasm tb.asm tb.bin
	php tb.php
	php mifer.php 64k tb.bin ../de0/mbios.mif
	iverilog -g2005-sv -o tb.qqq tb.v ../core.v
	vvp tb.qqq -o tb.vcd > vvp.log
	rm tb.qqq
tbc:
	verilator --threads 1 -cc ../core.v
	cd obj_dir && make -f Vcore.mk
	g++ -o tb -I$(VINC) tb.cc \
		$(VINC)/verilated.cpp \
		$(VINC)/verilated_threads.cpp \
		obj_dir/Vcore__ALL.a \
		-lSDL2
wav:
	gtkwave tb.gtkw
