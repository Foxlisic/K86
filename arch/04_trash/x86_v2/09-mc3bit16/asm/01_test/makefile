#CWD=.
CWD=$(shell pwd)
CVT=../../../utils/bin2hex.php

all:
	fasm main.asm main.bin
	php $(CVT) $(CWD)/main.bin $(CWD)/../../tb.hex
	