@echo off
iverilog -g2012 -o nand2.out design.sv testbench.sv && vvp nand2.out
