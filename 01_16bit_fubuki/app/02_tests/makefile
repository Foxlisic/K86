VINC=/usr/share/verilator/include
DIRC=../..

all:
	fasm tb.asm tb.com
	php $(DIRC)/../tools/mifer.php 16k tb.com $(DIRC)/de0/mbios.mif
	$(DIRC)/tb tb.com
