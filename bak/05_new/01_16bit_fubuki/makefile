VINC=/usr/share/verilator/include

all: ica tbc

ica:
	fasm bios.asm bios.bin
	fasm test.asm test.bin
	php ../tools/hexer.php bios.bin tb.hex
	iverilog -g2005-sv -o tb.qqq tb.v core.v vidac.v
	vvp tb.qqq -o tb.vcd > /dev/null
	rm tb.qqq
tbc:
	verilator --threads 1 -cc core.v
	verilator --threads 1 -cc vidac.v
	cd obj_dir && make -f Vcore.mk
	cd obj_dir && make -f Vvidac.mk
	g++ -Ofast -Wno-unused-result -o tb -I$(VINC) tb.cc \
		$(VINC)/verilated.cpp \
		$(VINC)/verilated_threads.cpp \
		obj_dir/Vcore__ALL.a \
		obj_dir/Vvidac__ALL.a \
		-lSDL2
	./tb -b bios.bin -c test.bin > tb.log
wav:
	gtkwave tb.gtkw
clean:
	rm -rf tb tb.vcd tb.hex tb.bin obj_dir tb.log test.bin bios.bin
