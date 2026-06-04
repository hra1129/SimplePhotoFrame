vlib work
vlog ..\display_timming_generator.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
