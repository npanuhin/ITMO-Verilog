@echo off
iverilog -g2012 -o result.out testbench.sv && vvp result.out
