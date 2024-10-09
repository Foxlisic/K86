VINC=/usr/share/verilator/include
DIRC=../..

all:
	fasm tb.asm tb.com
	php $(DIRC)/../tools/mifer.php 16k tb.com $(DIRC)/de0/mbios.mif
	$(DIRC)/tb -c tb.com -b $(DIRC)/bios.bin -d -v > tb.log
video:
	ffmpeg -framerate 60 -r 60 -i record.ppm -vf "scale=w=1600:h=1000,pad=width=1920:height=1080:x=160:y=40:color=black" -sws_flags neighbor -sws_dither none -f mp4 -q:v 0 -vcodec mpeg4 -y record.mp4
