VINC=/usr/share/verilator/include
DIRC=../..

all: com app
com:
	fasm tb.asm tb.com
	fasm $(DIRC)/bios.asm bios.bin
	php $(DIRC)/../tools/mifer.php 64k tb.com $(DIRC)/de0/mif_main.mif bios.bin
app:
	$(DIRC)/tb -c tb.com -b bios.bin -d > tb.log
dos:
	mv tb.com ~/dosbox/MAIN.COM
	dosbox
video:
	ffmpeg -framerate 60 -r 60 -i record.ppm -vf "scale=w=1600:h=1000,pad=width=1920:height=1080:x=160:y=40:color=black" -sws_flags neighbor -sws_dither none -f mp4 -q:v 0 -vcodec mpeg4 -y record.mp4
