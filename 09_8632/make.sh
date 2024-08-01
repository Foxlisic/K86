#!/bin/sh

# Icarus Verilog, аналог GCC -- аналог gcc
iverilog -g2005-sv -DICARUS=1 -o main.qqq main.v cpu.v

# Симулятор -- линковщик
vvp main.qqq >> /dev/null

# Визуализация симуляции
# gtkwave main.vcd

echo 'OK'
