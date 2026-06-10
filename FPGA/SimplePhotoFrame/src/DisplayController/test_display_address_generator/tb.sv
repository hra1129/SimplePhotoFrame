`timescale 1ns/1ps

module tb;
	localparam integer IMG_WIDTH = 800 / 16;
	localparam integer IMG_HEIGHT = 480;
	localparam integer BURST_WORDS = 8;
	localparam integer REQUESTS_PER_FRAME = IMG_WIDTH * IMG_HEIGHT;
	localparam integer OBSERVE_FRAMES = 2;
	localparam integer MAX_CYCLES = REQUESTS_PER_FRAME * BURST_WORDS * OBSERVE_FRAMES + 2000;

	reg			clk;
	reg			reset;
	reg			sdram_init_busy;
	reg	[7:0]	bus_address;
	reg			bus_valid;
	wire			bus_ready;
	reg			bus_write;
	reg	[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;
	reg			fifo_full;
	wire	[31:0]	fifo_wdata;
	wire			fifo_valid;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	reg			sdram_address_ready;
	reg	[31:0]	sdram_rdata;
	reg			sdram_rdata_valid;

	integer		fifo_pulses;
	integer		request_pulses;
	integer		frame_count;
	integer		cycle_count;

	display_address_generator dut (
		.clk					( clk					),
		.reset					( reset					),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.fifo_full				( fifo_full				),
		.fifo_wdata				( fifo_wdata			),
		.fifo_valid				( fifo_valid			),
		.sdram_address			( sdram_address			),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
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
		bus_address = 8'd0;
		bus_valid = 1'b0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
		fifo_full = 1'b0;
		sdram_address_ready = 1'b0;
		sdram_rdata = 32'h0123_4567;
		sdram_rdata_valid = 1'b0;
		fifo_pulses = 0;
		request_pulses = 0;
		frame_count = 0;
		cycle_count = 0;

		repeat(3) @(posedge clk);
		reset = 1'b0;

		while( frame_count < OBSERVE_FRAMES && cycle_count < MAX_CYCLES ) begin
			@(posedge clk);
			#1;
			cycle_count = cycle_count + 1;

			check_ok( sdram_address_valid == 1'b0, "display_off_sdram_request" );

			if( fifo_valid ) begin
				fifo_pulses = fifo_pulses + 1;
			end

			if( dut.w_valid ) begin
				request_pulses = request_pulses + 1;
				if( dut.ff_h_counter == 0 && dut.ff_v_counter == 0 ) begin
					frame_count = frame_count + 1;
					$display("[TB] frame=%0d cycle=%0d requests=%0d fifo_words=%0d fifo_wdata=%h", frame_count, cycle_count, request_pulses, fifo_pulses, fifo_wdata);
				end
			end
		end

		check_ok( frame_count == OBSERVE_FRAMES, "display_off_2frames_timeout" );
		check_ok( request_pulses == REQUESTS_PER_FRAME * OBSERVE_FRAMES, "display_off_request_count" );
		check_ok( fifo_pulses == request_pulses * BURST_WORDS, "display_off_fifo_word_count" );

		$display("[TB] PASS frames=%0d requests=%0d fifo_words=%0d cycles=%0d", frame_count, request_pulses, fifo_pulses, cycle_count);
		$finish;
	end
endmodule