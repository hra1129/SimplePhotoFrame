vlib work
vlog ..\single_port_ram.v
vlog ..\preload_buffer.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
