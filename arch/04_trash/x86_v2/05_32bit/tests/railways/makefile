FILE=railways.com
all:
	cp $(FILE) ~/dosbox/main.com
	dd if=$(FILE) of=memory.bin bs=1 seek=31744
	php ../../utils/bin2mif.php memory.bin 262144 > ../../de0/memory.mif
	mv memory.bin ../../em
	cd ../../em && ./machine88
