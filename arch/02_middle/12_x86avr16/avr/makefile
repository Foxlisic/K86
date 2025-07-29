# https://gcc.gnu.org/onlinedocs/gcc/AVR-Options.html
DEVICE  = atmega328
OPTIONS = -Os -DF_CPU=25000000 -mmcu=$(DEVICE) -std=c++11
INCLUDE = -I.. -Iinclude
WARNING = -Wall -Wno-unused-but-set-variable
LINKER  = -fdata-sections -Wl,--gc-sections,--defsym=__stack=0x80efff,--defsym=__heap_end=0x80efff
COMPILE = avr-gcc $(INCLUDE) $(WARNING) $(OPTIONS) $(LINKER)
AVR     = avr_machine

all:
	$(COMPILE) main.cc -o main.elf
	avr-objcopy -j .text -j .data -O binary main.elf main.bin
	avr-objdump -S main.elf > main.lst
	avr-size -C --mcu=$(DEVICE) main.elf > mem.map
	rm main.elf
	$(AVR) main.bin

clean:
	rm -f *.o rm *.elf *.lst *.bin *.map
