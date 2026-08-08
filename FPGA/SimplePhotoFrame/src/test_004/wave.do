onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/test_number
add wave -noupdate -divider {ADDRESS GEN}
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_address_generator/clk
add wave -noupdate -radix unsigned /tb/u_dut/u_display_controller/display_address_generator/ff_h_counter
add wave -noupdate -radix unsigned /tb/u_dut/u_display_controller/display_address_generator/ff_v_counter
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_address_generator/sdram_address
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_address_generator/sdram_address_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_address_generator/sdram_address_ready
add wave -noupdate -divider {FILL COLOR}
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/display_on
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/fill_color
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/in_sdram_address
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/in_sdram_address_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/in_sdram_address_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/sdram_address
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/sdram_address_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/sdram_address_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/sdram_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/sdram_rdata_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/out_data
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/out_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_fillcolor_generator/out_ready
add wave -noupdate -divider {PRELOAD BUFF}
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/in_data
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/in_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/in_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/in_nearly_full
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/out_data
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/out_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_preload_buffer/out_ready
add wave -noupdate -divider {TIMING GEN}
add wave -noupdate /tb/u_dut/u_display_controller/display_timing_generator/frame_end
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_timing_generator/p_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_timing_generator/p_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_display_controller/display_timing_generator/p_data
add wave -noupdate -radix unsigned /tb/u_dut/u_display_controller/display_timing_generator/ff_h_counter
add wave -noupdate -radix unsigned /tb/u_dut/u_display_controller/display_timing_generator/ff_v_counter
add wave -noupdate /tb/u_dut/u_display_controller/display_timing_generator/lcd_ck
add wave -noupdate /tb/u_dut/u_display_controller/display_timing_generator/lcd_hs
add wave -noupdate /tb/u_dut/u_display_controller/display_timing_generator/lcd_vs
add wave -noupdate /tb/u_dut/u_display_controller/display_timing_generator/lcd_de
add wave -noupdate -divider GRP2
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_address
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_write
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_flush
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_rdata
add wave -noupdate -radix hexadecimal /tb/u_dut/u_graphic_processor2/sdram_rdata_valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {250 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 317
configure wave -valuecolwidth 74
configure wave -justifyvalue left
configure wave -signalnamewidth 2
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
WaveRestoreZoom {61182700123 ps} {76834515547 ps}
