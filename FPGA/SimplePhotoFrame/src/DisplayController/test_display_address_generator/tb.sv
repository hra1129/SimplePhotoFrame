`timescale 1ns/1ps

module tb;
	localparam integer IMG_WIDTH = 800 / 16;
	localparam integer IMG_HEIGHT = 480;
	localparam integer BURST_WORDS = 8;
	localparam integer REQUESTS_PER_FRAME = IMG_WIDTH * IMG_HEIGHT;
	localparam integer OBSERVE_FRAMES = 2;
	localparam integer MAX_CYCLES = REQUESTS_PER_FRAME * BURST_WORDS * OBSERVE_FRAMES + 2000;

	reg				clk;
	reg				reset;
	reg				sdram_init_busy;
	reg			frame_end;
	reg				bus_cs;
	reg	[4:0]	bus_address;
	reg				bus_valid;
	wire			bus_ready;
	reg			bus_write;
	reg	[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;
	wire			display_on;
	wire	[15:0]	fill_color;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	reg			sdram_address_ready;

	integer			request_pulses;
	integer			frame_count;
	integer			cycle_count;
	reg				seen_reg5_readback;
	reg				seen_reg5_cleared;

	display_address_generator dut (
		.clk					( clk					),
		.reset					( reset					),
		.sdram_init_busy		( sdram_init_busy		),
		.frame_end			( frame_end			),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.display_on				( display_on				),
		.fill_color				( fill_color				),
		.sdram_address			( sdram_address			),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	)
	);

	always #5 clk = ~clk;

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

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		sdram_init_busy = 1'b0;
		frame_end = 1'b0;
		bus_cs = 1'b1;
		bus_address = 5'd0;
		bus_valid = 1'b0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
		sdram_address_ready = 1'b1;
		request_pulses = 0;
		frame_count = 0;
		cycle_count = 0;
		seen_reg5_readback = 1'b0;
		seen_reg5_cleared = 1'b0;

		repeat(3) @(posedge clk);
		reset = 1'b0;

		@(posedge clk);
		bus_address <= 5'd5;
		bus_wdata <= 16'h0001;
		bus_write <= 1'b1;
		bus_valid <= 1'b1;
		@(posedge clk);
		bus_valid <= 1'b0;
		bus_write <= 1'b0;
		bus_wdata <= 16'd0;
		bus_address <= 5'd5;

		@(posedge clk);
		bus_valid <= 1'b1;
		bus_write <= 1'b0;
		@(posedge clk);
		#1;
		check_ok( bus_rdata_valid && bus_rdata[0], "reg5_readback_after_write" );
		seen_reg5_readback = 1'b1;
		bus_valid <= 1'b0;

		frame_end = 1'b0;
		@(posedge clk);
		frame_end = 1'b1;
		bus_valid <= 1'b1;
		bus_write <= 1'b0;
		@(posedge clk);
		#1;
		check_ok( bus_rdata_valid && !bus_rdata[0], "reg5_clear_on_frame_end" );
		seen_reg5_cleared = 1'b1;
		bus_valid <= 1'b0;

		while( frame_count < OBSERVE_FRAMES && cycle_count < MAX_CYCLES ) begin
			@(posedge clk);
			#1;
			cycle_count = cycle_count + 1;

			if( sdram_address_valid && sdram_address_ready ) begin
				request_pulses = request_pulses + 1;
				if( dut.ff_h_counter == 0 && dut.ff_v_counter == 0 ) begin
					frame_count = frame_count + 1;
					$display("[TB] frame=%0d cycle=%0d requests=%0d display_on=%0d fill_color=%h", frame_count, cycle_count, request_pulses, display_on, fill_color);
				end
			end
		end

		check_ok( frame_count == OBSERVE_FRAMES, "display_off_2frames_timeout" );
		check_ok( request_pulses >= REQUESTS_PER_FRAME, "display_off_request_count" );
		check_ok( seen_reg5_readback, "reg5_readback_not_observed" );
		check_ok( seen_reg5_cleared, "reg5_clear_not_observed" );

		$display("[TB] PASS frames=%0d requests=%0d cycles=%0d", frame_count, request_pulses, cycle_count);
		$finish;
	end
endmodule