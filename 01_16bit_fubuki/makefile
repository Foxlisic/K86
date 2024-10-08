VINC=/usr/share/verilator/include

all: ica tbc
	./tb tb.bin
ica:
	iverilog -g2005-sv -o tb.qqq tb.v core.v
	vvp tb.qqq -o tb.vcd > /dev/null
	rm tb.qqq
tbc:
	verilator --threads 1 -cc core.v
	cd obj_dir && make -f Vcore.mk
	g++ -Ofast -Wno-unused-result -o tb -I$(VINC) tb.cc \
		$(VINC)/verilated.cpp \
		$(VINC)/verilated_threads.cpp \
		obj_dir/Vcore__ALL.a \
		-lSDL2
wav:
	gtkwave tb.gtkw
clean:
	rm -rf tb tb.vcd tb.hex tb.bin obj_dir
