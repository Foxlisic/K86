FILE=fbird.com
CDIR=../../..

all:
	cp $(FILE) ~/dosbox/main.com
	dd if=$(FILE) of=memory.bin bs=1 seek=31744
	php $(CDIR)/utils/bin2mif.php memory.bin 262144 > $(CDIR)/de0/memory.mif
	mv memory.bin $(CDIR)/em
	cd $(CDIR)/em && ./machine88
