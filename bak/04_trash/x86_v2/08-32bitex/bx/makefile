FILES=machine.o alu.o debug.o instr.o cpu.o bx.o

all: $(FILES)
	g++ $(FILES) -lSDL2 -Wall -o bx
	cd asm && make
win: $(FILES)
	g++ $(FILES) -mwindows -lSDL2 -Wall -o bx.exe	
	cd asm && make
%.o: %.cc machine.h font.h
	g++ -c $< -O3 -o $@
clean:
	rm -f bx *.o
