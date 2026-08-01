`timescale 1ns/1ps

module tb;
	localparam real CLK_HALF_NS						= 1000_000_000 / 108_000_000 / 2;   // 108MHz
	localparam integer TIMEOUT_CYCLES				= 5000;
	localparam integer REFRESH_INTERVAL_CYCLES_TB	= 80;

	reg				reset;
	reg				clk;
	reg				clk_sdram;

	reg		[22:1]	bus_address;
	reg				bus_write;
	reg		[15:0]	bus_wdata;
	reg				bus_flash;
	reg				bus_valid;
	wire			bus_ready;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;

	wire	[22:5]	sdram_cache_address;
	wire			sdram_cache_write;
	wire			sdram_cache_refresh;
	wire			sdram_cache_valid;
	wire	[31:0]	sdram_cache_wdata;
	wire	[3:0]	sdram_cache_wdata_mask;
	wire			sdram_cache_wdata_valid;
	wire	[31:0]	sdram_cache_rdata;
	wire			sdram_cache_rdata_valid;

	wire			sdram_init_busy;
	wire	[22:5]	ip_sdram_address;
	wire			ip_sdram_write;
	wire			ip_sdram_refresh;
	wire			ip_sdram_valid;
	wire			ip_sdram_ready;
	wire	[31:0]	ip_sdram_wdata;
	wire	[3:0]	ip_sdram_wdata_mask;
	wire			ip_sdram_wdata_valid;
	wire	[31:0]	ip_sdram_rdata;
	wire			ip_sdram_rdata_valid;

	// SDRAMの物理信号
	wire			sdram_clk;
	wire			sdram_cke;
	wire			sdram_cs_n;
	wire			sdram_ras_n;
	wire			sdram_cas_n;
	wire			sdram_wen_n;
	wire	[31:0]	sdram_dq;
	wire	[10:0]	sdram_addr;
	wire	[ 1:0]	sdram_ba;
	wire	[ 3:0]	sdram_dqm;

	integer			error_count;
	integer			sdram_write_req_count;
	integer			sdram_read_req_count;
	integer			sdram_refresh_req_count;
	integer			sdram_actual_write_count;
	integer			sdram_actual_read_count;
	reg		[22:1]	test_addr;
	reg		[22:1]	test_addr_lo;
	reg		[22:1]	test_addr2_hi;
	reg		[22:1]	test_addr2_lo;
	reg		[22:1]	test_addr3_hi;
	reg		[22:1]	test_addr3_lo;
	reg		[22:1]	same_hash_addr0;
	reg		[22:1]	same_hash_addr1;
	reg		[22:1]	same_hash_addr2;
	reg		[22:1]	same_hash_addr3;
	reg		[22:1]	same_hash_addr4;
	reg		[6:0]	test_hash;
	reg		[2:0]	test_word;
	reg			monitor_write_active;
	reg	[22:5]	monitor_write_addr;
	integer			monitor_write_beat;
	reg			monitor_write_overflow;
	reg			last_write_matched_same_hash_addr0;
	reg			last_write_data_hit_same_hash_addr0;
	integer			last_write_data_hit_beat_same_hash_addr0;

	cache #( .c_refresh_interval_cycles(REFRESH_INTERVAL_CYCLES_TB) ) u_dut ( .reset				( reset ),
		.clk				( clk ),
		.cache_address		( bus_address ),
		.cache_write		( bus_write ),
		.cache_wdata		( bus_wdata ),
		.cache_flush		( bus_flash ),
		.cache_valid		( bus_valid ),
		.cache_ready		( bus_ready ),
		.cache_rdata		( bus_rdata ),
		.cache_rdata_valid	( bus_rdata_valid ),
		.sdram_address		( sdram_cache_address ),
		.sdram_write		( sdram_cache_write ),
		.sdram_refresh		( sdram_cache_refresh ),
		.sdram_valid		( sdram_cache_valid ),
		.sdram_ready		( ip_sdram_ready ),
		.sdram_wdata		( sdram_cache_wdata ),
		.sdram_wdata_mask	( sdram_cache_wdata_mask ),
		.sdram_wdata_valid	( sdram_cache_wdata_valid ),
		.sdram_rdata		( ip_sdram_rdata ),
		.sdram_rdata_valid	( ip_sdram_rdata_valid ) );

	ip_sdram #( .FREQ(108_000_000) ) u_sdram_ctrl ( .reset				( reset ),
		.clk				( clk ),
		.clk_sdram			( clk_sdram ),
		.sdram_init_busy	( sdram_init_busy ),
		.bus_address		( sdram_cache_address ),
		.bus_write			( sdram_cache_write ),
		.bus_refresh		( sdram_cache_refresh ),
		.bus_valid			( sdram_cache_valid ),
		.bus_ready			( ip_sdram_ready ),
		.bus_wdata			( sdram_cache_wdata ),
		.bus_wdata_mask		( sdram_cache_wdata_mask ),
		.bus_wdata_valid	( sdram_cache_wdata_valid ),
		.bus_rdata			( ip_sdram_rdata ),
		.bus_rdata_valid	( ip_sdram_rdata_valid ),
		.O_sdram_clk		( sdram_clk ),
		.O_sdram_cke		( sdram_cke ),
		.O_sdram_cs_n		( sdram_cs_n ),
		.O_sdram_ras_n		( sdram_ras_n ),
		.O_sdram_cas_n		( sdram_cas_n ),
		.O_sdram_wen_n		( sdram_wen_n ),
		.IO_sdram_dq		( sdram_dq ),
		.O_sdram_addr		( sdram_addr ),
		.O_sdram_ba			( sdram_ba ),
		.O_sdram_dqm		( sdram_dqm ) );

	mt48lc2m32b2 u_sdram_model ( .Dq					( sdram_dq ),
		.Addr				( sdram_addr ),
		.Ba					( sdram_ba ),
		.Clk				( sdram_clk ),
		.Cke				( sdram_cke ),
		.Cs_n				( sdram_cs_n ),
		.Ras_n				( sdram_ras_n ),
		.Cas_n				( sdram_cas_n ),
		.We_n				( sdram_wen_n ),
		.Dqm				( sdram_dqm ) );

	always #(CLK_HALF_NS ) begin
		clk <= ~clk;
	end

	// clk_sdramはclkに対して180度位相がずれている
	// 初期状態ではclk_sdram=1（clk=0と逆相）として開始する
	always #(CLK_HALF_NS ) begin
		clk_sdram <= ~clk_sdram;
	end

	function [31:0] apply_dqm;
		input [31:0] old_data;
		input [31:0] new_data;
		input [3:0] dqm;
		begin
			apply_dqm[7:0] = dqm[0] ? old_data[7:0] : new_data[7:0];
			apply_dqm[15:8] = dqm[1] ? old_data[15:8] : new_data[15:8];
			apply_dqm[23:16] = dqm[2] ? old_data[23:16] : new_data[23:16];
			apply_dqm[31:24] = dqm[3] ? old_data[31:24] : new_data[31:24];
		end
	endfunction

	task automatic cache_write16;
		input [22:1] addr;
		input [15:0] data;
		integer timeout;
		begin
			timeout = 0;
			@(negedge clk );
			bus_address <= addr;
			bus_write <= 1'b1;
			bus_wdata <= data;
			bus_flash <= 1'b0;
			bus_valid <= 1'b1;
			while( !bus_ready && timeout < TIMEOUT_CYCLES ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			if( timeout >= TIMEOUT_CYCLES ) begin
				$display( "[TB][ERROR] write timeout addr=%h data=%h", addr, data );
				error_count = error_count + 1;
			end
			@(negedge clk );
			bus_valid <= 1'b0;
			bus_write <= 1'b0;
			bus_wdata <= 16'h0000;
			bus_address <= 22'd0;
		end
	endtask

	task automatic cache_read16;
		input [22:1] addr;
		output [15:0] data;
		integer timeout;
		begin
			timeout = 0;
			data = 16'h0000;
			@(negedge clk );
			bus_address <= addr;
			bus_write <= 1'b0;
			bus_flash <= 1'b0;
			bus_valid <= 1'b1;
			while( !bus_ready && timeout < TIMEOUT_CYCLES ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			if( timeout >= TIMEOUT_CYCLES ) begin
				$display( "[TB][ERROR] read request timeout addr=%h", addr );
				error_count = error_count + 1;
			end
			@(negedge clk );
			bus_valid <= 1'b0;
			bus_address <= 22'd0;

			timeout = 0;
			while( !bus_rdata_valid && timeout < TIMEOUT_CYCLES ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			if( timeout >= TIMEOUT_CYCLES ) begin
				$display( "[TB][ERROR] read response timeout addr=%h", addr );
				error_count = error_count + 1;
			end else begin
				data = bus_rdata;
			end
		end
	endtask

	task automatic cache_flush;
		integer timeout;
		begin
			timeout = 0;
			@(negedge clk );
			bus_flash <= 1'b1;
			bus_write <= 1'b0;
			bus_valid <= 1'b1;

			// DUTがアイドル状態を離れるまで待機する（要求が受理された状態）
			while( bus_ready && timeout < (TIMEOUT_CYCLES * 4) ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			if( timeout >= (TIMEOUT_CYCLES * 4) ) begin
				$display( "[TB][ERROR] flush start timeout" );
				error_count = error_count + 1;
			end

			@(negedge clk );
			bus_valid <= 1'b0;
			bus_flash <= 1'b0;

			// フラッシュ処理が完了し、DUTがアイドル状態に戻るまで待機する
			timeout = 0;
			while( !bus_ready && timeout < (TIMEOUT_CYCLES * 16) ) begin
				@( posedge clk );
				timeout = timeout + 1;
			end
			if( timeout >= (TIMEOUT_CYCLES * 16) ) begin
				$display( "[TB][ERROR] flush completion timeout" );
				error_count = error_count + 1;
			end
		end
	endtask

	// ---------------------------------------------------------
	//	SDRAMモニター
	// ---------------------------------------------------------
	initial begin
		$display( "[TB][INFO] SDRAM monitor started" );
		forever begin
			@( posedge clk );
			if( sdram_cache_valid && ip_sdram_ready ) begin
				if( sdram_cache_refresh ) begin
					sdram_refresh_req_count = sdram_refresh_req_count + 1;
					$display( "[TB][SDRAM] refresh req" );
				end
				else if( sdram_cache_write ) begin
					sdram_write_req_count = sdram_write_req_count + 1;
					monitor_write_active = 1'b1;
					monitor_write_addr = sdram_cache_address;
					monitor_write_beat = 0;
					monitor_write_overflow = 1'b0;
					last_write_matched_same_hash_addr0 = (sdram_cache_address == same_hash_addr0[22:5]);
					last_write_data_hit_same_hash_addr0 = 1'b0;
					last_write_data_hit_beat_same_hash_addr0 = -1;
					$display( "[TB][SDRAM] write req: addr=%h data=%h mask=%b", sdram_cache_address, sdram_cache_wdata, sdram_cache_wdata_mask );
				end
				else begin
					sdram_read_req_count = sdram_read_req_count + 1;
					$display( "[TB][SDRAM] read req: addr=%h", sdram_cache_address );
				end
			end
			if( sdram_cache_wdata_valid ) begin
				sdram_actual_write_count = sdram_actual_write_count + 1;
				$display( "[TB][SDRAM] write beat: addr=%h beat=%0d data=%h mask=%b", monitor_write_addr, monitor_write_beat, sdram_cache_wdata, sdram_cache_wdata_mask );
				if( !monitor_write_active ) begin
					monitor_write_overflow = 1'b1;
				end
				if( last_write_matched_same_hash_addr0 && (sdram_cache_wdata[15:0] == 16'h1001) && (sdram_cache_wdata_mask[1:0] == 2'b00) ) begin
					last_write_data_hit_same_hash_addr0 = 1'b1;
					last_write_data_hit_beat_same_hash_addr0 = monitor_write_beat;
				end
				if( monitor_write_beat == 7 ) begin
					monitor_write_active = 1'b0;
				end
				else begin
					monitor_write_beat = monitor_write_beat + 1;
				end
			end
			if( ip_sdram_rdata_valid ) begin
				sdram_actual_read_count = sdram_actual_read_count + 1;
			end
		end
	end

	// ---------------------------------------------------------
	//	テストシナリオ
	// ---------------------------------------------------------
	reg [15:0] rd;
	reg [15:0] rd2;
	integer i;
	integer test_number;

	task automatic reset_sdram_counters;
	begin
		sdram_write_req_count = 0;
		sdram_read_req_count = 0;
		sdram_refresh_req_count = 0;
		sdram_actual_write_count = 0;
		sdram_actual_read_count = 0;
		monitor_write_active = 1'b0;
		monitor_write_addr = 18'd0;
		monitor_write_beat = 0;
		monitor_write_overflow = 1'b0;
		last_write_matched_same_hash_addr0 = 1'b0;
		last_write_data_hit_same_hash_addr0 = 1'b0;
		last_write_data_hit_beat_same_hash_addr0 = -1;
	end
	endtask

	task automatic start_test;
		input integer number;
		input string title;
	begin
		test_number = number;
		$display( "-----------------" );
		$display( "[TB][TEST%0d] %s", test_number, title );
	end
	endtask

	initial begin
		clk = 1'b0;
		clk_sdram = 1'b1;		// 180 degree phase shift to clk
		reset = 1'b1;
		bus_address = 22'd0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
		bus_flash = 1'b0;
		bus_valid = 1'b0;
		error_count = 0;
		test_number = 0;
		monitor_write_active = 1'b0;
		monitor_write_addr = 18'd0;
		monitor_write_beat = 0;
		monitor_write_overflow = 1'b0;
		last_write_matched_same_hash_addr0 = 1'b0;
		last_write_data_hit_same_hash_addr0 = 1'b0;
		last_write_data_hit_beat_same_hash_addr0 = -1;

		// ---------------------------------------------------------
		// 初期化中の信号を監視する
		// ---------------------------------------------------------
		#1000;
		$display( "[TB][DEBUG] After 1us: reset=%d, clk=%d, sdram_init_busy=%d", reset, clk, sdram_init_busy );
		$display( "[TB][DEBUG] bus_ready=%d, bus_rdata_valid=%d", bus_ready, bus_rdata_valid );
		$display( "[TB][DEBUG] ip_sdram: bus_ready=%d, ff_main_state check via bus_ready", ip_sdram_ready );

		repeat( 8 ) @( posedge clk );
		reset = 1'b0;

		// ---------------------------------------------------------
		// SDRAMの初期化完了を待機する
		// ---------------------------------------------------------
		repeat( 20 ) @( posedge clk );
		if( sdram_init_busy ) begin
			$display( "[TB][INFO] waiting for SDRAM init..." );
			while( sdram_init_busy ) begin
				@( posedge clk );
			end
		end
		$display( "[TB][INFO] SDRAM init complete at time %0d", $time );

		// キャッシュタグの初期化完了を待機する
		repeat( 160 ) @( posedge clk );

		test_addr = 22'h000126;
		test_addr_lo = 22'h000124;
		test_addr2_hi = 22'h000326;
		test_addr2_lo = 22'h000324;
		test_addr3_hi = 22'h000526;
		test_addr3_lo = 22'h000524;
		same_hash_addr0 = 22'h000726;
		same_hash_addr1 = 22'h001726;
		same_hash_addr2 = 22'h002726;
		same_hash_addr3 = 22'h003726;
		same_hash_addr4 = 22'h004726;
		test_hash = test_addr[11:5];
		test_word = test_addr[4:2];

		// ---------------------------------------------------------
		//	テスト１：
		//	キャッシュミスの発生とSDRAMからのフェッチを確認する
		// ---------------------------------------------------------
		start_test( 1, "read miss then fill" );
		reset_sdram_counters( );
		$display( "[TB][DEBUG] Before read: addr=%h, bus_ready=%d", test_addr, bus_ready );
		cache_read16(test_addr, rd );
		$display( "[TB][DEBUG] After read: rd=%04h", rd );
		// 最初の読み出しは未初期化のSDRAMから行われるため、応答が返ってくることだけを確認する
		// （SDRAMモデルは未初期化データとしてxxxxを返す）
		// 実際の検証はTEST3/TEST4で、書き込み・フラッシュ・再読み出しを行う際に行う
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST1 unexpected write request count got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 1) else begin
			$display( "[TB][ERROR] TEST1 unexpected read request count got=%0d exp=1", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST1 unexpected actual write count got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 8) else begin
			$display( "[TB][ERROR] TEST1 unexpected actual read count got=%0d exp=8", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST1 actual write count ratio mismatch got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST1 actual read count ratio mismatch got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end
		$display( "[TB][OK] TEST1 read response received (cache fill from SDRAM working)" );

		start_test( 2, "write hit then read back" );
		reset_sdram_counters( );
		cache_write16(test_addr, 16'hA55A );
		cache_read16(test_addr, rd );
		if( rd !== 16'hA55A ) begin
			$display( "[TB][ERROR] TEST2 read-back mismatch got=%04h exp=A55A", rd );
			error_count = error_count + 1;
		end else begin
			$display( "[TB][OK] TEST2 write-back verified" );
		end
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST2 unexpected write request count got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 0) else begin
			$display( "[TB][ERROR] TEST2 unexpected read request count got=%0d exp=0", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST2 unexpected actual write count got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 0) else begin
			$display( "[TB][ERROR] TEST2 unexpected actual read count got=%0d exp=0", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST2 actual write count ratio mismatch got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST2 actual read count ratio mismatch got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end

		start_test( 3, "flush then SDRAM writeback" );
		reset_sdram_counters( );
		cache_flush( );
		repeat( 100 ) @( posedge clk );  // フラッシュがSDRAMへ到達するのを待つ
		assert (sdram_write_req_count == 1) else begin
			$display( "[TB][ERROR] TEST3 unexpected write request count got=%0d exp=1", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 0) else begin
			$display( "[TB][ERROR] TEST3 unexpected read request count got=%0d exp=0", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 8) else begin
			$display( "[TB][ERROR] TEST3 unexpected actual write count got=%0d exp=8", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 0) else begin
			$display( "[TB][ERROR] TEST3 unexpected actual read count got=%0d exp=0", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST3 actual write count ratio mismatch got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST3 actual read count ratio mismatch got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end
		$display( "[TB][OK] TEST3 flush completed" );

		start_test( 4, "refresh auto event and continued access" );
		reset_sdram_counters( );
		for( i = 0; i < 200; i = i + 1 ) begin
			@( posedge clk );
		end
		cache_read16(test_addr, rd );
		if( rd !== 16'hA55A ) begin
			$display( "[TB][ERROR] TEST4 post-refresh read mismatch got=%04h exp=A55A", rd );
			error_count = error_count + 1;
		end else begin
			$display( "[TB][OK] TEST4 post-refresh verified" );
		end
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST4 unexpected write request count got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 1) else begin
			$display( "[TB][ERROR] TEST4 unexpected read request count got=%0d exp=1", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST4 unexpected actual write count got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 8) else begin
			$display( "[TB][ERROR] TEST4 unexpected actual read count got=%0d exp=8", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (sdram_refresh_req_count >= 1) else begin
			$display( "[TB][ERROR] TEST4 expected refresh request during idle wait got=%0d", sdram_refresh_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST4 actual write count ratio mismatch got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST4 actual read count ratio mismatch got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end

		start_test( 5, "write miss preserves untouched halfword and partial refill keeps dirty halfword" );
		cache_read16(test_addr2_lo, rd );
		cache_write16(test_addr2_lo, 16'h1234 );
		cache_write16(test_addr2_hi, 16'h5678 );
		cache_flush( );

		reset_sdram_counters( );
		cache_write16(test_addr2_hi, 16'hA55A );
		cache_read16(test_addr2_lo, rd );
		if( rd !== 16'h1234 ) begin
			$display( "[TB][ERROR] TEST5 partial refill lower-half mismatch got=%04h exp=1234", rd );
			error_count = error_count + 1;
		end
		cache_read16(test_addr2_hi, rd2 );
		if( rd2 !== 16'hA55A ) begin
			$display( "[TB][ERROR] TEST5 dirty upper-half lost after partial refill got=%04h exp=A55A", rd2 );
			error_count = error_count + 1;
		end
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST5 unexpected write request count during partial refill got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST5 unexpected actual write count during partial refill got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST5 actual write count ratio mismatch during partial refill got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST5 actual read count ratio mismatch during partial refill got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end

		reset_sdram_counters( );
		cache_flush( );
		cache_read16(test_addr2_lo, rd );
		cache_read16(test_addr2_hi, rd2 );
		if( rd !== 16'h1234 ) begin
			$display( "[TB][ERROR] TEST5 persisted lower-half mismatch got=%04h exp=1234", rd );
			error_count = error_count + 1;
		end
		if( rd2 !== 16'hA55A ) begin
			$display( "[TB][ERROR] TEST5 persisted upper-half mismatch got=%04h exp=A55A", rd2 );
			error_count = error_count + 1;
		end
		assert (sdram_write_req_count == 1) else begin
			$display( "[TB][ERROR] TEST5 unexpected write request count during persist check got=%0d exp=1", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 1) else begin
			$display( "[TB][ERROR] TEST5 unexpected read request count during persist check got=%0d exp=1", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 8) else begin
			$display( "[TB][ERROR] TEST5 unexpected actual write count during persist check got=%0d exp=8", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 8) else begin
			$display( "[TB][ERROR] TEST5 unexpected actual read count during persist check got=%0d exp=8", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST5 actual write count ratio mismatch during persist check got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST5 actual read count ratio mismatch during persist check got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end
		$display( "[TB][OK] TEST5 halfword write-miss and partial refill verified" );

		start_test( 6, "reverse partial refill keeps dirty lower halfword" );
		cache_read16(test_addr3_lo, rd );
		cache_write16(test_addr3_lo, 16'h1357 );
		cache_write16(test_addr3_hi, 16'h2468 );
		cache_flush( );

		reset_sdram_counters( );
		cache_write16(test_addr3_lo, 16'h0F0F );
		cache_read16(test_addr3_hi, rd2 );
		if( rd2 !== 16'h2468 ) begin
			$display( "[TB][ERROR] TEST6 partial refill upper-half mismatch got=%04h exp=2468", rd2 );
			error_count = error_count + 1;
		end
		cache_read16(test_addr3_lo, rd );
		if( rd !== 16'h0F0F ) begin
			$display( "[TB][ERROR] TEST6 dirty lower-half lost after partial refill got=%04h exp=0F0F", rd );
			error_count = error_count + 1;
		end
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST6 unexpected write request count during partial refill got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST6 unexpected actual write count during partial refill got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == (sdram_write_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST6 actual write count ratio mismatch during partial refill got=%0d req=%0d", sdram_actual_write_count, sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == (sdram_read_req_count * 8)) else begin
			$display( "[TB][ERROR] TEST6 actual read count ratio mismatch during partial refill got=%0d req=%0d", sdram_actual_read_count, sdram_read_req_count );
			error_count = error_count + 1;
		end
		$display( "[TB][OK] TEST6 reverse partial refill verified" );

		start_test( 7, "same-hash 4way fill stays on-cache and 5th write evicts oldest dirty line" );
		reset_sdram_counters( );
		cache_write16(same_hash_addr0, 16'h1001 );
		cache_write16(same_hash_addr1, 16'h2002 );
		cache_write16(same_hash_addr2, 16'h3003 );
		cache_write16(same_hash_addr3, 16'h4004 );
		cache_read16(same_hash_addr0, rd );
		if( rd !== 16'h1001 ) begin
			$display( "[TB][ERROR] TEST7 way0 read-back mismatch got=%04h exp=1001", rd );
			error_count = error_count + 1;
		end
		cache_read16(same_hash_addr1, rd );
		if( rd !== 16'h2002 ) begin
			$display( "[TB][ERROR] TEST7 way1 read-back mismatch got=%04h exp=2002", rd );
			error_count = error_count + 1;
		end
		cache_read16(same_hash_addr2, rd );
		if( rd !== 16'h3003 ) begin
			$display( "[TB][ERROR] TEST7 way2 read-back mismatch got=%04h exp=3003", rd );
			error_count = error_count + 1;
		end
		cache_read16(same_hash_addr3, rd );
		if( rd !== 16'h4004 ) begin
			$display( "[TB][ERROR] TEST7 way3 read-back mismatch got=%04h exp=4004", rd );
			error_count = error_count + 1;
		end
		assert (sdram_write_req_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected write request count during 4way fill got=%0d exp=0", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected read request count during 4way fill got=%0d exp=0", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual write count during 4way fill got=%0d exp=0", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual read count during 4way fill got=%0d exp=0", sdram_actual_read_count );
			error_count = error_count + 1;
		end

		reset_sdram_counters( );
		cache_write16(same_hash_addr4, 16'h5005 );
		repeat( 100 ) @( posedge clk );
		assert (sdram_write_req_count == 1) else begin
			$display( "[TB][ERROR] TEST7 unexpected write request count during 5th write got=%0d exp=1", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected read request count during 5th write got=%0d exp=0", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 8) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual write count during 5th write got=%0d exp=8", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 0) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual read count during 5th write got=%0d exp=0", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		assert (last_write_matched_same_hash_addr0) else begin
			$display( "[TB][ERROR] TEST7 evict write address mismatch got=%h exp=%h", monitor_write_addr, same_hash_addr0[22:5] );
			error_count = error_count + 1;
		end
		assert (last_write_data_hit_same_hash_addr0) else begin
			$display( "[TB][ERROR] TEST7 evict write data missing exp lower16=1001 addr=%h", same_hash_addr0[22:5] );
			error_count = error_count + 1;
		end
		assert (last_write_data_hit_beat_same_hash_addr0 == same_hash_addr0[4:2]) else begin
			$display( "[TB][ERROR] TEST7 evict write beat mismatch got=%0d exp=%0d", last_write_data_hit_beat_same_hash_addr0, same_hash_addr0[4:2] );
			error_count = error_count + 1;
		end
		assert (!monitor_write_overflow) else begin
			$display( "[TB][ERROR] TEST7 unexpected write beat overflow for addr=%h", same_hash_addr0[22:5] );
			error_count = error_count + 1;
		end

		reset_sdram_counters( );
		cache_read16(same_hash_addr0, rd );
		if( rd !== 16'h1001 ) begin
			$display( "[TB][ERROR] TEST7 evicted line reload mismatch got=%04h exp=1001", rd );
			error_count = error_count + 1;
		end
		assert (sdram_write_req_count == 1) else begin
			$display( "[TB][ERROR] TEST7 unexpected write request count during evicted-line reload got=%0d exp=1", sdram_write_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_read_req_count == 1) else begin
			$display( "[TB][ERROR] TEST7 unexpected read request count during evicted-line reload got=%0d exp=1", sdram_read_req_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_write_count == 8) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual write count during evicted-line reload got=%0d exp=8", sdram_actual_write_count );
			error_count = error_count + 1;
		end
		assert (sdram_actual_read_count == 8) else begin
			$display( "[TB][ERROR] TEST7 unexpected actual read count during evicted-line reload got=%0d exp=8", sdram_actual_read_count );
			error_count = error_count + 1;
		end
		$display( "[TB][OK] TEST7 4way same-hash fill and dirty eviction verified" );

		if( error_count == 0 ) begin
			$display( "[TB] ALL TESTS PASSED" );
		end
		else begin
			$display( "[TB] FAILED with %0d errors", error_count );
		end

		repeat( 20 ) @( posedge clk );
		$finish;
	end

	// ---------------------------------------------------------
	//	タイムアウトした場合には強制終了
	// ---------------------------------------------------------
	initial begin
		repeat( TIMEOUT_CYCLES * 50 ) @( posedge clk );
		$display( "[TB][TIMEOUT]" );
		$stop;
	end
endmodule

