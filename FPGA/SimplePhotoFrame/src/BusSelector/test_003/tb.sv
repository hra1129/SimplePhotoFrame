`timescale 1ns/1ps

module tb;
	localparam real CLK_HALF_NS = (1_000_000_000.0 / 81_000_000.0) / 2.0;
	localparam int BURST_WORDS = 8;
	localparam int TEST_REPEAT = 50;
	localparam int TIMEOUT_CYCLES = 50000;
	localparam [22:5] DISP_BASE_T1 = 18'h01000;
	localparam [22:5] CACHE_BASE_T1 = 18'h02000;
	localparam [22:5] BASE_T2 = 18'h03000;
	localparam [22:5] DISP_BASE_T3 = 18'h04000;
	localparam [22:5] CACHE_BASE_T3 = 18'h05000;
	localparam [22:5] DISP_BASE_T4 = 18'h06000;
	localparam [22:5] CACHE_BASE_T4 = 18'h07000;
	localparam [22:5] REFRESH_ADDR_T4 = 18'h07F00;
	localparam [22:5] BASE_T5 = 18'h08000;
	localparam [22:5] REFRESH_ADDR_T5 = 18'h08F00;
	localparam [22:5] DISP_BASE_T6 = 18'h09000;
	localparam [22:5] CACHE_BASE_T6 = 18'h0A000;
	localparam [22:5] DISP_BASE_T7 = 18'h0B000;
	localparam [22:5] CACHE_BASE_T7 = 18'h0C000;
	localparam [22:5] DISP_BASE_T8 = 18'h0D000;
	localparam [22:5] REFRESH_ADDR_T8 = 18'h0E000;
	localparam [22:5] BASE_T9 = 18'h11000;
	localparam [22:5] DISP_BASE_T10 = 18'h12000;
	localparam [22:5] CACHE_BASE_T10 = 18'h13000;
	localparam [22:5] DISP_BASE_T11 = 18'h14000;
	localparam [22:5] REFRESH_ADDR_T11 = 18'h15000;
	localparam int STAGGER_MAX_DELAY = 16;

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
	integer sim_cycle;

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

	task automatic wait_cycles(input integer cycles);
		integer i;
	begin
		for( i = 0; i < cycles; i = i + 1 ) begin
			step();
		end
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

	task automatic issue_display_read_track(
		input [22:5] addr,
		output integer accept_cycle
	);
		integer timeout;
	begin
		accept_cycle = -1;
		timeout = 0;
		@(posedge clk);
		sdram_display_address <= addr;
		sdram_display_address_valid <= 1'b1;

		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_display_address_ready ) begin
				accept_cycle = sim_cycle;
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

	task automatic issue_cache_request_track(
		input [22:5] addr,
		input bit write,
		input bit refresh,
		output integer accept_cycle
	);
		integer timeout;
	begin
		accept_cycle = -1;
		timeout = 0;
		@(posedge clk);
		sdram_cache_address <= addr;
		sdram_cache_write <= write;
		sdram_cache_refresh <= refresh;
		sdram_cache_address_valid <= 1'b1;

		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_cache_address_ready ) begin
				accept_cycle = sim_cycle;
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

	task automatic cache_write_burst_track(
		input [22:5] addr,
		input [7:0] id,
		output integer accept_cycle
	);
		integer i;
	begin
		issue_cache_request_track(addr, 1'b1, 1'b0, accept_cycle);

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

	task automatic expect_cache_read_burst_track(
		input [7:0] id,
		output integer done_cycle
	);
		integer timeout;
		integer beat;
		reg [31:0] expected;
	begin
		done_cycle = -1;
		timeout = 0;
		beat = 0;
		while( beat < BURST_WORDS && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
			if( sdram_cache_rdata_valid ) begin
				expected = make_word(id, beat[2:0]);
				check( sdram_cache_rdata === expected, "cache read data mismatch" );
				if( beat == (BURST_WORDS - 1) ) begin
					done_cycle = sim_cycle;
				end
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

	task automatic expect_display_read_burst_track(
		input [7:0] id,
		output integer done_cycle
	);
		integer timeout;
		integer beat;
		reg [31:0] expected;
	begin
		done_cycle = -1;
		timeout = 0;
		beat = 0;
		while( beat < BURST_WORDS && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
			if( sdram_display_rdata_valid ) begin
				expected = make_word(id, beat[2:0]);
				check( sdram_display_rdata === expected, "display read data mismatch" );
				if( beat == (BURST_WORDS - 1) ) begin
					done_cycle = sim_cycle;
				end
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

	task automatic run_simul_display_cache_write(
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] cache_addr,
		input [7:0] cache_id
	);
	begin
		fork
			begin
				issue_display_read(display_addr);
				expect_display_read_burst(display_id);
			end
			begin
				cache_write_burst(cache_addr, cache_id);
			end
		join
	end
	endtask

	task automatic run_simul_display_cache_read(
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] cache_addr,
		input [7:0] cache_id
	);
	begin
		fork
			begin
				issue_display_read(display_addr);
				expect_display_read_burst(display_id);
			end
			begin
				issue_cache_request(cache_addr, 1'b0, 1'b0);
				expect_cache_read_burst(cache_id);
			end
		join
	end
	endtask

	task automatic run_simul_display_cache_refresh(
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] refresh_addr
	);
	begin
		fork
			begin
				issue_display_read(display_addr);
				expect_display_read_burst(display_id);
			end
			begin
				issue_cache_request(refresh_addr, 1'b0, 1'b1);
			end
		join
	end
	endtask

	task automatic run_staggered_display_cache_read(
		input integer delay_cycles,
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] cache_addr,
		input [7:0] cache_id
	);
		integer display_done_cycle;
		integer cache_accept_cycle;
		integer display_accept_cycle;
	begin
		display_done_cycle = -1;
		cache_accept_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst_track(display_id, display_done_cycle);
			end
			begin
				wait_cycles(delay_cycles);
				issue_cache_request_track(cache_addr, 1'b0, 1'b0, cache_accept_cycle);
				expect_cache_read_burst(cache_id);
			end
		join
		check( cache_accept_cycle > display_done_cycle,
			$sformatf("cache read accepted before display read finished at delay=%0d", delay_cycles) );
	end
	endtask

	task automatic run_staggered_display_cache_write(
		input integer delay_cycles,
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] cache_addr,
		input [7:0] cache_id
	);
		integer display_done_cycle;
		integer cache_accept_cycle;
		integer display_accept_cycle;
	begin
		display_done_cycle = -1;
		cache_accept_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst_track(display_id, display_done_cycle);
			end
			begin
				wait_cycles(delay_cycles);
				cache_write_burst_track(cache_addr, cache_id, cache_accept_cycle);
			end
		join
		check( cache_accept_cycle > display_done_cycle,
			$sformatf("cache write accepted before display read finished at delay=%0d", delay_cycles) );
		issue_cache_request(cache_addr, 1'b0, 1'b0);
		expect_cache_read_burst(cache_id);
	end
	endtask

	task automatic run_staggered_display_cache_refresh(
		input integer delay_cycles,
		input [22:5] display_addr,
		input [7:0] display_id,
		input [22:5] refresh_addr
	);
		integer display_done_cycle;
		integer cache_accept_cycle;
		integer display_accept_cycle;
	begin
		display_done_cycle = -1;
		cache_accept_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst_track(display_id, display_done_cycle);
			end
			begin
				wait_cycles(delay_cycles);
				issue_cache_request_track(refresh_addr, 1'b0, 1'b1, cache_accept_cycle);
			end
		join
		check( cache_accept_cycle > display_done_cycle,
			$sformatf("cache refresh accepted before display read finished at delay=%0d", delay_cycles) );
	end
	endtask

	task automatic run_staggered_cache_read_display(
		input integer delay_cycles,
		input [22:5] cache_addr,
		input [7:0] cache_id,
		input [22:5] display_addr,
		input [7:0] display_id
	);
		integer cache_accept_cycle;
		integer cache_done_cycle;
		integer display_accept_cycle;
	begin
		cache_accept_cycle = -1;
		cache_done_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				issue_cache_request_track(cache_addr, 1'b0, 1'b0, cache_accept_cycle);
				expect_cache_read_burst_track(cache_id, cache_done_cycle);
			end
			begin
				while( cache_accept_cycle < 0 ) begin
					step();
				end
				wait_cycles(delay_cycles);
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst(display_id);
			end
		join
		check( display_accept_cycle > cache_done_cycle,
			$sformatf("display read accepted before cache read finished at delay=%0d", delay_cycles) );
	end
	endtask

	task automatic run_staggered_cache_write_display(
		input integer delay_cycles,
		input [22:5] cache_addr,
		input [7:0] cache_id,
		input [22:5] display_addr,
		input [7:0] display_id
	);
		integer cache_accept_cycle;
		integer cache_done_cycle;
		integer display_accept_cycle;
	begin
		cache_accept_cycle = -1;
		cache_done_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				cache_write_burst_track(cache_addr, cache_id, cache_accept_cycle);
				cache_done_cycle = sim_cycle;
			end
			begin
				while( cache_accept_cycle < 0 ) begin
					step();
				end
				wait_cycles(delay_cycles);
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst(display_id);
			end
		join
		check( display_accept_cycle > cache_done_cycle,
			$sformatf("display read accepted before cache write finished at delay=%0d", delay_cycles) );
		issue_cache_request(cache_addr, 1'b0, 1'b0);
		expect_cache_read_burst(cache_id);
	end
	endtask

	task automatic run_staggered_cache_refresh_display(
		input integer delay_cycles,
		input [22:5] refresh_addr,
		input [22:5] display_addr,
		input [7:0] display_id
	);
		integer cache_accept_cycle;
		integer display_accept_cycle;
	begin
		cache_accept_cycle = -1;
		display_accept_cycle = -1;
		fork
			begin
				issue_cache_request_track(refresh_addr, 1'b0, 1'b1, cache_accept_cycle);
			end
			begin
				while( cache_accept_cycle < 0 ) begin
					step();
				end
				wait_cycles(delay_cycles);
				issue_display_read_track(display_addr, display_accept_cycle);
				expect_display_read_burst(display_id);
			end
		join
		check( display_accept_cycle > cache_accept_cycle,
			$sformatf("display read accepted too early after cache refresh request at delay=%0d", delay_cycles) );
	end
	endtask

	always @(posedge clk) begin
		if( reset ) begin
			sim_cycle <= 0;
		end
		else begin
			sim_cycle <= sim_cycle + 1;
		end
	end

	initial begin
		integer i;
		integer delay_cycles;
		reg [22:5] display_addr;
		reg [22:5] cache_addr;
		reg [7:0] display_id;
		reg [7:0] cache_id;

		clk = 1'b0;
		reset = 1'b1;
		error_count = 0;
		test_num = 0;
		sim_cycle = 0;

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

		// -------------------------------------------------------------------------
		//	Test 1: 50回連続で display のリード、cache のライトが同時発生する場合のテスト
		// -------------------------------------------------------------------------
		start_test("display read + cache write simultaneously, 50 iterations");
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T1 + i, (8'h10 + i));
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			display_addr = DISP_BASE_T1 + i;
			cache_addr = CACHE_BASE_T1 + i;
			display_id = 8'h10 + i;
			cache_id = 8'h80 + i;
			run_simul_display_cache_write(display_addr, display_id, cache_addr, cache_id);
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			issue_cache_request(CACHE_BASE_T1 + i, 1'b0, 1'b0);
			expect_cache_read_burst(8'h80 + i);
		end

		// -------------------------------------------------------------------------
		//	Test 2: 50回連続で display のリード、cache のリードが同時発生する場合のテスト
		// -------------------------------------------------------------------------
		start_test("display read + cache read simultaneously, 50 iterations");
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			cache_write_burst(BASE_T2 + i, (8'h20 + i));
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			display_addr = BASE_T2 + i;
			cache_addr = BASE_T2 + i;
			display_id = 8'h20 + i;
			cache_id = 8'h20 + i;
			run_simul_display_cache_read(display_addr, display_id, cache_addr, cache_id);
		end

		// -------------------------------------------------------------------------
		//	Test 3: 50回連続で display のリード、cache のリード・ライト（交互）が同時発生する場合のテスト
		// -------------------------------------------------------------------------
		start_test("display read + cache read/write alternately, 50 iterations");
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T3 + i, (8'h40 + i));
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			display_addr = DISP_BASE_T3 + i;
			display_id = 8'h40 + i;
			if( (i % 2) == 0 ) begin
				cache_addr = CACHE_BASE_T3 + i;
				cache_id = 8'hA0 + i;
				run_simul_display_cache_write(display_addr, display_id, cache_addr, cache_id);
			end
			else begin
				cache_addr = CACHE_BASE_T3 + (i - 1);
				cache_id = 8'hA0 + (i - 1);
				run_simul_display_cache_read(display_addr, display_id, cache_addr, cache_id);
			end
		end

		// -------------------------------------------------------------------------
		//	Test 4: 50回連続で display のリード、cache のライトが同時発生する場合のテスト、ただし 25回目は cache は refresh。
		// -------------------------------------------------------------------------
		start_test("display read + cache write simultaneously, 25th is cache refresh");
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T4 + i, (8'h60 + i));
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			display_addr = DISP_BASE_T4 + i;
			display_id = 8'h60 + i;
			if( i == 24 ) begin
				run_simul_display_cache_refresh(display_addr, display_id, REFRESH_ADDR_T4);
			end
			else begin
				cache_addr = CACHE_BASE_T4 + i;
				cache_id = 8'hC0 + i;
				run_simul_display_cache_write(display_addr, display_id, cache_addr, cache_id);
			end
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			if( i != 24 ) begin
				issue_cache_request(CACHE_BASE_T4 + i, 1'b0, 1'b0);
				expect_cache_read_burst(8'hC0 + i);
			end
		end

		// -------------------------------------------------------------------------
		//	Test 5: 50回連続で display のリード、cache のリードが同時発生する場合のテスト、ただし 25回目は cache は refresh。
		// -------------------------------------------------------------------------
		start_test("display read + cache read simultaneously, 25th is cache refresh");
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			cache_write_burst(BASE_T5 + i, (8'hE0 + i));
		end
		for( i = 0; i < TEST_REPEAT; i = i + 1 ) begin
			display_addr = BASE_T5 + i;
			display_id = 8'hE0 + i;
			if( i == 24 ) begin
				run_simul_display_cache_refresh(display_addr, display_id, REFRESH_ADDR_T5);
			end
			else begin
				cache_addr = BASE_T5 + i;
				cache_id = 8'hE0 + i;
				run_simul_display_cache_read(display_addr, display_id, cache_addr, cache_id);
			end
		end

		// -------------------------------------------------------------------------
		//	Test 6: display read と cache read を独立タスクで起動し、cache の開始遅延を 0..16clk でずらす
		// -------------------------------------------------------------------------
		start_test("display read then staggered cache read accepts after display burst");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T6 + i, (8'h10 + i));
			cache_write_burst(CACHE_BASE_T6 + i, (8'h30 + i));
		end
		for( delay_cycles = 0; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_display_cache_read(
				delay_cycles,
				DISP_BASE_T6 + delay_cycles,
				8'h10 + delay_cycles,
				CACHE_BASE_T6 + delay_cycles,
				8'h30 + delay_cycles
			);
		end

		// -------------------------------------------------------------------------
		//	Test 7: display read と cache write を独立タスクで起動し、cache の開始遅延を 0..16clk でずらす
		// -------------------------------------------------------------------------
		start_test("display read then staggered cache write accepts after display burst");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T7 + i, (8'h50 + i));
		end
		for( delay_cycles = 0; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_display_cache_write(
				delay_cycles,
				DISP_BASE_T7 + delay_cycles,
				8'h50 + delay_cycles,
				CACHE_BASE_T7 + delay_cycles,
				8'h70 + delay_cycles
			);
		end

		// -------------------------------------------------------------------------
		//	Test 8: display read と cache refresh を独立タスクで起動し、cache の開始遅延を 0..16clk でずらす
		// -------------------------------------------------------------------------
		start_test("display read then staggered cache refresh accepts after display burst");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T8 + i, (8'h90 + i));
		end
		for( delay_cycles = 0; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_display_cache_refresh(
				delay_cycles,
				DISP_BASE_T8 + delay_cycles,
				8'h90 + delay_cycles,
				REFRESH_ADDR_T8 + delay_cycles
			);
		end

		// -------------------------------------------------------------------------
		//	Test 9: cache read 受理後 1..16clk 遅らせて display read を起動
		// -------------------------------------------------------------------------
		start_test("cache read then staggered display read accepts after cache burst");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(BASE_T9 + i, (8'hA0 + i));
		end
		for( delay_cycles = 1; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_cache_read_display(
				delay_cycles,
				BASE_T9 + delay_cycles,
				8'hA0 + delay_cycles,
				BASE_T9 + delay_cycles,
				8'hA0 + delay_cycles
			);
		end

		// -------------------------------------------------------------------------
		//	Test 10: cache write 受理後 1..16clk 遅らせて display read を起動
		// -------------------------------------------------------------------------
		start_test("cache write then staggered display read accepts after cache burst");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T10 + i, (8'hB0 + i));
		end
		for( delay_cycles = 1; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_cache_write_display(
				delay_cycles,
				CACHE_BASE_T10 + delay_cycles,
				8'hC0 + delay_cycles,
				DISP_BASE_T10 + delay_cycles,
				8'hB0 + delay_cycles
			);
		end

		// -------------------------------------------------------------------------
		//	Test 11: cache refresh 受理後 1..16clk 遅らせて display read を起動
		// -------------------------------------------------------------------------
		start_test("cache refresh then staggered display read accepts after refresh");
		for( i = 0; i <= STAGGER_MAX_DELAY; i = i + 1 ) begin
			cache_write_burst(DISP_BASE_T11 + i, (8'hD0 + i));
		end
		for( delay_cycles = 1; delay_cycles <= STAGGER_MAX_DELAY; delay_cycles = delay_cycles + 1 ) begin
			run_staggered_cache_refresh_display(
				delay_cycles,
				REFRESH_ADDR_T11 + delay_cycles,
				DISP_BASE_T11 + delay_cycles,
				8'hD0 + delay_cycles
			);
		end

		$display("[TB] completed with %0d error(s)", error_count);
		if( error_count != 0 ) begin
			$fatal(1);
		end
		$finish;
	end

endmodule
