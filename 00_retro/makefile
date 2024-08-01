VLIB=/usr/share/verilator/include

all: ica
ica:
	iverilog -g2005-sv -DICARUS=1 -o app.qqq app.v k8088.v
	vvp app.qqq >> /dev/null
	rm app.qqq
vcd:
	gtkwave app.vcd
wav:
	gtkwave app.gtkw
