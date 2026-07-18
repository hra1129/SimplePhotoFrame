`timescale 1ns/1ps

module tb;
	localparam integer CLK_HALF = 5;
	localparam integer TIMEOUT_CYCLES = 200;
	localparam integer BURST_WORDS = 8;
	localparam integer REFRESH_READY_LOW_CYCLES = 50;
	localparam [1:0] SDRAM_IDLE = 2'd0;
	localparam [1:0] SDRAM_REFRESH = 2'd1;
	localparam [1:0] SDRAM_WRITE = 2'd2;
	localparam [1:0] SDRAM_READ = 2'd3;

	reg				clk;
	reg				reset;

	reg		[22:5]	sdram_display_address;
	reg				sdram_display_address_valid;
	wire			sdram_display_address_ready;
	wire	[31:0]	sdram_display_rdata;
	wire			sdram_display_rdata_valid;

	int				dbg_cycle;
	reg		[22:5]	sdram_cache_address;
	reg				sdram_cache_write;
	reg				sdram_cache_refresh;
	reg				sdram_cache_address_valid;
	wire			sdram_cache_address_ready;
	reg		[31:0]	sdram_cache_wdata;
	reg		[3:0]	sdram_cache_wdata_mask;
	reg				sdram_cache_wdata_valid;
	wire	[31:0]	sdram_cache_rdata;
	wire			sdram_cache_rdata_valid;

	wire	[22:5]	sdram_address;
	wire			sdram_write;
	wire			sdram_refresh;
	wire			sdram_address_valid;
	reg				sdram_address_ready;
	wire	[31:0]	sdram_wdata;
	wire	[3:0]	sdram_wdata_mask;
	wire			sdram_wdata_valid;
	reg		[31:0]	sdram_rdata;
	reg				sdram_rdata_valid;

	int				test_num;
	int				error_count;
	int				timeout;
	integer			sdram_wait_count;
	reg		[2:0]	sdram_read_count;
	reg		[2:0]	sdram_write_count;
	reg		[1:0]	sdram_model_state;
	integer			read_sequence;
	reg		[31:0]	sdram_read_base;

	bus_selector u_dut (
		.clk							( clk							),
		.reset							( reset							),
		.sdram_display_address			( sdram_display_address			),
		.sdram_display_address_valid	( sdram_display_address_valid	),
		.sdram_display_address_ready	( sdram_display_address_ready	),
		.sdram_display_rdata			( sdram_display_rdata			),
		.sdram_display_rdata_valid		( sdram_display_rdata_valid		),
		.sdram_cache_address			( sdram_cache_address			),
		.sdram_cache_write				( sdram_cache_write				),
		.sdram_cache_refresh			( sdram_cache_refresh			),
		.sdram_cache_address_valid		( sdram_cache_address_valid		),
		.sdram_cache_address_ready		( sdram_cache_address_ready		),
		.sdram_cache_wdata				( sdram_cache_wdata				),
		.sdram_cache_wdata_mask			( sdram_cache_wdata_mask		),
		.sdram_cache_wdata_valid		( sdram_cache_wdata_valid		),
		.sdram_cache_rdata				( sdram_cache_rdata				),
		.sdram_cache_rdata_valid		( sdram_cache_rdata_valid		),
		.sdram_address					( sdram_address					),
		.sdram_write					( sdram_write					),
		.sdram_refresh					( sdram_refresh					),
		.sdram_address_valid			( sdram_address_valid			),
		.sdram_address_ready			( sdram_address_ready			),
		.sdram_wdata					( sdram_wdata					),
		.sdram_wdata_mask				( sdram_wdata_mask				),
		.sdram_wdata_valid				( sdram_wdata_valid				),
		.sdram_rdata					( sdram_rdata					),
		.sdram_rdata_valid				( sdram_rdata_valid				)
	);

	always #(CLK_HALF) clk = ~clk;

	always @(posedge clk) begin
		if( reset ) begin
			sdram_address_ready <= 1'b1;
			sdram_rdata <= 32'd0;
			sdram_rdata_valid <= 1'b0;
			sdram_wait_count <= 0;
			sdram_read_count <= 3'd0;
			sdram_write_count <= 3'd0;
			sdram_model_state <= SDRAM_IDLE;
			read_sequence <= 0;
			sdram_read_base <= 32'd0;
		end
		else begin
			sdram_rdata_valid <= 1'b0;
			case( sdram_model_state )
				SDRAM_IDLE: begin
					sdram_address_ready <= 1'b1;
					if( sdram_address_valid ) begin
						sdram_address_ready <= 1'b0;
						if( sdram_refresh ) begin
							sdram_model_state <= SDRAM_REFRESH;
							sdram_wait_count <= REFRESH_READY_LOW_CYCLES;
						end
						else if( sdram_write ) begin
							sdram_model_state <= SDRAM_WRITE;
							sdram_write_count <= 3'd0;
						end
						else begin
							sdram_model_state <= SDRAM_READ;
							sdram_read_count <= 3'd0;
							case( read_sequence )
								0: sdram_read_base <= 32'hABCD_1200;
								1: sdram_read_base <= 32'hCCDD_EE00;
								2: sdram_read_base <= 32'h1122_3300;
								default: sdram_read_base <= 32'h5566_7700;
							endcase
							read_sequence <= read_sequence + 1;
						end
					end
				end

				SDRAM_REFRESH: begin
					sdram_address_ready <= 1'b0;
					if( sdram_wait_count == 1 ) begin
						sdram_model_state <= SDRAM_IDLE;
						sdram_wait_count <= 0;
						sdram_address_ready <= 1'b1;
					end
					else begin
						sdram_wait_count <= sdram_wait_count - 1;
					end
				end

				SDRAM_WRITE: begin
					sdram_address_ready <= 1'b0;
					if( sdram_cache_wdata_valid ) begin
						if( sdram_write_count == (BURST_WORDS - 1) ) begin
							sdram_model_state <= SDRAM_IDLE;
							sdram_write_count <= 3'd0;
							sdram_address_ready <= 1'b1;
						end
						else begin
							sdram_write_count <= sdram_write_count + 3'd1;
						end
					end
				end

				default: begin // SDRAM_READ
					sdram_address_ready <= 1'b0;
					sdram_rdata_valid <= 1'b1;
					sdram_rdata <= sdram_read_base + sdram_read_count;
					if( sdram_read_count == (BURST_WORDS - 1) ) begin
						sdram_model_state <= SDRAM_IDLE;
						sdram_read_count <= 3'd0;
						sdram_address_ready <= 1'b1;
					end
					else begin
						sdram_read_count <= sdram_read_count + 3'd1;
					end
				end
			endcase
		end
	end

	task automatic init_inputs;
	begin
		sdram_display_address = '0;
		sdram_display_address_valid = 1'b0;
		sdram_cache_address = '0;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b0;
		sdram_cache_wdata = '0;
		sdram_cache_wdata_mask = 4'h0;
		sdram_cache_wdata_valid = 1'b0;
		sdram_rdata = '0;
		sdram_rdata_valid = 1'b0;
		sdram_wait_count = 0;
		sdram_read_count = 3'd0;
		sdram_write_count = 3'd0;
		sdram_model_state = SDRAM_IDLE;
		read_sequence = 0;
		sdram_read_base = 32'd0;
	end
	endtask

	task automatic clear_requests;
	begin
		sdram_display_address_valid = 1'b0;
		sdram_cache_address_valid = 1'b0;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b0;
		sdram_cache_wdata_valid = 1'b0;
		@(posedge clk);
	end
	endtask

	task automatic start_test(input string name);
	begin
		test_num = test_num + 1;
		$display("[TB][TEST%0d] %s", test_num, name);
	end
	endtask

	task automatic check(input bit cond, input string msg);
	begin
		if( !cond ) begin
			$display("[TB][ERROR][TEST%0d] %s", test_num, msg);
			$display(
				"[TB][STATE][TEST%0d] av=%b drdy=%b crdy=%b addr=%h wr=%b ref=%b wdata=%h mask=%h wvalid=%b drdata_v=%b crdata_v=%b",
				test_num,
				sdram_address_valid,
				sdram_display_address_ready,
				sdram_cache_address_ready,
				sdram_address,
				sdram_write,
				sdram_refresh,
				sdram_wdata,
				sdram_wdata_mask,
				sdram_wdata_valid,
				sdram_display_rdata_valid,
				sdram_cache_rdata_valid
			);
			error_count = error_count + 1;
		end
	end
	endtask

	task automatic step;
	begin
		@(posedge clk);
	end
	endtask

	task automatic wait_rdata;
	begin
		timeout = 0;
		while( !sdram_rdata_valid && timeout < TIMEOUT_CYCLES ) begin
			step();
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "timeout waiting for SDRAM read data" );
	end
	endtask

	task automatic wait_accept(
		input bit expect_display_ready,
		input bit expect_cache_ready
	);
	begin
		timeout = 0;
		while( !sdram_address_valid && timeout < TIMEOUT_CYCLES ) begin
			step();
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "timeout waiting for SDRAM accept" );
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display(
				"[TB][DEBUG][TEST%0d] ff_ready=%b ff_priority=%b ff_read_bus=%b ff_read_stall=%b display_v=%b cache_v=%b sdram_v=%b display_rdy=%b cache_rdy=%b",
				test_num,
				u_dut.ff_ready,
				u_dut.ff_priority,
				u_dut.ff_read_bus,
				u_dut.ff_read_stall,
				sdram_display_address_valid,
				sdram_cache_address_valid,
				sdram_address_valid,
				sdram_display_address_ready,
				sdram_cache_address_ready
			);
		end
		check( sdram_display_address_ready === expect_display_ready, "display ready mismatch" );
		check( sdram_cache_address_ready === expect_cache_ready, "cache ready mismatch" );
	end
	endtask

	task automatic expect_sdram(
		input bit expect_display,
		input bit expect_cache,
		input bit expect_write,
		input bit expect_refresh,
		input bit expect_valid,
		input [22:5] expect_address,
		input [31:0] expect_wdata,
		input [3:0] expect_mask,
		input bit expect_wdata_valid
	);
	begin
		check( sdram_address_valid === expect_valid, "sdram_address_valid mismatch" );
		check( sdram_write === expect_write, "sdram_write mismatch" );
		check( sdram_refresh === expect_refresh, "sdram_refresh mismatch" );
		check( sdram_display_address_ready == expect_display, "display ready mismatch" );
		check( sdram_cache_address_ready == expect_cache, "cache ready mismatch" );
		if( expect_valid ) begin
			check( sdram_address === expect_address, "sdram_address mismatch" );
			check( sdram_wdata_valid === expect_wdata_valid, "sdram_wdata_valid mismatch" );
			if( expect_write || expect_wdata_valid ) begin
				check( sdram_wdata === expect_wdata, "sdram_wdata mismatch" );
				check( sdram_wdata_mask === expect_mask, "sdram_wdata_mask mismatch" );
			end
		end
	end
	endtask

	task automatic expect_read_data(
		input bit expect_display,
		input bit expect_cache,
		input [31:0] expect_display_rdata,
		input [31:0] expect_cache_rdata
	);
	begin
		check( sdram_display_rdata_valid === expect_display, "display rdata_valid mismatch" );
		check( sdram_cache_rdata_valid === expect_cache, "cache rdata_valid mismatch" );
		if( expect_display ) begin
			check( sdram_display_rdata === expect_display_rdata, "display rdata mismatch" );
		end
		if( expect_cache ) begin
			check( sdram_cache_rdata === expect_cache_rdata, "cache rdata mismatch" );
		end
	end
	endtask

	initial begin
		integer i;
		reg [31:0] burst_data;
		reg [3:0] burst_mask;

		clk = 1'b0;
		reset = 1'b1;
		test_num = 0;
		error_count = 0;
		init_inputs();

		repeat(4) @(posedge clk);
		reset = 1'b0;
		step();

		start_test( "display and cache valid at same time, then continuous arbitration" );
		sdram_display_address = 18'h00123;
		sdram_display_address_valid = 1'b1;
		sdram_cache_address = 18'h00456;
		sdram_cache_write = 1'b1;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b1;
		sdram_cache_wdata = 32'hCAFEBABE;
		sdram_cache_wdata_mask = 4'h0;
		sdram_cache_wdata_valid = 1'b0;
		wait_accept( 1'b1, 1'b0 );
		expect_sdram( 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 18'h00123, 32'd0, 4'h0, 1'b0 );
		sdram_display_address_valid = 1'b0;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			wait_rdata();
			expect_read_data( 1'b1, 1'b0, 32'hABCD_1200 + i, 32'd0 );
			step();
			check( sdram_display_address_ready === 1'b0, "display ready must stay low during burst read" );
			check( sdram_cache_address_ready === 1'b0, "cache ready must stay low during burst read" );
			check( sdram_cache_address_valid === 1'b1, "cache valid must stay high until cache request is accepted" );
			check( sdram_cache_wdata_valid === 1'b0, "cache wdata_valid must stay low until cache request is accepted" );
		end
		step();
		check( sdram_display_address_ready === 1'b0, "display ready must remain low until next arbitration" );
		check( sdram_cache_address_valid === 1'b1, "cache valid must still be high before cache ready" );
		check( sdram_cache_wdata_valid === 1'b0, "cache wdata_valid must still be low before cache ready" );
		wait_accept( 1'b0, 1'b1 );
		expect_sdram( 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 18'h00456, 32'hCAFEBABE, 4'h0, 1'b0 );
		sdram_cache_address_valid = 1'b0;

		// Keep next display read pending while cache write burst is in progress.
		sdram_display_address = 18'h00AAA;
		sdram_display_address_valid = 1'b1;
		sdram_cache_wdata_valid = 1'b1;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			sdram_cache_wdata = 32'hCAFE_BE00 + i;
			sdram_cache_wdata_mask = 4'h1 << i[1:0];
			step();
			check( sdram_display_address_ready === 1'b0, "display ready must stay low until cache write burst completes" );
		end
		sdram_cache_wdata_valid = 1'b0;
		sdram_cache_address_valid = 1'b0;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b0;
		wait_accept( 1'b1, 1'b0 );
		expect_sdram( 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 18'h00AAA, 32'd0, 4'h0, 1'b0 );
		sdram_display_address_valid = 1'b0;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			wait_rdata();
			expect_read_data( 1'b1, 1'b0, 32'hCCDD_EE00 + i, 32'd0 );
			step();
		end
		step();

		start_test( "display only request" );
		sdram_display_address = 18'h00AAA;
		sdram_display_address_valid = 1'b1;
		wait_accept( 1'b1, 1'b0 );
		expect_sdram( 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 18'h00AAA, 32'd0, 4'h0, 1'b0 );
		sdram_display_address_valid = 1'b0;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			wait_rdata();
			expect_read_data( 1'b1, 1'b0, 32'h1122_3300 + i, 32'd0 );
			step();
		end
		step();

		start_test( "cache write only request and 8word write burst" );
		sdram_cache_address = 18'h00BBB;
		sdram_cache_write = 1'b1;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b1;
		sdram_cache_wdata_valid = 1'b0;
		wait_accept( 1'b0, 1'b1 );
		check( sdram_cache_wdata_valid === 1'b0, "cache wdata_valid must be low when cache address is accepted" );
		sdram_cache_address_valid = 1'b0;
		sdram_cache_wdata_valid = 1'b1;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			burst_data = 32'hA5A5_5A50 + i;
			burst_mask = 4'h1 << i[1:0];
			sdram_cache_wdata = burst_data;
			sdram_cache_wdata_mask = burst_mask;
			step();
			check( sdram_cache_address_ready === 1'b0, "cache ready must stay low until cache write burst completes" );
			check( sdram_display_address_ready === 1'b0, "display ready must stay low during cache write burst" );
			check( sdram_write === 1'b1, "sdram_write must stay asserted during cache write burst" );
			check( sdram_wdata_valid === 1'b1, "sdram_wdata_valid must stay asserted during cache write burst" );
			check( sdram_wdata === burst_data, "sdram_wdata mismatch during cache write burst" );
			check( sdram_wdata_mask === burst_mask, "sdram_wdata_mask mismatch during cache write burst" );
		end
		sdram_cache_wdata_valid = 1'b0;
		sdram_cache_address_valid = 1'b0;
		sdram_cache_write = 1'b0;
		step();
		clear_requests();

		start_test( "cache read only request and 8word read burst" );
		sdram_cache_address = 18'h00CCD;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b1;
		sdram_cache_wdata_valid = 1'b0;
		wait_accept( 1'b0, 1'b1 );
		expect_sdram( 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 18'h00CCD, 32'd0, 4'h0, 1'b0 );
		sdram_cache_address_valid = 1'b0;
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			wait_rdata();
			expect_read_data( 1'b0, 1'b1, 32'd0, 32'h5566_7700 + i );
			step();
		end
		step();

		start_test( "cache refresh only request and continuous refresh" );
		sdram_cache_address = 18'h00DDD;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b1;
		sdram_cache_address_valid = 1'b1;
		sdram_cache_wdata = 32'hDEAD_BEEF;
		sdram_cache_wdata_mask = 4'hF;
		sdram_cache_wdata_valid = 1'b0;
		wait_accept( 1'b0, 1'b1 );
		expect_sdram( 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 18'h00DDD, 32'hDEAD_BEEF, 4'hF, 1'b0 );
		clear_requests();

		start_test( "continuous mixed arbitration across multiple cycles" );
		sdram_display_address = 18'h01111;
		sdram_display_address_valid = 1'b1;
		sdram_cache_address = 18'h02222;
		sdram_cache_write = 1'b1;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b1;
		sdram_cache_wdata = 32'h0102_0304;
		sdram_cache_wdata_mask = 4'h5;
		sdram_cache_wdata_valid = 1'b0;
		wait_accept( 1'b1, 1'b0 );
		expect_sdram( 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 18'h01111, 32'd0, 4'h0, 1'b0 );
		clear_requests();

		$display("[TB] completed with %0d error(s)", error_count);
		if( error_count != 0 ) begin
			$fatal( 1 );
		end
		$finish;
	end

endmodule
