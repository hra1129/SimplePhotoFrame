vlib work
vlog ..\display_single_port_ram.v
vlog ..\display_preload_buffer.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
