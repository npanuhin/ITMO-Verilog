@echo off
iverilog -g2012 -o not_switch.out design.sv testbench.sv && vvp not_switch.out
