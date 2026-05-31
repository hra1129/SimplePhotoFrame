onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider "System"
add wave -noupdate -radix binary		/tb/clk
add wave -noupdate -radix binary		/tb/reset

add wave -noupdate -divider "LCD Timing"
add wave -noupdate -radix binary		/tb/lcd_ck
add wave -noupdate -radix binary		/tb/lcd_hs
add wave -noupdate -radix binary		/tb/lcd_vs
add wave -noupdate -radix binary		/tb/lcd_de

add wave -noupdate -divider "LCD Data"
add wave -noupdate -radix hexadecimal	/tb/lcd_r
add wave -noupdate -radix hexadecimal	/tb/lcd_g
add wave -noupdate -radix hexadecimal	/tb/lcd_b

add wave -noupdate -divider "Pixel Interface"
add wave -noupdate -radix binary		/tb/p_valid
add wave -noupdate -radix binary		/tb/p_ready
add wave -noupdate -radix hexadecimal	/tb/p_data

add wave -noupdate -divider "DUT Internal"
add wave -noupdate -radix binary		/tb/u_dut/ff_lcd_ck
add wave -noupdate -radix unsigned		/tb/u_dut/ff_h_counter
add wave -noupdate -radix unsigned		/tb/u_dut/ff_v_counter

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
update
