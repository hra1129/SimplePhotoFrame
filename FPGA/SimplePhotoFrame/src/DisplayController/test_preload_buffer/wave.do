onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/test_number
add wave -noupdate -radix hexadecimal /tb/u_dut/clk
add wave -noupdate -radix hexadecimal /tb/u_dut/reset
add wave -noupdate -radix unsigned /tb/u_dut/in_data
add wave -noupdate -radix hexadecimal /tb/u_dut/in_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/in_ready
add wave -noupdate -radix unsigned /tb/u_dut/out_data
add wave -noupdate -radix hexadecimal /tb/u_dut/out_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/out_ready
add wave -noupdate -radix unsigned /tb/u_dut/ff_wr_ptr
add wave -noupdate -radix unsigned /tb/u_dut/ff_rd_ptr
add wave -noupdate -radix unsigned /tb/u_dut/w_wr_ptr_next
add wave -noupdate -radix unsigned /tb/u_dut/w_rd_ptr_next
add wave -noupdate -radix unsigned /tb/u_dut/w_count
add wave -noupdate -radix hexadecimal /tb/u_dut/w_nearly_full
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_initial_charge
add wave -noupdate -radix hexadecimal /tb/u_dut/w_in_ready
add wave -noupdate -radix hexadecimal /tb/u_dut/w_wr_en
add wave -noupdate -radix hexadecimal /tb/u_dut/w_wr_sram_sel
add wave -noupdate -radix hexadecimal /tb/u_dut/w_wr_addr
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram0_we
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram1_we
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_pipe_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_pipe_sram_sel
add wave -noupdate -radix unsigned /tb/u_dut/ff_sram_data
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_sram_valid
add wave -noupdate -radix unsigned /tb/u_dut/ff_fifo_data
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_fifo_valid
add wave -noupdate -radix hexadecimal /tb/u_dut/w_rd_sram_sel
add wave -noupdate -radix hexadecimal /tb/u_dut/w_rd_addr
add wave -noupdate -radix hexadecimal /tb/u_dut/w_data_exist
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram_can_accept
add wave -noupdate -radix hexadecimal /tb/u_dut/w_do_read_req
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram_conflict
add wave -noupdate -radix hexadecimal /tb/u_dut/w_do_read
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram0_dout
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram1_dout
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram0_addr
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram1_addr
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram_dout
add wave -noupdate -radix hexadecimal /tb/u_dut/w_sram_output
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {265032000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 231
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
WaveRestoreZoom {264688645 ps} {265417778 ps}
