`timescale 1ns/1ps

module tb;
	localparam real CLK_HALF_NS = (1_000_000_000.0 / 81_000_000.0) / 2.0;
	localparam int BURST_WORDS = 8;
	localparam int TIMEOUT_CYCLES = 50000;

	reg clk;
	reg reset;

	reg [22:5] sdram_display_address;
	reg sdram_display_address_valid;
	wire sdram_display_address_ready;
	wire [31:0] sdram_display_rdata;
	wire sdram_display_rdata_valid;

	reg [22:5] sdram_cache_address;
	reg sdram_cache_write;
	reg sdram_cache_refresh;
	reg sdram_cache_address_valid;
	wire sdram_cache_address_ready;
	reg [31:0] sdram_cache_wdata;
	reg [3:0] sdram_cache_wdata_mask;
	reg sdram_cache_wdata_valid;
	wire [31:0] sdram_cache_rdata;
	wire sdram_cache_rdata_valid;

	wire [22:5] sel_sdram_address;
	wire sel_sdram_write;
	wire sel_sdram_refresh;
	wire sel_sdram_address_valid;
	wire sel_sdram_address_ready;
	wire [31:0] sel_sdram_wdata;
	wire [3:0] sel_sdram_wdata_mask;
	wire sel_sdram_wdata_valid;
	wire [31:0] sel_sdram_rdata;
	wire sel_sdram_rdata_valid;

	wire sdram_init_busy;
	wire O_sdram_clk;
	wire O_sdram_cke;
	wire O_sdram_cs_n;
	wire O_sdram_ras_n;
	wire O_sdram_cas_n;
	wire O_sdram_wen_n;
	wire [31:0] IO_sdram_dq;
	wire [10:0] O_sdram_addr;
	wire [1:0] O_sdram_ba;
	wire [3:0] O_sdram_dqm;

	integer error_count;
	integer test_num;

	function automatic [31:0] make_word(
		input [7:0] id,
		input [2:0] beat
	);
	begin
		make_word = {8'hA5, id, 8'h5A, {5'd0, beat}};
	end
	endfunction

	always #(CLK_HALF_NS) clk = ~clk;

	bus_selector u_dut (
		.clk                        ( clk                       ),
		.reset                      ( reset                     ),
		.sdram_display_address      ( sdram_display_address     ),
		.sdram_display_address_valid( sdram_display_address_valid ),
		.sdram_display_address_ready( sdram_display_address_ready ),
		.sdram_display_rdata        ( sdram_display_rdata       ),
		.sdram_display_rdata_valid  ( sdram_display_rdata_valid ),
		.sdram_cache_address        ( sdram_cache_address       ),
		.sdram_cache_write          ( sdram_cache_write         ),
		.sdram_cache_refresh        ( sdram_cache_refresh       ),
		.sdram_cache_address_valid  ( sdram_cache_address_valid ),
		.sdram_cache_address_ready  ( sdram_cache_address_ready ),
		.sdram_cache_wdata          ( sdram_cache_wdata         ),
		.sdram_cache_wdata_mask     ( sdram_cache_wdata_mask    ),
		.sdram_cache_wdata_valid    ( sdram_cache_wdata_valid   ),
		.sdram_cache_rdata          ( sdram_cache_rdata         ),
		.sdram_cache_rdata_valid    ( sdram_cache_rdata_valid   ),
		.sdram_address              ( sel_sdram_address         ),
		.sdram_write                ( sel_sdram_write           ),
		.sdram_refresh              ( sel_sdram_refresh         ),
		.sdram_address_valid        ( sel_sdram_address_valid   ),
		.sdram_address_ready        ( sel_sdram_address_ready   ),
		.sdram_wdata                ( sel_sdram_wdata           ),
		.sdram_wdata_mask           ( sel_sdram_wdata_mask      ),
		.sdram_wdata_valid          ( sel_sdram_wdata_valid     ),
		.sdram_rdata                ( sel_sdram_rdata           ),
		.sdram_rdata_valid          ( sel_sdram_rdata_valid     )
	);

	ip_sdram u_sdram_ctrl (
		.reset              ( reset                 ),
		.clk                ( clk                   ),
		.clk_sdram          ( clk                   ),
		.sdram_init_busy    ( sdram_init_busy       ),
		.bus_address        ( sel_sdram_address     ),
		.bus_write          ( sel_sdram_write       ),
		.bus_refresh        ( sel_sdram_refresh     ),
		.bus_valid          ( sel_sdram_address_valid ),
		.bus_ready          ( sel_sdram_address_ready ),
		.bus_wdata          ( sel_sdram_wdata       ),
		.bus_wdata_mask     ( sel_sdram_wdata_mask  ),
		.bus_wdata_valid    ( sel_sdram_wdata_valid ),
		.bus_rdata          ( sel_sdram_rdata       ),
		.bus_rdata_valid    ( sel_sdram_rdata_valid ),
		.O_sdram_clk        ( O_sdram_clk           ),
		.O_sdram_cke        ( O_sdram_cke           ),
		.O_sdram_cs_n       ( O_sdram_cs_n          ),
		.O_sdram_ras_n      ( O_sdram_ras_n         ),
		.O_sdram_cas_n      ( O_sdram_cas_n         ),
		.O_sdram_wen_n      ( O_sdram_wen_n         ),
		.IO_sdram_dq        ( IO_sdram_dq           ),
		.O_sdram_addr       ( O_sdram_addr          ),
		.O_sdram_ba         ( O_sdram_ba            ),
		.O_sdram_dqm        ( O_sdram_dqm           )
	);

	mt48lc2m32b2 u_sdram_model (
		.Dq                 ( IO_sdram_dq           ),
		.Addr               ( O_sdram_addr          ),
		.Ba                 ( O_sdram_ba            ),
		.Clk                ( O_sdram_clk           ),
		.Cke                ( O_sdram_cke           ),
		.Cs_n               ( O_sdram_cs_n          ),
		.Ras_n              ( O_sdram_ras_n         ),
		.Cas_n              ( O_sdram_cas_n         ),
		.We_n               ( O_sdram_wen_n         ),
		.Dqm                ( O_sdram_dqm           )
	);

	task automatic check(input bit cond, input string msg);
	begin
		if( !cond ) begin
			$display("[TB][ERROR][T%0d] %s", test_num, msg);
			error_count = error_count + 1;
		end
	end
	endtask

	task automatic start_test(input string name);
	begin
		test_num = test_num + 1;
		$display("[TB][TEST%0d] %s", test_num, name);
	end
	endtask

	task automatic step;
	begin
		@(posedge clk);
	end
	endtask

	task automatic wait_init_done;
		integer timeout;
	begin
		timeout = 0;
		while( sdram_init_busy && timeout < TIMEOUT_CYCLES ) begin
			step();
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "timeout waiting for SDRAM initialization" );
	end
	endtask

	task automatic issue_display_read(input [22:5] addr);
		integer timeout;
	begin
		timeout = 0;
		@(posedge clk);
		sdram_display_address <= addr;
		sdram_display_address_valid <= 1'b1;

		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_display_address_ready ) begin
				sdram_display_address_valid <= 1'b0;
				break;
			end
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "display read request timeout" );
	end
	endtask

	task automatic issue_cache_request(
		input [22:5] addr,
		input bit write,
		input bit refresh
	);
		integer timeout;
	begin
		timeout = 0;
		@(posedge clk);
		sdram_cache_address <= addr;
		sdram_cache_write <= write;
		sdram_cache_refresh <= refresh;
		sdram_cache_address_valid <= 1'b1;

		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_cache_address_ready ) begin
				sdram_cache_address_valid <= 1'b0;
				break;
			end
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "cache request timeout" );
	end
	endtask

	task automatic cache_write_burst(
		input [22:5] addr,
		input [7:0] id
	);
		integer i;
	begin
		issue_cache_request(addr, 1'b1, 1'b0);

		@(posedge clk);
		for( i = 0; i < BURST_WORDS; i = i + 1 ) begin
			if( i != 0 ) begin
				@(posedge clk);
			end
			sdram_cache_wdata <= make_word(id, i[2:0]);
			sdram_cache_wdata_mask <= 4'h0;
			sdram_cache_wdata_valid <= 1'b1;
		end

		@(posedge clk);
		sdram_cache_wdata_valid <= 1'b0;
		sdram_cache_wdata <= 32'd0;
		sdram_cache_wdata_mask <= 4'hF;
		sdram_cache_write <= 1'b0;
	end
	endtask

	task automatic expect_cache_read_burst(input [7:0] id);
		integer timeout;
		integer beat;
		reg [31:0] expected;
	begin
		timeout = 0;
		beat = 0;
		while( beat < BURST_WORDS && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
			if( sdram_cache_rdata_valid ) begin
				expected = make_word(id, beat[2:0]);
				check( sdram_cache_rdata === expected, "cache read data mismatch" );
				beat = beat + 1;
			end
		end
		check( beat == BURST_WORDS, "cache read burst timeout" );
	end
	endtask

	task automatic expect_display_read_burst(input [7:0] id);
		integer timeout;
		integer beat;
		reg [31:0] expected;
	begin
		timeout = 0;
		beat = 0;
		while( beat < BURST_WORDS && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
			if( sdram_display_rdata_valid ) begin
				expected = make_word(id, beat[2:0]);
				check( sdram_display_rdata === expected, "display read data mismatch" );
				beat = beat + 1;
			end
		end
		check( beat == BURST_WORDS, "display read burst timeout" );
	end
	endtask

	task automatic expect_dual_read_burst(input [7:0] id);
		integer timeout;
		integer disp_beat;
		integer cache_beat;
		reg [31:0] expected;
	begin
		timeout = 0;
		disp_beat = 0;
		cache_beat = 0;
		while( (disp_beat < BURST_WORDS || cache_beat < BURST_WORDS) && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
			if( sdram_display_rdata_valid && disp_beat < BURST_WORDS ) begin
				expected = make_word(id, disp_beat[2:0]);
				check( sdram_display_rdata === expected, "display read data mismatch (dual)" );
				disp_beat = disp_beat + 1;
			end
			if( sdram_cache_rdata_valid && cache_beat < BURST_WORDS ) begin
				expected = make_word(id, cache_beat[2:0]);
				check( sdram_cache_rdata === expected, "cache read data mismatch (dual)" );
				cache_beat = cache_beat + 1;
			end
		end
		check( disp_beat == BURST_WORDS, "display read burst timeout (dual)" );
		check( cache_beat == BURST_WORDS, "cache read burst timeout (dual)" );
	end
	endtask

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		error_count = 0;
		test_num = 0;

		sdram_display_address = '0;
		sdram_display_address_valid = 1'b0;
		sdram_cache_address = '0;
		sdram_cache_write = 1'b0;
		sdram_cache_refresh = 1'b0;
		sdram_cache_address_valid = 1'b0;
		sdram_cache_wdata = 32'd0;
		sdram_cache_wdata_mask = 4'hF;
		sdram_cache_wdata_valid = 1'b0;

		repeat(4) step();
		reset = 1'b0;
		step();

		wait_init_done();
		repeat(16) step();

		start_test("cache write burst -> cache read burst (real SDRAM path)");
		cache_write_burst(18'h00120, 8'h31);
		issue_cache_request(18'h00120, 1'b0, 1'b0);
		expect_cache_read_burst(8'h31);

		start_test("display read uses same SDRAM data through bus_selector");
		issue_display_read(18'h00120);
		expect_display_read_burst(8'h31);

		start_test("back-to-back display/cache read requests are both served");
		issue_display_read(18'h00120);
		expect_display_read_burst(8'h31);
		issue_cache_request(18'h00120, 1'b0, 1'b0);
		expect_cache_read_burst(8'h31);

		$display("[TB] completed with %0d error(s)", error_count);
		if( error_count != 0 ) begin
			$fatal(1);
		end
		$finish;
	end

endmodule
