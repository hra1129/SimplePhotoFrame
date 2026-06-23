onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix unsigned /tb/test_number
add wave -noupdate -radix hexadecimal /tb/u_qspi/reset
add wave -noupdate -radix hexadecimal /tb/u_qspi/clk
add wave -noupdate -radix hexadecimal /tb/u_qspi/clk_serial
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_mode
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_write
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_valid
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_ready
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_rdata
add wave -noupdate -radix hexadecimal /tb/u_qspi/serial_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_qspi/qspi_clk
add wave -noupdate -radix hexadecimal -childformat {{{/tb/u_qspi/qspi_sio[3]} -radix hexadecimal} {{/tb/u_qspi/qspi_sio[2]} -radix hexadecimal} {{/tb/u_qspi/qspi_sio[1]} -radix hexadecimal} {{/tb/u_qspi/qspi_sio[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb/u_qspi/qspi_sio[3]} {-radix hexadecimal} {/tb/u_qspi/qspi_sio[2]} {-radix hexadecimal} {/tb/u_qspi/qspi_sio[1]} {-radix hexadecimal} {/tb/u_qspi/qspi_sio[0]} {-radix hexadecimal}} /tb/u_qspi/qspi_sio
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_fifo_mode
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_fifo_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_fifo_write
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_fifo_valid
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_mode
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_wdata
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_write
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_valid
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_ready
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_rdata
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_processing
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_serial_qspi_accepted
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_serial_valid0
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_serial_valid1
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_processing
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_state
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_clk
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_shift_reg
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_hiz
add wave -noupdate -radix hexadecimal /tb/u_qspi/ff_qspi_sio
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1341 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 245
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
WaveRestoreZoom {0 ps} {60834504 ps}
