onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/test_number
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/reset
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/clk
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/clk_serial
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_cs
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_address
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_write
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_valid
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_ready
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_rdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/bus_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/srom0_cs_n
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/srom1_cs_n
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/srom_clk
add wave -noupdate -radix hexadecimal -childformat {{{/tb/u_qspi_rom/srom_sio[3]} -radix hexadecimal} {{/tb/u_qspi_rom/srom_sio[2]} -radix hexadecimal} {{/tb/u_qspi_rom/srom_sio[1]} -radix hexadecimal} {{/tb/u_qspi_rom/srom_sio[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb/u_qspi_rom/srom_sio[3]} {-radix hexadecimal} {/tb/u_qspi_rom/srom_sio[2]} {-radix hexadecimal} {/tb/u_qspi_rom/srom_sio[1]} {-radix hexadecimal} {/tb/u_qspi_rom/srom_sio[0]} {-radix hexadecimal}} /tb/u_qspi_rom/srom_sio
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_bus_ready
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_bus_rdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_bus_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_command_mode
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_rom_address
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_byte_count
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_burst_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_burst_count
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_do_command
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_finish_command
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_serial_mode
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_serial_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_serial_write
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_serial_valid
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/w_serial_ready
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/w_serial_rdata
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/w_serial_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/w_serial_idle
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_srom0_cs_n
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_srom1_cs_n
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_cs_n
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_wait_count
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_wait_count_active
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_command_state
add wave -noupdate -radix hexadecimal /tb/u_qspi_rom/ff_next_command_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {773 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 255
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {822151171 ps} {825041203 ps}
