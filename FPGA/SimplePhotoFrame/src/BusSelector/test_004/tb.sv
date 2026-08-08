`timescale 1ns/1ps

// bus_selector + ip_sdram + MT48 model のストレス試験。
// 目的: cache write burst(8word wdata) の途中に refresh/display 要求が
// 割り込んだ場合でも、display read データが乱れないことを確認する。
module tb;
	localparam real CLK_HALF_NS = (1_000_000_000.0 / 81_000_000.0) / 2.0;
	localparam int BURST_WORDS = 8;
	localparam int TIMEOUT_CYCLES = 50000;
	localparam int REGION_A_BURSTS = 4;
	localparam int REGION_B_BURSTS = 8;

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
	reg stop_display;
	reg display_hammer_done;
	reg stress_monitor_enable;
	reg [7:0] regionb_last_id [0:REGION_B_BURSTS-1];

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
			$display("[TB][ERROR][T%0d] %s (time=%0t)", test_num, msg, $time);
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

	//	write burst の wdata streaming 中(beat=refresh_beat)に refresh 要求を提示する。
	//	受理は write burst 完了後まで遅延しなければならない。
	task automatic write_burst_with_refresh(
		input [22:5] addr,
		input [7:0] id,
		input int refresh_beat
	);
		integer i;
		integer timeout;
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
			if( i == refresh_beat ) begin
				sdram_cache_address <= 18'd0;
				sdram_cache_write <= 1'b0;
				sdram_cache_refresh <= 1'b1;
				sdram_cache_address_valid <= 1'b1;
			end
		end

		@(posedge clk);
		sdram_cache_wdata_valid <= 1'b0;
		sdram_cache_wdata <= 32'd0;
		sdram_cache_wdata_mask <= 4'hF;

		//	refresh 要求の受理待ち
		timeout = 0;
		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_cache_address_ready ) begin
				sdram_cache_address_valid <= 1'b0;
				sdram_cache_refresh <= 1'b0;
				break;
			end
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "refresh accept after write timeout" );
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
				check( sdram_cache_rdata === expected, $sformatf("cache read data mismatch beat=%0d expected=%08h got=%08h", beat, expected, sdram_cache_rdata) );
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
				check( sdram_display_rdata === expected, $sformatf("display read data mismatch beat=%0d expected=%08h got=%08h", beat, expected, sdram_display_rdata) );
				beat = beat + 1;
			end
		end
		check( beat == BURST_WORDS, "display read burst timeout" );
	end
	endtask

	//	display は実機同様、read burst を発行し続ける。
	//	実機は preload FIFO 残量に応じて要求間隔が空くため、少し間隔を入れる。
	task automatic display_hammer;
		integer idx;
	begin
		idx = 0;
		while( !stop_display ) begin
			issue_display_read(18'h00200 + idx[17:0]);
			expect_display_read_burst(8'h10 + idx[7:0]);
			repeat(6) step();
			idx = (idx + 1) % REGION_A_BURSTS;
		end
		display_hammer_done = 1'b1;
	end
	endtask

	task automatic wait_display_accept;
		integer timeout;
	begin
		timeout = 0;
		while( timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			if( sdram_display_address_valid && sdram_display_address_ready ) begin
				break;
			end
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "wait_display_accept timeout" );
	end
	endtask

	// -----------------------------------------------------------------------
	//	不変条件モニタ
	// -----------------------------------------------------------------------
	integer disp_pending;
	always @( posedge clk ) begin
		if( reset ) begin
			disp_pending = 0;
		end
		else begin
			if( sdram_display_address_valid && sdram_display_address_ready ) begin
				disp_pending = disp_pending + BURST_WORDS;
			end
			if( sdram_display_rdata_valid ) begin
				if( disp_pending <= 0 ) begin
					$display("[TB][ERROR] stray display rdata beat (time=%0t)", $time);
					error_count = error_count + 1;
				end
				else begin
					disp_pending = disp_pending - 1;
				end
			end
			//	ストレス期間中は cache read を発行しないので、cache への beat は全て誤配送
			if( stress_monitor_enable && sdram_cache_rdata_valid ) begin
				$display("[TB][ERROR] cache rdata beat without cache read (time=%0t)", $time);
				error_count = error_count + 1;
			end
			//	cache が出した wdata beat は selector で落とされてはならない
			if( sdram_cache_wdata_valid !== sel_sdram_wdata_valid ) begin
				$display("[TB][ERROR] wdata_valid dropped by selector (time=%0t)", $time);
				error_count = error_count + 1;
			end
			//	burst stall 中の新規要求受理は仕様違反
			if( sel_sdram_address_valid && sel_sdram_address_ready && (u_dut.ff_write_stall || u_dut.ff_read_stall) ) begin
				$display("[TB][ERROR] request accepted during burst stall (time=%0t)", $time);
				error_count = error_count + 1;
			end
		end
	end

	// -----------------------------------------------------------------------
	//	メインシーケンス
	// -----------------------------------------------------------------------
	initial begin
		integer i;
		integer p;
		integer sel;
		integer gap;
		integer id_counter;
		integer timeout;

		clk = 1'b0;
		reset = 1'b1;
		error_count = 0;
		test_num = 0;
		stop_display = 1'b0;
		display_hammer_done = 1'b0;
		stress_monitor_enable = 1'b0;

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

		start_test("prefill display region A and write region B");
		for( i = 0; i < REGION_A_BURSTS; i = i + 1 ) begin
			cache_write_burst(18'h00200 + i[17:0], 8'h10 + i[7:0]);
		end
		for( i = 0; i < REGION_B_BURSTS; i = i + 1 ) begin
			cache_write_burst(18'h00300 + i[17:0], 8'h40 + i[7:0]);
			regionb_last_id[i] = 8'h40 + i[7:0];
		end
		issue_display_read(18'h00200);
		expect_display_read_burst(8'h10);

		stress_monitor_enable = 1'b1;
		fork
			display_hammer();
		join_none

		start_test("refresh request presented during write wdata streaming (beat 0..7)");
		id_counter = 0;
		for( p = 0; p < BURST_WORDS; p = p + 1 ) begin
			write_burst_with_refresh(18'h00300 + p[17:0], 8'h50 + p[7:0], p);
			regionb_last_id[p] = 8'h50 + p[7:0];
		end

		start_test("write burst issued at swept offsets after display accept");
		for( p = 0; p < 16; p = p + 1 ) begin
			wait_display_accept();
			repeat( p ) step();
			cache_write_burst(18'h00300 + (p % REGION_B_BURSTS), 8'h60 + p[7:0]);
			regionb_last_id[p % REGION_B_BURSTS] = 8'h60 + p[7:0];
		end

		start_test("refresh issued at swept offsets after display accept");
		for( p = 0; p < 16; p = p + 1 ) begin
			wait_display_accept();
			repeat( p ) step();
			issue_cache_request(18'd0, 1'b0, 1'b1);
		end

		start_test("random mix of writes and refreshes against display stream");
		for( p = 0; p < 100; p = p + 1 ) begin
			sel = $urandom_range(0, 2);
			gap = $urandom_range(0, 12);
			repeat( gap ) step();
			if( sel == 0 ) begin
				issue_cache_request(18'd0, 1'b0, 1'b1);
			end
			else begin
				i = $urandom_range(0, REGION_B_BURSTS - 1);
				id_counter = id_counter + 1;
				cache_write_burst(18'h00300 + i[17:0], 8'h80 + id_counter[6:0]);
				regionb_last_id[i] = 8'h80 + id_counter[6:0];
			end
		end

		//	display hammer を停止し、完了を待つ
		stop_display = 1'b1;
		timeout = 0;
		while( !display_hammer_done && timeout < TIMEOUT_CYCLES ) begin
			step();
			timeout = timeout + 1;
		end
		check( timeout < TIMEOUT_CYCLES, "display hammer stop timeout" );
		stress_monitor_enable = 1'b0;
		repeat(32) step();

		start_test("write data integrity after stress (region B readback)");
		for( i = 0; i < REGION_B_BURSTS; i = i + 1 ) begin
			issue_cache_request(18'h00300 + i[17:0], 1'b0, 1'b0);
			expect_cache_read_burst(regionb_last_id[i]);
		end

		$display("[TB] completed with %0d error(s)", error_count);
		if( error_count != 0 ) begin
			$fatal(1);
		end
		$finish;
	end

endmodule
