onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix unsigned /tb/test_number
add wave -noupdate -radix hexadecimal /tb/u_dut/reset
add wave -noupdate -radix hexadecimal /tb/u_dut/clk
add wave -noupdate -radix hexadecimal /tb/u_dut/clk_serial
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_cs
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_write
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_address
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/bus_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_cs_n
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_clk
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_mosi
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_miso
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_intr
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_spi_cs_n_pre
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_spi_cs_n
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_state
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_spi_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_spi_write
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_spi_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/spi_rdata_en
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_address
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_send_data_h
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_cs
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_write
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_bus_valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5614 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 182
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
WaveRestoreZoom {0 ps} {429348329 ps}
