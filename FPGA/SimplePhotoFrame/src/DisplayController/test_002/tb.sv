`timescale 1ns/1ps

module tb;
	localparam integer H_ACTIVE_PIXELS = 800;
	localparam integer V_ACTIVE_LINES = 480;
	localparam integer BURST_PIXELS = 16;
	localparam integer VRAM_STRIDE_BURST = 64;
	localparam integer MAX_CYCLES = 40000000;
	localparam integer SDRAM_READ_LATENCY = 4;
	localparam integer SDRAM_BURST_WORDS = 8;

	localparam [1:0] C_IDLE = 2'd0;
	localparam [1:0] C_WAIT = 2'd1;
	localparam [1:0] C_BURST = 2'd2;

	reg			clk;
	reg			reset;
	reg			sdram_init_busy;
	reg			bus_cs;
	reg	[4:0]	bus_address;
	reg			bus_valid;
	wire			bus_ready;
	reg			bus_write;
	reg	[15:0]	bus_wdata;
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
	reg			sdram_address_ready;
	reg	[31:0]	sdram_rdata;
	reg			sdram_rdata_valid;

	reg	[1:0]	sdram_state;
	reg	[22:5]	ff_req_addr;
	reg	[3:0]	ff_wait_count;
	reg	[2:0]	ff_burst_count;

	integer		cycle_count;
	integer		mismatch_count;
	integer		sample_count;
	integer		frame_end_count_after_on;
	reg			monitor_enable;
	reg			seen_display_on;
	reg			last_frame_end;

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
				if( timeout > 200 ) begin
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
			sdram_state <= C_IDLE;
			ff_req_addr <= 18'd0;
			ff_wait_count <= 4'd0;
			ff_burst_count <= 3'd0;
			sdram_address_ready <= 1'b1;
			sdram_rdata_valid <= 1'b0;
			sdram_rdata <= 32'd0;
		end
		else begin
			sdram_rdata_valid <= 1'b0;
			case( sdram_state )
				C_IDLE: begin
					sdram_address_ready <= 1'b1;
					ff_burst_count <= 3'd0;
					if( sdram_address_valid && sdram_address_ready ) begin
						ff_req_addr <= sdram_address;
						ff_wait_count <= SDRAM_READ_LATENCY[3:0];
						sdram_address_ready <= 1'b0;
						sdram_state <= C_WAIT;
					end
				end

				C_WAIT: begin
					sdram_address_ready <= 1'b0;
					if( ff_wait_count != 4'd0 ) begin
						ff_wait_count <= ff_wait_count - 4'd1;
					end
					else begin
						sdram_state <= C_BURST;
					end
				end

				C_BURST: begin
					sdram_address_ready <= 1'b0;
					sdram_rdata_valid <= 1'b1;
					sdram_rdata <= { ff_req_addr[20:5], ff_req_addr[20:5] };
					if( ff_burst_count == SDRAM_BURST_WORDS - 1 ) begin
						ff_burst_count <= 3'd0;
						sdram_state <= C_IDLE;
						sdram_address_ready <= 1'b1;
					end
					else begin
						ff_burst_count <= ff_burst_count + 3'd1;
					end
				end

				default: begin
					sdram_state <= C_IDLE;
					sdram_address_ready <= 1'b1;
				end
			endcase
		end
	end

	always @(posedge clk) begin
		integer active_x;
		integer active_y;
		integer burst_idx;
		reg [15:0] expected_pixel;
		if( reset ) begin
			mismatch_count <= 0;
			sample_count <= 0;
			frame_end_count_after_on <= 0;
			monitor_enable <= 1'b0;
			seen_display_on <= 1'b0;
			last_frame_end <= 1'b0;
		end
		else begin
			if( dut.display_address_generator.ff_display_on && !seen_display_on ) begin
				seen_display_on <= 1'b1;
				monitor_enable <= 1'b1;
				frame_end_count_after_on <= 0;
				$display("[TB] display_on became active at cycle=%0d", cycle_count);
			end

			if( monitor_enable ) begin
				if( dut.display_timing_generator.frame_end && !last_frame_end ) begin
					frame_end_count_after_on <= frame_end_count_after_on + 1;
					$display("[TB] frame_end count after display_on = %0d", frame_end_count_after_on + 1);
				end

				if( dut.display_timing_generator.w_lcd_ck_rise && dut.display_timing_generator.w_de ) begin
					active_x = dut.display_timing_generator.ff_h_counter - 25;
					active_y = dut.display_timing_generator.ff_v_counter - 15;
					burst_idx = active_x / BURST_PIXELS;
					expected_pixel = (active_y * VRAM_STRIDE_BURST + burst_idx) & 16'hFFFF;
					sample_count <= sample_count + 1;
					if( dut.p_data !== expected_pixel ) begin
						if( mismatch_count < 40 ) begin
							$display("[TB][MISMATCH] y=%0d x=%0d exp=%h got=%h req_addr=%0d", active_y, active_x, expected_pixel, dut.p_data, dut.sdram_address);
						end
						mismatch_count <= mismatch_count + 1;
					end
				end
			end

			last_frame_end <= dut.display_timing_generator.frame_end;
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
		sdram_state = C_IDLE;
		ff_req_addr = 18'd0;
		ff_wait_count = 4'd0;
		ff_burst_count = 3'd0;
		cycle_count = 0;
		mismatch_count = 0;
		sample_count = 0;
		frame_end_count_after_on = 0;
		monitor_enable = 1'b0;
		seen_display_on = 1'b0;
		last_frame_end = 1'b0;

		repeat(5) @(posedge clk);
		reset = 1'b0;

		// Enable display (register #2 bit0 = 1)
		bus_write16(5'd2, 16'h0001);

		while( cycle_count < MAX_CYCLES ) begin
			@(posedge clk);
			cycle_count = cycle_count + 1;
			if( seen_display_on && frame_end_count_after_on >= 2 ) begin
				$display("[TB] monitor finished: samples=%0d mismatch=%0d", sample_count, mismatch_count);
				if( mismatch_count == 0 ) begin
					$display("[TB] PASS: no pixel mismatches for 2 frames after display_on=1");
					$finish;
				end
				else begin
					$display("[TB] FAIL: mismatches detected for 2 frames after display_on=1");
					$finish(1);
				end
			end
		end

		$display("[TB][ERROR] timeout samples=%0d mismatch=%0d", sample_count, mismatch_count);
		$finish(1);
	end
endmodule
