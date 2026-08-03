`timescale 1ns/1ps

module tb;
	localparam integer IMG_WIDTH = 800 / 16;
	localparam integer IMG_HEIGHT = 480;
	localparam integer MAX_CYCLES = 12_000_000;
	localparam [15:0] EXPECT_FILL_COLOR = 16'hF800;
	localparam integer SDRAM_READ_LATENCY = 4;
	localparam integer SDRAM_BURST_WORDS = 8;
	localparam [1:0] C_SDRAM_IDLE = 2'd0;
	localparam [1:0] C_SDRAM_WAIT = 2'd1;
	localparam [1:0] C_SDRAM_BURST = 2'd2;

	reg				clk;
	reg				reset;
	reg				sdram_init_busy;
	reg				bus_cs;
	reg		[4:0]	bus_address;
	reg				bus_valid;
	wire			bus_ready;
	reg				bus_write;
	reg		[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;
	wire			lcd_ck;
	wire			lcd_hs;
	wire			lcd_vs;
	wire			lcd_de;
	wire	[4:0]	lcd_r;
	wire	[5:0]	lcd_g;
	wire	[4:0]	lcd_b;
	wire			lcd_bl;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	reg				sdram_address_ready;
	reg		[31:0]	sdram_rdata;
	reg				sdram_rdata_valid;

	reg		[1:0]	sdram_state;
	reg		[22:5]	sdram_burst_base_addr;
	reg		[3:0]	sdram_wait_count;
	reg		[2:0]	sdram_burst_count;
	reg				sdram_accept_pulse;

	integer			cycle_count;
	integer			frame_count;
	integer			first_fifo_sample_count;

	reg				switched_to_on_in_frame1;
	reg				switched_to_off_in_frame2;
	reg				switched_to_on_in_frame3;

	reg				checked_frame1;
	reg				checked_frame2;
	reg				checked_frame3;
	reg				checked_frame4;

	reg				captured_frame4_first_address;
	reg		[22:5]	frame4_first_address;
	reg				prev_timing_origin;

	display_controller dut (
		.clk					( clk					),
		.reset					( reset					),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.lcd_ck					( lcd_ck				),
		.lcd_hs					( lcd_hs				),
		.lcd_vs					( lcd_vs				),
		.lcd_de					( lcd_de				),
		.lcd_r					( lcd_r					),
		.lcd_g					( lcd_g					),
		.lcd_b					( lcd_b					),
		.lcd_bl					( lcd_bl				),
		.sdram_address			( sdram_address			),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
	);

	always #5 clk = ~clk;

	function automatic [31:0] f_sdram_pattern;
		input [22:5] addr;
		begin
			f_sdram_pattern = {addr, 14'h2A5};
		end
	endfunction

	task automatic check_ok;
		input condition;
		input [255:0] message;
		begin
			if( !condition ) begin
				$display("[TB][ERROR] %0s", message);
				$finish(1);
			end
		end
	endtask

	task automatic bus_write16;
		input [4:0] addr;
		input [15:0] data;
		integer timeout;
		begin
			@(negedge clk);
			bus_address <= addr;
			bus_wdata <= data;
			bus_write <= 1'b1;
			bus_valid <= 1'b1;

			timeout = 0;
			while( !bus_ready ) begin
				@(posedge clk);
				timeout = timeout + 1;
				if( timeout > 100 ) begin
					$display("[TB][ERROR] bus_write timeout addr=%0d", addr);
					$finish(1);
				end
			end

			@(negedge clk);
			bus_valid <= 1'b0;
			bus_write <= 1'b0;
		end
	endtask

	always @(posedge clk) begin
		if( reset ) begin
			sdram_address_ready <= 1'b1;
			sdram_rdata_valid <= 1'b0;
			sdram_rdata <= 32'd0;
			sdram_state <= C_SDRAM_IDLE;
			sdram_burst_base_addr <= 18'd0;
			sdram_wait_count <= 4'd0;
			sdram_burst_count <= 3'd0;
			sdram_accept_pulse <= 1'b0;
		end
		else begin
			sdram_rdata_valid <= 1'b0;
			sdram_accept_pulse <= 1'b0;

			case( sdram_state )
				C_SDRAM_IDLE: begin
					sdram_address_ready <= 1'b1;
					sdram_burst_count <= 3'd0;
					if( sdram_address_valid && sdram_address_ready ) begin
						sdram_burst_base_addr <= sdram_address;
						sdram_wait_count <= SDRAM_READ_LATENCY[3:0];
						sdram_address_ready <= 1'b0;
						sdram_accept_pulse <= 1'b1;
						sdram_state <= C_SDRAM_WAIT;
					end
				end

				C_SDRAM_WAIT: begin
					sdram_address_ready <= 1'b0;
					if( sdram_wait_count != 4'd0 ) begin
						sdram_wait_count <= sdram_wait_count - 4'd1;
					end
					else begin
						sdram_state <= C_SDRAM_BURST;
					end
				end

				C_SDRAM_BURST: begin
					sdram_address_ready <= 1'b0;
					sdram_rdata_valid <= 1'b1;
					sdram_rdata <= f_sdram_pattern(sdram_burst_base_addr + {{15{1'b0}}, sdram_burst_count});
					if( sdram_burst_count == (SDRAM_BURST_WORDS - 1) ) begin
						sdram_state <= C_SDRAM_IDLE;
						sdram_address_ready <= 1'b1;
						sdram_burst_count <= 3'd0;
					end
					else begin
						sdram_burst_count <= sdram_burst_count + 3'd1;
					end
				end

				default: begin
					sdram_state <= C_SDRAM_IDLE;
					sdram_address_ready <= 1'b1;
				end
			endcase
		end
	end

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		sdram_init_busy = 1'b0;
		bus_cs = 1'b1;
		bus_address = 5'd0;
		bus_valid = 1'b0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
		sdram_address_ready = 1'b1;
		sdram_rdata = 32'd0;
		sdram_rdata_valid = 1'b0;
		sdram_state = C_SDRAM_IDLE;
		sdram_burst_base_addr = 18'd0;
		sdram_wait_count = 4'd0;
		sdram_burst_count = 3'd0;
		sdram_accept_pulse = 1'b0;
		cycle_count = 0;
		frame_count = 0;
		first_fifo_sample_count = 0;
		switched_to_on_in_frame1 = 1'b0;
		switched_to_off_in_frame2 = 1'b0;
		switched_to_on_in_frame3 = 1'b0;
		checked_frame1 = 1'b0;
		checked_frame2 = 1'b0;
		checked_frame3 = 1'b0;
		checked_frame4 = 1'b0;
		captured_frame4_first_address = 1'b0;
		frame4_first_address = 18'd0;
		prev_timing_origin = 1'b0;

		// Focus this test on frame/address behavior without FIFO backpressure.
		force dut.fifo_full = 1'b0;

		repeat(3) @(posedge clk);
		reset = 1'b0;

		while( (frame_count < 4 || !checked_frame4 || !captured_frame4_first_address) && cycle_count < MAX_CYCLES ) begin
			@(posedge clk);
			#1;
			cycle_count = cycle_count + 1;

			if( (dut.display_timing_generator.ff_h_counter == 0) &&
			    (dut.display_timing_generator.ff_v_counter == 0) ) begin
				if( !prev_timing_origin ) begin
					frame_count = frame_count + 1;
					first_fifo_sample_count = 0;
					$display("[TB] frame_start=%0d cycle=%0d ff_display_on=%0d",
						frame_count,
						cycle_count,
						dut.display_address_generator.ff_display_on);
				end
				prev_timing_origin = 1'b1;
			end
			else begin
				prev_timing_origin = 1'b0;
			end

			if( frame_count == 1 && !switched_to_on_in_frame1 &&
			    dut.display_address_generator.w_valid &&
			    (dut.display_address_generator.ff_v_counter == IMG_HEIGHT/2) &&
			    (dut.display_address_generator.ff_h_counter == IMG_WIDTH/2) ) begin
				$display("[TB] write display_on=1 in frame1 at cycle=%0d", cycle_count);
				bus_write16(5'd2, 16'h0001);
				switched_to_on_in_frame1 = 1'b1;
			end

			if( frame_count == 2 && !switched_to_off_in_frame2 &&
			    dut.display_address_generator.w_valid &&
			    (dut.display_address_generator.ff_v_counter == IMG_HEIGHT/2) &&
			    (dut.display_address_generator.ff_h_counter == IMG_WIDTH/2) ) begin
				$display("[TB] write display_on=0 in frame2 at cycle=%0d", cycle_count);
				bus_write16(5'd2, 16'h0000);
				switched_to_off_in_frame2 = 1'b1;
			end

			if( frame_count == 3 && !switched_to_on_in_frame3 &&
			    dut.display_address_generator.w_valid &&
			    (dut.display_address_generator.ff_v_counter == IMG_HEIGHT/2) &&
			    (dut.display_address_generator.ff_h_counter == IMG_WIDTH/2) ) begin
				$display("[TB] write display_on=1 in frame3 at cycle=%0d", cycle_count);
				bus_write16(5'd2, 16'h0001);
				switched_to_on_in_frame3 = 1'b1;
			end

			if( sdram_accept_pulse && frame_count == 4 && !captured_frame4_first_address ) begin
				captured_frame4_first_address = 1'b1;
				frame4_first_address = sdram_burst_base_addr;
				$display("[TB] frame4 first accepted SDRAM address = %0d", sdram_burst_base_addr);
			end

			if( dut.fifo_valid && (frame_count >= 1) && (frame_count <= 4) ) begin
				if( first_fifo_sample_count == 0 ) begin
					first_fifo_sample_count = 1;
					$display("[TB] frame=%0d first fifo_wdata=%h", frame_count, dut.fifo_wdata);

					case( frame_count )
						1: begin
							check_ok(dut.fifo_wdata == {EXPECT_FILL_COLOR, EXPECT_FILL_COLOR}, "frame1_not_fill_color");
							checked_frame1 = 1'b1;
						end
						2: begin
							check_ok(dut.fifo_wdata == sdram_rdata, "frame2_not_dram_data");
							check_ok(dut.fifo_wdata != {EXPECT_FILL_COLOR, EXPECT_FILL_COLOR}, "frame2_unexpected_fill_color");
							checked_frame2 = 1'b1;
						end
						3: begin
							check_ok(dut.fifo_wdata == {EXPECT_FILL_COLOR, EXPECT_FILL_COLOR}, "frame3_not_fill_color");
							checked_frame3 = 1'b1;
						end
						4: begin
							check_ok(dut.fifo_wdata == sdram_rdata, "frame4_not_dram_data");
							check_ok(dut.fifo_wdata != {EXPECT_FILL_COLOR, EXPECT_FILL_COLOR}, "frame4_unexpected_fill_color");
							checked_frame4 = 1'b1;
						end
						default: begin
						end
					endcase
				end
			end
		end

		check_ok(frame_count >= 4, "frame_count_not_reached_4");
		check_ok(switched_to_on_in_frame1, "display_on_1st_toggle_not_done");
		check_ok(switched_to_off_in_frame2, "display_on_2nd_toggle_not_done");
		check_ok(switched_to_on_in_frame3, "display_on_3rd_toggle_not_done");
		check_ok(checked_frame1, "frame1_data_check_not_done");
		check_ok(checked_frame2, "frame2_data_check_not_done");
		check_ok(checked_frame3, "frame3_data_check_not_done");
		check_ok(checked_frame4, "frame4_data_check_not_done");
		check_ok(captured_frame4_first_address, "frame4_first_address_not_captured");
		check_ok(frame4_first_address == 18'd0, "frame4_first_address_is_not_zero");

		$display("[TB] PASS 4-frame display_on switching behavior verified.");
		$finish;
	end
endmodule
