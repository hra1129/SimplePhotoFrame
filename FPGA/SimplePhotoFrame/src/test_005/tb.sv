`timescale 1ns/1ps

module tb;
	localparam real CLK27M_HALF_PERIOD_NS = 1000000000.0 / (27000000.0 * 2.0);
	localparam real SCLK_HALF_NS          = 1000000000.0 / (50000000.0 * 2.0);

	localparam [7:0] IO_DISPLAY  = (0 << 5);
	localparam [7:0] IO_GRAPHIC1 = (1 << 5);
	localparam [7:0] IO_GRAPHIC2 = (2 << 5);
	localparam [7:0] IO_VRAM     = (6 << 5);

	localparam [7:0] IO_VRAM_ADDRESS_L = 8'h00;
	localparam [7:0] IO_VRAM_ADDRESS_H = 8'h01;
	localparam [7:0] IO_VRAM_DATA      = 8'h02;
	localparam [7:0] IO_VRAM_FLUSH     = 8'h03;

	localparam [15:0] C_ROP_PUT = 16'h0000;

	localparam integer DISPLAY_WIDTH  = 800;
	localparam integer DISPLAY_HEIGHT = 480;
	localparam integer DISPLAY_STRIDE = 1024;
	localparam integer MONITOR_WIDTH   = 256;
	localparam integer MONITOR_HEIGHT  = 64;
	localparam integer FRAME_WORDS    = DISPLAY_STRIDE * DISPLAY_HEIGHT;
	localparam integer FRAME0_BASE    = FRAME_WORDS * 0;
	localparam integer FRAME1_BASE    = FRAME_WORDS * 1;
	localparam integer FRAME2_BASE    = FRAME_WORDS * 2;

	localparam integer BAR_WIDTH             = 16;
	localparam integer GP2_STRESS_ITERATIONS = 2;
	localparam integer DISPLAY_SETTLE_FRAMES = 1;
	localparam integer POST_STRESS_FRAMES    = 1;
	localparam integer STALL_LOG_LIMIT       = 32;
	localparam integer SHIFT_SEARCH_MAX      = 64;
	localparam integer BUSY_CLEAR_POLL_LIMIT = 200000;
	localparam integer PHASE_SWEEP_STEPS         = 4;
	localparam integer PHASE_OFFSET_STEP_LCD_CK  = 16;
	localparam integer GP2_BASE_WIDTH            = 525;
	localparam integer GP2_BASE_HEIGHT           = 315;

	reg         clk27m;
	reg         fpga_spi_cs_n;
	reg         fpga_spi_sck;
	reg         fpga_spi_mosi;
	reg [1:0]   button;

	wire        lcd_ck;
	wire        lcd_hs;
	wire        lcd_vs;
	wire        lcd_de;
	wire [4:0]  lcd_r;
	wire [5:0]  lcd_g;
	wire [4:0]  lcd_b;
	wire        lcd_bl;
	wire [7:0]  led;
	wire        fpga_spi_miso;
	wire        fpga_spi_intr;
	wire        i2s_bclk;
	wire        i2s_dout;
	wire        i2s_en;
	wire        i2s_lrck;
	wire        ws2812;
	wire        O_sdram_clk;
	wire        O_sdram_cke;
	wire        O_sdram_cs_n;
	wire        O_sdram_ras_n;
	wire        O_sdram_cas_n;
	wire        O_sdram_wen_n;
	wire [31:0] IO_sdram_dq;
	wire [10:0] O_sdram_addr;
	wire [1:0]  O_sdram_ba;
	wire [3:0]  O_sdram_dqm;

	integer error_count;
	integer stall_event_count;
	integer mismatch_line_count;
	integer mismatch_pixel_count;
	integer line_width_error_count;
	integer frame_count;
	integer active_x;
	integer active_y;
	integer line_stall_count;
	integer first_bad_frame;
	integer first_bad_line;
	integer first_bad_x;
	integer phase_failure_count;
	integer first_failure_phase;
	integer max_stalls_seen;
	integer max_mismatch_lines_seen;
	integer max_mismatch_pixels_seen;
	integer max_line_width_errors_seen;
	integer i;
	reg     in_active_line;
	reg     line_mismatch_seen;
	reg     prev_stall;
	reg     monitor_enable;
	reg     monitor_synced;

	function automatic [15:0] make_bar_color(input integer bar_index, input integer color_phase);
		reg [4:0] red;
		reg [5:0] green;
		reg [4:0] blue;
		integer idx;
	begin
		idx = (bar_index + color_phase) & 63;
		red   = (idx * 3 + 5) & 31;
		green = (idx * 5 + 9) & 63;
		blue  = (idx * 7 + 3) & 31;
		make_bar_color = {red, green, blue};
	end
	endfunction

	function automatic [15:0] expected_display_color(input integer x, input integer y);
	begin
		if( (x < MONITOR_WIDTH) && (y < MONITOR_HEIGHT) ) begin
			expected_display_color = make_bar_color(x / BAR_WIDTH, 0);
		end
		else begin
			expected_display_color = 16'h0000;
		end
	end
	endfunction

	function automatic integer guess_shift(input integer x, input integer y, input [15:0] actual_color);
		integer delta;
	begin
		guess_shift = -1;
		for( delta = 1; delta <= SHIFT_SEARCH_MAX; delta = delta + 1 ) begin
			if( (guess_shift < 0) && (x >= delta) && (actual_color == expected_display_color(x - delta, y)) ) begin
				guess_shift = delta;
			end
		end
	end
	endfunction

	simple_photo_frame u_dut (
		.clk27m         ( clk27m        ),
		.lcd_ck         ( lcd_ck        ),
		.lcd_hs         ( lcd_hs        ),
		.lcd_vs         ( lcd_vs        ),
		.lcd_de         ( lcd_de        ),
		.lcd_r          ( lcd_r         ),
		.lcd_g          ( lcd_g         ),
		.lcd_b          ( lcd_b         ),
		.lcd_bl         ( lcd_bl        ),
		.led            ( led           ),
		.fpga_spi_cs_n  ( fpga_spi_cs_n ),
		.fpga_spi_sck   ( fpga_spi_sck  ),
		.fpga_spi_mosi  ( fpga_spi_mosi ),
		.fpga_spi_miso  ( fpga_spi_miso ),
		.fpga_spi_intr  ( fpga_spi_intr ),
		.i2s_bclk       ( i2s_bclk      ),
		.i2s_dout       ( i2s_dout      ),
		.i2s_en         ( i2s_en        ),
		.i2s_lrck       ( i2s_lrck      ),
		.ws2812         ( ws2812        ),
		.button         ( button        ),
		.O_sdram_clk    ( O_sdram_clk   ),
		.O_sdram_cke    ( O_sdram_cke   ),
		.O_sdram_cs_n   ( O_sdram_cs_n  ),
		.O_sdram_ras_n  ( O_sdram_ras_n ),
		.O_sdram_cas_n  ( O_sdram_cas_n ),
		.O_sdram_wen_n  ( O_sdram_wen_n ),
		.IO_sdram_dq    ( IO_sdram_dq   ),
		.O_sdram_addr   ( O_sdram_addr  ),
		.O_sdram_ba     ( O_sdram_ba    ),
		.O_sdram_dqm    ( O_sdram_dqm   )
	);

	mt48lc2m32b2 u_sdram (
		.Dq   ( IO_sdram_dq   ),
		.Addr ( O_sdram_addr  ),
		.Ba   ( O_sdram_ba    ),
		.Clk  ( O_sdram_clk   ),
		.Cke  ( O_sdram_cke   ),
		.Cs_n ( O_sdram_cs_n  ),
		.Ras_n( O_sdram_ras_n ),
		.Cas_n( O_sdram_cas_n ),
		.We_n ( O_sdram_wen_n ),
		.Dqm  ( O_sdram_dqm   )
	);

	always #(CLK27M_HALF_PERIOD_NS) begin
		clk27m <= ~clk27m;
	end

	task automatic tb_error(input string msg);
	begin
		$display("[TB][ERROR] %s", msg);
		error_count = error_count + 1;
	end
	endtask

	task automatic spi_send_byte;
		input [7:0] data;
		integer bit_index;
	begin
		for( bit_index = 7; bit_index >= 0; bit_index = bit_index - 1 ) begin
			fpga_spi_mosi = data[bit_index];
			#(SCLK_HALF_NS);
			fpga_spi_sck = 1'b1;
			#(SCLK_HALF_NS);
			fpga_spi_sck = 1'b0;
		end
		#80;
	end
	endtask

	task automatic spi_transfer_byte;
		input [7:0] tx_data;
		output [7:0] rx_data;
		input bit wait_for_intr;
		integer bit_index;
	begin
		rx_data = 8'h00;
		if( wait_for_intr ) begin
			if( fpga_spi_intr !== 1'b1 ) begin
				fork
					begin : wait_intr_edge
						@(posedge fpga_spi_intr);
					end
					begin : wait_intr_timeout
						#50000;
						tb_error("fpga_spi_intr wait timeout");
						$stop;
					end
				join_any
				disable fork;
			end
		end
		for( bit_index = 7; bit_index >= 0; bit_index = bit_index - 1 ) begin
			fpga_spi_mosi = tx_data[bit_index];
			#(SCLK_HALF_NS);
			fpga_spi_sck = 1'b1;
			rx_data[bit_index] = fpga_spi_miso;
			#(SCLK_HALF_NS);
			fpga_spi_sck = 1'b0;
		end
		#80;
	end
	endtask

	task automatic spi_wait_ready;
		input [7:0] address;
		reg [7:0] status;
		reg [7:0] dummy_rx;
		integer busy_retry;
	begin
		busy_retry = 0;
		while( 1 ) begin
			fpga_spi_cs_n = 1'b0;
			#100;
			spi_transfer_byte(8'h03, dummy_rx, 1'b0);
			spi_transfer_byte(address, dummy_rx, 1'b0);
			spi_transfer_byte(8'h00, status, 1'b1);
			fpga_spi_cs_n = 1'b1;
			#100;
			if( status[0] ) begin
				break;
			end
			busy_retry = busy_retry + 1;
			if( busy_retry > 1000 ) begin
				tb_error($sformatf("busy wait timeout at address %02h", address));
				$stop;
			end
		end
	end
	endtask

	task automatic spi_write16;
		input [7:0] address;
		input [15:0] data;
	begin
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		#100;
		spi_wait_ready(address);
		fpga_spi_cs_n = 1'b0;
		#100;
		spi_send_byte(8'h01);
		spi_send_byte(address);
		spi_send_byte(data[7:0]);
		spi_send_byte(data[15:8]);
		#100;
		fpga_spi_cs_n = 1'b1;
		#100;
	end
	endtask

	task automatic spi_read16;
		input [7:0] address;
		output [15:0] data;
		reg [7:0] data_l;
		reg [7:0] data_h;
		reg [7:0] dummy_rx;
	begin
		data = 16'h0000;
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		#100;
		spi_wait_ready(address);
		fpga_spi_cs_n = 1'b0;
		#100;
		spi_transfer_byte(8'h02, dummy_rx, 1'b0);
		spi_transfer_byte(address, dummy_rx, 1'b0);
		spi_transfer_byte(8'h00, data_l, 1'b1);
		spi_transfer_byte(8'h00, data_h, 1'b1);
		#100;
		fpga_spi_cs_n = 1'b1;
		#100;
		data = {data_h, data_l};
	end
	endtask

	task automatic wait_busy_clear;
		input [7:0] io_address;
		input string name;
		logic [15:0] status;
		integer poll_count;
	begin
		poll_count = 0;
		forever begin
			spi_read16(io_address, status);
			if( status[0] == 1'b0 ) begin
				break;
			end
			poll_count = poll_count + 1;
			if( (poll_count % 20000) == 0 ) begin
				$display(
					"[TB][WAIT] %s busy poll=%0d state_g1=%0d state_g2=%0d bs_read_stall=%b bs_write_stall=%b",
					name,
					poll_count,
					u_dut.u_graphic_processor1.ff_state,
					u_dut.u_graphic_processor2.ff_state,
					u_dut.u_bus_selector.ff_read_stall,
					u_dut.u_bus_selector.ff_write_stall
				);
			end
			if( poll_count > BUSY_CLEAR_POLL_LIMIT ) begin
				tb_error($sformatf("wait_busy_clear timeout for %s", name));
				$stop;
			end
		end
	end
	endtask

	task automatic wait_display_frames(input integer frame_num);
		integer frame_idx;
	begin
		for( frame_idx = 0; frame_idx < frame_num; frame_idx = frame_idx + 1 ) begin
			@(posedge u_dut.u_display_controller.display_timing_generator.frame_end);
		end
	end
	endtask

	task automatic wait_lcd_ck_rise_cycles(input integer cycle_num);
		integer count;
	begin
		count = 0;
		while( count < cycle_num ) begin
			@(posedge u_dut.u_display_controller.clk);
			if( u_dut.u_display_controller.display_timing_generator.w_lcd_ck_rise ) begin
				count = count + 1;
			end
		end
	end
	endtask

	task automatic display_enable(input bit enable);
	begin
		spi_write16(IO_DISPLAY | 8'h02, enable ? 16'h0001 : 16'h0000);
	end
	endtask

	task automatic display_set_frame_address(input [31:0] address);
	begin
		spi_write16(IO_DISPLAY | 8'h00, address[15:0]);
		spi_write16(IO_DISPLAY | 8'h01, address[21:16]);
	end
	endtask

	task automatic vram_read(input [31:0] address, output [15:0] data);
	begin
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_L, address[15:0]);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_H, {9'h000, address[22:16]});
		spi_read16(IO_VRAM | IO_VRAM_DATA, data);
	end
	endtask

	task automatic graphic1_set_frame_address(input [31:0] address);
	begin
		spi_write16(IO_GRAPHIC1 | 8'h07, address[15:0]);
		spi_write16(IO_GRAPHIC1 | 8'h08, address[21:16]);
	end
	endtask

	task automatic graphic2_set_source_frame_address(input [31:0] address);
	begin
		spi_write16(IO_GRAPHIC2 | 8'h0A, address[15:0]);
		spi_write16(IO_GRAPHIC2 | 8'h0B, address[21:16]);
	end
	endtask

	task automatic graphic2_set_destination_frame_address(input [31:0] address);
	begin
		spi_write16(IO_GRAPHIC2 | 8'h0C, address[15:0]);
		spi_write16(IO_GRAPHIC2 | 8'h0D, address[21:16]);
	end
	endtask

	task automatic graphic1_fill_rectangle(
		input [15:0] sx,
		input [15:0] sy,
		input [15:0] width,
		input [15:0] height,
		input [15:0] color,
		input [15:0] rop
	);
	begin
		wait_busy_clear(IO_GRAPHIC1 | 8'h06, "graphic1");
		spi_write16(IO_GRAPHIC1 | 8'h00, sx);
		spi_write16(IO_GRAPHIC1 | 8'h01, sy);
		spi_write16(IO_GRAPHIC1 | 8'h02, width);
		spi_write16(IO_GRAPHIC1 | 8'h03, height);
		spi_write16(IO_GRAPHIC1 | 8'h04, color);
		spi_write16(IO_GRAPHIC1 | 8'h05, rop);
		spi_write16(IO_GRAPHIC1 | 8'h06, 16'h0001);
		wait_busy_clear(IO_GRAPHIC1 | 8'h06, "graphic1");
	end
	endtask

	task automatic graphic2_block_copy(
		input [15:0] sx,
		input [15:0] sy,
		input [15:0] swidth,
		input [15:0] sheight,
		input [15:0] dx,
		input [15:0] dy,
		input [15:0] dwidth,
		input [15:0] dheight,
		input [15:0] rop
	);
	begin
		wait_busy_clear(IO_GRAPHIC2 | 8'h09, "graphic2");
		spi_write16(IO_GRAPHIC2 | 8'h00, sx);
		spi_write16(IO_GRAPHIC2 | 8'h01, sy);
		spi_write16(IO_GRAPHIC2 | 8'h02, swidth);
		spi_write16(IO_GRAPHIC2 | 8'h03, sheight);
		spi_write16(IO_GRAPHIC2 | 8'h04, dx);
		spi_write16(IO_GRAPHIC2 | 8'h05, dy);
		spi_write16(IO_GRAPHIC2 | 8'h06, dwidth);
		spi_write16(IO_GRAPHIC2 | 8'h07, dheight);
		spi_write16(IO_GRAPHIC2 | 8'h08, rop);
		spi_write16(IO_GRAPHIC2 | 8'h09, 16'h0001);
		wait_busy_clear(IO_GRAPHIC2 | 8'h09, "graphic2");
	end
	endtask

	task automatic fill_vertical_bar_frame(input [31:0] frame_address, input integer color_phase);
		integer bar_x;
	begin
		$display("[TB] Fill vertical bar frame base=%0d phase=%0d", frame_address, color_phase);
		graphic1_set_frame_address(frame_address);
		for( bar_x = 0; bar_x < MONITOR_WIDTH; bar_x = bar_x + BAR_WIDTH ) begin
			graphic1_fill_rectangle(
				bar_x[15:0],
				16'd0,
				BAR_WIDTH[15:0],
				MONITOR_HEIGHT[15:0],
				make_bar_color(bar_x / BAR_WIDTH, color_phase),
				C_ROP_PUT
			);
		end
	end
	endtask

	task automatic fill_solid_frame(input [31:0] frame_address, input [15:0] color);
	begin
		$display("[TB] Fill solid frame base=%0d color=%04h", frame_address, color);
		graphic1_set_frame_address(frame_address);
		graphic1_fill_rectangle(16'd0, 16'd0, DISPLAY_STRIDE[15:0], DISPLAY_HEIGHT[15:0], color, C_ROP_PUT);
	end
	endtask

	task automatic init_monitor_state;
	begin
		stall_event_count = 0;
		mismatch_line_count = 0;
		mismatch_pixel_count = 0;
		line_width_error_count = 0;
		frame_count = 0;
		active_x = 0;
		active_y = 0;
		line_stall_count = 0;
		first_bad_frame = -1;
		first_bad_line = -1;
		first_bad_x = -1;
		in_active_line = 1'b0;
		line_mismatch_seen = 1'b0;
		prev_stall = 1'b0;
		monitor_synced = 1'b0;
	end
	endtask

	task automatic run_gp2_stress;
		integer iter;
	begin
		$display("[TB] Start GP2 block-copy stress");
		for( iter = 0; iter < GP2_STRESS_ITERATIONS; iter = iter + 1 ) begin
			$display(
				"[TB] GP2 iter=%0d sx=%0d sy=%0d sw=%0d sh=%0d dx=%0d dy=%0d dw=%0d dh=%0d",
				iter, 0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT, 0, 0, GP2_BASE_WIDTH, GP2_BASE_HEIGHT
			);
			graphic2_block_copy(
				16'd0, 16'd0, DISPLAY_WIDTH[15:0], DISPLAY_HEIGHT[15:0],
				16'd0, 16'd0, GP2_BASE_WIDTH[15:0], GP2_BASE_HEIGHT[15:0],
				C_ROP_PUT
			);
		end
		$display("[TB] GP2 block-copy stress done");
	end
	endtask

	task automatic run_phase_case(
		input integer phase_id,
		input integer offset_lcd_ck
	);
	begin
		$display("[TB][PHASE] start id=%0d offset_lcd_ck=%0d", phase_id, offset_lcd_ck);
		init_monitor_state();
		wait_display_frames(1);
		monitor_enable = 1'b1;
		wait_lcd_ck_rise_cycles(offset_lcd_ck);

		run_gp2_stress();
		wait_display_frames(POST_STRESS_FRAMES);
		monitor_enable = 1'b0;

		$display(
			"[TB][PHASE] result id=%0d offset_lcd_ck=%0d stalls=%0d mismatch_lines=%0d mismatch_pixels=%0d line_width_errors=%0d first_bad_frame=%0d first_bad_line=%0d first_bad_x=%0d",
			phase_id,
			offset_lcd_ck,
			stall_event_count,
			mismatch_line_count,
			mismatch_pixel_count,
			line_width_error_count,
			first_bad_frame,
			first_bad_line,
			first_bad_x
		);

		if( stall_event_count > max_stalls_seen ) begin
			max_stalls_seen = stall_event_count;
		end
		if( mismatch_line_count > max_mismatch_lines_seen ) begin
			max_mismatch_lines_seen = mismatch_line_count;
		end
		if( mismatch_pixel_count > max_mismatch_pixels_seen ) begin
			max_mismatch_pixels_seen = mismatch_pixel_count;
		end
		if( line_width_error_count > max_line_width_errors_seen ) begin
			max_line_width_errors_seen = line_width_error_count;
		end

		if( (stall_event_count != 0) || (mismatch_line_count != 0) || (line_width_error_count != 0) ) begin
			phase_failure_count = phase_failure_count + 1;
			if( first_failure_phase < 0 ) begin
				first_failure_phase = phase_id;
			end
			tb_error($sformatf("phase failure id=%0d offset_lcd_ck=%0d", phase_id, offset_lcd_ck));
		end
	end
	endtask

	always @(posedge u_dut.u_display_controller.clk) begin
		reg [15:0] expected_color;
		reg [15:0] actual_color;
		integer shift_guess_value;

		if( monitor_enable ) begin
			if( u_dut.u_display_controller.display_timing_generator.frame_end ) begin
				frame_count <= frame_count + 1;
				if( !monitor_synced ) begin
					monitor_synced <= 1'b1;
					active_x <= 0;
					active_y <= 0;
					in_active_line <= 1'b0;
				end
			end

			if( !monitor_synced ) begin
				prev_stall <= u_dut.u_display_controller.display_timing_generator.w_stall;
			end
			else begin

				if( u_dut.u_display_controller.display_timing_generator.w_stall && !prev_stall ) begin
					stall_event_count <= stall_event_count + 1;
					line_stall_count <= line_stall_count + 1;
					if( stall_event_count < STALL_LOG_LIMIT ) begin
						$display(
							"[TB][STALL] frame=%0d line=%0d x=%0d fifo_count=%0d init_charge=%b p_valid=%b p_ready=%b disp_vr=%b/%b gp2_vr=%b/%b gp2_state=%0d bs_read_stall=%b bs_write_stall=%b",
							frame_count,
							active_y,
							active_x,
							u_dut.u_display_controller.display_preload_buffer.ff_count,
							u_dut.u_display_controller.display_preload_buffer.ff_initial_charge,
							u_dut.u_display_controller.p_valid,
							u_dut.u_display_controller.p_ready,
							u_dut.w_sdram_display_address_valid,
							u_dut.w_sdram_display_address_ready,
							u_dut.w_sdram2_valid,
							u_dut.w_sdram2_ready,
							u_dut.u_graphic_processor2.ff_state,
							u_dut.u_bus_selector.ff_read_stall,
							u_dut.u_bus_selector.ff_write_stall
						);
					end
				end

				prev_stall <= u_dut.u_display_controller.display_timing_generator.w_stall;

				if( u_dut.u_display_controller.display_timing_generator.w_lcd_ck_rise ) begin
					if( lcd_de ) begin
						if( !in_active_line ) begin
							in_active_line <= 1'b1;
							active_x <= 0;
							line_stall_count <= 0;
							line_mismatch_seen <= 1'b0;
						end

						expected_color = expected_display_color(active_x, active_y);
						actual_color = {lcd_r, lcd_g, lcd_b};
						if( actual_color !== expected_color ) begin
							mismatch_pixel_count <= mismatch_pixel_count + 1;
							if( !line_mismatch_seen ) begin
								line_mismatch_seen <= 1'b1;
								mismatch_line_count <= mismatch_line_count + 1;
								shift_guess_value = guess_shift(active_x, active_y, actual_color);
								if( first_bad_frame < 0 ) begin
									first_bad_frame <= frame_count;
									first_bad_line <= active_y;
									first_bad_x <= active_x;
								end
								$display(
									"[TB][MISMATCH] frame=%0d line=%0d x=%0d expected=%04h got=%04h shift_guess=%0d fifo_count=%0d stalls_on_line=%0d",
									frame_count,
									active_y,
									active_x,
									expected_color,
									actual_color,
									shift_guess_value,
									u_dut.u_display_controller.display_preload_buffer.ff_count,
									line_stall_count
								);
							end
						end
						active_x <= active_x + 1;
					end
					else if( in_active_line ) begin
						if( active_x != DISPLAY_WIDTH ) begin
							line_width_error_count <= line_width_error_count + 1;
							$display("[TB][LINE] frame=%0d line=%0d active_pixels=%0d", frame_count, active_y, active_x);
						end
						in_active_line <= 1'b0;
						active_x <= 0;
						if( active_y == (DISPLAY_HEIGHT - 1) ) begin
							active_y <= 0;
						end
						else begin
							active_y <= active_y + 1;
						end
					end
				end
			end
		end
		else begin
			prev_stall <= 1'b0;
		end
	end

	initial begin
		clk27m = 1'b0;
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		fpga_spi_mosi = 1'b0;
		button = 2'b11;
		error_count = 0;
		monitor_enable = 1'b0;
		phase_failure_count = 0;
		first_failure_phase = -1;
		max_stalls_seen = 0;
		max_mismatch_lines_seen = 0;
		max_mismatch_pixels_seen = 0;
		max_line_width_errors_seen = 0;
		init_monitor_state();

		#2000;

		$display("[TB] Configure frame addresses");
		display_set_frame_address(FRAME0_BASE);
		graphic2_set_source_frame_address(FRAME1_BASE);
		graphic2_set_destination_frame_address(FRAME2_BASE);

		fill_solid_frame(FRAME0_BASE, 16'h0000);
		fill_vertical_bar_frame(FRAME0_BASE, 0);
		fill_solid_frame(FRAME1_BASE, 16'h07E0);
		fill_solid_frame(FRAME2_BASE, 16'hF800);

		$display("[TB] Enable display");
		display_enable(1'b1);
		wait_display_frames(DISPLAY_SETTLE_FRAMES);

		$display("[TB] Arm LCD corruption monitor");
		for( i = 0; i < PHASE_SWEEP_STEPS; i = i + 1 ) begin
			run_phase_case(i, i * PHASE_OFFSET_STEP_LCD_CK);
		end

		$display(
			"[TB] Sweep Summary: phases=%0d failed_phases=%0d first_failed_phase=%0d max_stalls=%0d max_mismatch_lines=%0d max_mismatch_pixels=%0d max_line_width_errors=%0d",
			PHASE_SWEEP_STEPS,
			phase_failure_count,
			first_failure_phase,
			max_stalls_seen,
			max_mismatch_lines_seen,
			max_mismatch_pixels_seen,
			max_line_width_errors_seen
		);

		$display(
			"[TB] Summary: phases=%0d failed=%0d first_failed_phase=%0d",
			PHASE_SWEEP_STEPS,
			phase_failure_count,
			first_failure_phase
		);

		if( error_count != 0 ) begin
			$fatal(1);
		end

		$display("[TB] Finish.");
		$finish;
	end
endmodule
