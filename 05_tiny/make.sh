#!/bin/sh

iverilog -g2005-sv -DICARUS=1 -o main.qqq main.v cpu.v regs.v alu.v
vvp main.qqq

# gtkwave main.vcd

echo 'OK'
