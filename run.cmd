@echo off
iverilog -Wall -g2012 -o result.out testbench.sv && vvp result.out
