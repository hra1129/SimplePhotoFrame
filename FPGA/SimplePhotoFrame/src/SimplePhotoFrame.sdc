//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.02_SP2 (64-bit) 
//Created Time: 2026-04-14 21:33:47

# 入力クロック
create_clock -name clk27m -period 37.03704 -waveform {0 18.518} [get_ports {clk27m}]

# PLL 出力クロック
create_generated_clock -name sysclk    -source [get_ports {clk27m}] -master_clock clk27m -multiply_by 3 -divide_by 1 [get_nets {sysclk}]
create_generated_clock -name serialclk -source [get_ports {clk27m}] -master_clock clk27m -multiply_by 6 -divide_by 1 [get_nets {serialclk}]

# 非同期クロックグループ宣言 → clk1とclk2間の全パスをタイミング除外
set_clock_groups -asynchronous -group [get_clocks {serialclk}] -group [get_clocks {sysclk}]
