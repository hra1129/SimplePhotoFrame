`timescale 1ns/1ps

module tb;
	localparam integer CLK_HALF_NS = 1000000000 / 108000000 / 2;
	localparam integer TIMEOUT_CYCLES = 500000;
	localparam integer BLOCK_WORDS = 4096;
	localparam integer TRACK_BLOCKS = 1;
	localparam integer LAST_ADDR = BLOCK_WORDS - 1;
	localparam integer WRITE_WORDS = LAST_ADDR + 1;
	localparam integer REFRESH_INTERVAL_CYCLES_TB = 32'h7fffffff;

	reg				reset;
	reg				clk;

	reg		[22:1]	cache_address;
	reg				cache_write;
	reg		[15:0]	cache_wdata;
	reg				cache_flush;
	reg				cache_valid;
	wire			cache_ready;
	wire	[15:0]	cache_rdata;
	wire			cache_rdata_valid;

	wire	[22:5]	sdram_address;
	wire			sdram_write;
	wire			sdram_refresh;
	wire			sdram_valid;
	reg				sdram_ready;
	wire	[31:0]	sdram_wdata;
	wire	[3:0]	sdram_wdata_mask;
	wire			sdram_wdata_valid;
	reg		[31:0]	sdram_rdata;
	reg				sdram_rdata_valid;

	reg				stream_active;
	reg		[22:5]	stream_base_addr;
	integer			stream_beat;
	integer			stream_block_index;
	integer			stream_checked_halfwords;
	integer			req_debug_print_count;

	integer			error_count;
	integer			write_req_count;
	integer			write_beat_count;
	integer			checked_halfword_count;
	integer			timeout;
	integer			addr;
	integer			low_word_addr;
	integer			high_word_addr;
	integer			block_index;
	integer			req_block_index;
	integer			stream_start_word_addr;
	integer			req_key_index;
	integer			bi;
	integer			ki;
	reg		[15:0]	expected_low;
	reg		[15:0]	expected_high;
	integer			checked_block_count [0:TRACK_BLOCKS-1];
	integer			req_block_count [0:TRACK_BLOCKS-1];
	integer			masked_req_block_count [0:TRACK_BLOCKS-1];
	integer			req_key_count [0:31];
	integer			req_way_count [0:7];

	cache #( .c_refresh_interval_cycles(REFRESH_INTERVAL_CYCLES_TB) ) u_dut (
		.reset				( reset				),
		.clk				( clk				),
		.cache_address		( cache_address		),
		.cache_write		( cache_write		),
		.cache_wdata		( cache_wdata		),
		.cache_flush		( cache_flush		),
		.cache_valid		( cache_valid		),
		.cache_ready		( cache_ready		),
		.cache_rdata		( cache_rdata		),
		.cache_rdata_valid	( cache_rdata_valid	),
		.sdram_address		( sdram_address		),
		.sdram_write		( sdram_write		),
		.sdram_refresh		( sdram_refresh		),
		.sdram_valid		( sdram_valid		),
		.sdram_ready		( sdram_ready		),
		.sdram_wdata		( sdram_wdata		),
		.sdram_wdata_mask	( sdram_wdata_mask	),
		.sdram_wdata_valid	( sdram_wdata_valid	),
		.sdram_rdata		( sdram_rdata		),
		.sdram_rdata_valid	( sdram_rdata_valid	)
	);

	always #(CLK_HALF_NS) begin
		clk <= ~clk;
	end

	task automatic cache_write16;
		input [22:1] addr_in;
		input [15:0] data_in;
		integer local_timeout;
		begin
			local_timeout = 0;
			@(posedge clk);
			cache_address <= addr_in;
			cache_write <= 1'b1;
			cache_wdata <= data_in;
			cache_flush <= 1'b0;
			cache_valid <= 1'b1;

			while( !cache_ready && local_timeout < TIMEOUT_CYCLES ) begin
				@(posedge clk);
				local_timeout = local_timeout + 1;
			end

			if( local_timeout >= TIMEOUT_CYCLES ) begin
				$display("[TB][ERROR] write timeout addr=%0d", addr_in);
				error_count = error_count + 1;
			end

			@(posedge clk);
			cache_valid <= 1'b0;
			cache_write <= 1'b0;
			cache_wdata <= 16'h0000;
			cache_address <= 22'd0;
		end
	endtask

	task automatic cache_issue_flush;
		integer local_timeout;
		begin
			local_timeout = 0;
			@(posedge clk);
			cache_write <= 1'b0;
			cache_flush <= 1'b1;
			cache_valid <= 1'b1;

			while( !cache_ready && local_timeout < TIMEOUT_CYCLES ) begin
				@(posedge clk);
				local_timeout = local_timeout + 1;
			end
			if( local_timeout >= TIMEOUT_CYCLES ) begin
				$display("[TB][ERROR] flush wait-ready timeout");
				error_count = error_count + 1;
			end

			local_timeout = 0;
			while( cache_ready && local_timeout < TIMEOUT_CYCLES ) begin
				@(posedge clk);
				local_timeout = local_timeout + 1;
			end
			if( local_timeout >= TIMEOUT_CYCLES ) begin
				$display("[TB][ERROR] flush start timeout");
				error_count = error_count + 1;
			end

			@(posedge clk);
			cache_valid <= 1'b0;
			cache_flush <= 1'b0;

			local_timeout = 0;
			while( !cache_ready && local_timeout < TIMEOUT_CYCLES ) begin
				@(posedge clk);
				local_timeout = local_timeout + 1;
			end
			if( local_timeout >= TIMEOUT_CYCLES ) begin
				$display("[TB][ERROR] flush completion timeout");
				error_count = error_count + 1;
			end
		end
	endtask

	always @(posedge clk) begin
		if( reset ) begin
			stream_active <= 1'b0;
			stream_base_addr <= 18'd0;
			stream_beat <= 0;
			write_req_count <= 0;
			write_beat_count <= 0;
			checked_halfword_count <= 0;
			stream_block_index <= 0;
			stream_checked_halfwords <= 0;
			req_debug_print_count <= 0;
			for( bi = 0; bi < TRACK_BLOCKS; bi = bi + 1 ) begin
				checked_block_count[bi] <= 0;
				req_block_count[bi] <= 0;
				masked_req_block_count[bi] <= 0;
			end
			for( ki = 0; ki < 32; ki = ki + 1 ) begin
				req_key_count[ki] <= 0;
			end
			for( ki = 0; ki < 8; ki = ki + 1 ) begin
				req_way_count[ki] <= 0;
			end
		end
		else begin
			if( sdram_valid && sdram_ready && sdram_write ) begin
				if( stream_active ) begin
					$display("[TB][ERROR] write request while previous stream is active");
					error_count = error_count + 1;
				end
				stream_start_word_addr = {sdram_address, 4'b0000};
				req_block_index = stream_start_word_addr / BLOCK_WORDS;
				stream_active <= 1'b1;
				stream_base_addr <= sdram_address;
				stream_beat <= 0;
				stream_checked_halfwords <= 0;
				stream_block_index <= req_block_index;
				write_req_count <= write_req_count + 1;
				if( req_block_index < TRACK_BLOCKS ) begin
					req_block_count[req_block_index] = req_block_count[req_block_index] + 1;
				end
				req_key_index = u_dut.ff_evict_key;
				if( req_key_index < 32 ) begin
					req_key_count[req_key_index] = req_key_count[req_key_index] + 1;
				end
				req_way_count[u_dut.ff_selected_way] = req_way_count[u_dut.ff_selected_way] + 1;
				if( req_debug_print_count < 32 ) begin
					$display("[TB][REQ] n=%0d key=%0d way=%0d block=%0d",
						req_debug_print_count,
						req_key_index,
						u_dut.ff_selected_way,
						req_block_index);
					req_debug_print_count <= req_debug_print_count + 1;
				end
			end

			if( sdram_wdata_valid ) begin
				if( !stream_active ) begin
					$display("[TB][ERROR] write beat without active request");
					error_count = error_count + 1;
				end
				else begin
					write_beat_count <= write_beat_count + 1;
					low_word_addr = {stream_base_addr, stream_beat[2:0], 1'b0};
					high_word_addr = {stream_base_addr, stream_beat[2:0], 1'b1};
					expected_low = low_word_addr[15:0];
					expected_high = high_word_addr[15:0];

					if( sdram_wdata_mask[1:0] == 2'b00 ) begin
						if( low_word_addr < WRITE_WORDS ) begin
							checked_halfword_count = checked_halfword_count + 1;
							stream_checked_halfwords <= stream_checked_halfwords + 1;
							block_index = low_word_addr / BLOCK_WORDS;
							if( block_index < TRACK_BLOCKS ) begin
								checked_block_count[block_index] = checked_block_count[block_index] + 1;
							end
							if( sdram_wdata[15:0] !== expected_low ) begin
								$display("[TB][ERROR] low mismatch req=%0d beat=%0d addr=%0d exp=%04h got=%04h mask=%b",
									write_req_count, stream_beat, low_word_addr, expected_low, sdram_wdata[15:0], sdram_wdata_mask);
								error_count = error_count + 1;
							end
						end
					end
					else if( sdram_wdata_mask[1:0] != 2'b11 ) begin
						$display("[TB][ERROR] unexpected low mask pattern req=%0d beat=%0d mask=%b", write_req_count, stream_beat, sdram_wdata_mask);
						error_count = error_count + 1;
					end

					if( sdram_wdata_mask[3:2] == 2'b00 ) begin
						if( high_word_addr < WRITE_WORDS ) begin
							checked_halfword_count = checked_halfword_count + 1;
							stream_checked_halfwords <= stream_checked_halfwords + 1;
							block_index = high_word_addr / BLOCK_WORDS;
							if( block_index < TRACK_BLOCKS ) begin
								checked_block_count[block_index] = checked_block_count[block_index] + 1;
							end
							if( sdram_wdata[31:16] !== expected_high ) begin
								$display("[TB][ERROR] high mismatch req=%0d beat=%0d addr=%0d exp=%04h got=%04h mask=%b",
									write_req_count, stream_beat, high_word_addr, expected_high, sdram_wdata[31:16], sdram_wdata_mask);
								error_count = error_count + 1;
							end
						end
					end
					else if( sdram_wdata_mask[3:2] != 2'b11 ) begin
						$display("[TB][ERROR] unexpected high mask pattern req=%0d beat=%0d mask=%b", write_req_count, stream_beat, sdram_wdata_mask);
						error_count = error_count + 1;
					end

					if( stream_beat == 7 ) begin
						if( stream_checked_halfwords == 0 ) begin
							if( stream_block_index < TRACK_BLOCKS ) begin
								masked_req_block_count[stream_block_index] = masked_req_block_count[stream_block_index] + 1;
							end
						end
						stream_active <= 1'b0;
						stream_beat <= 0;
						stream_checked_halfwords <= 0;
					end
					else begin
						stream_beat <= stream_beat + 1;
					end
				end
			end
		end
	end

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		cache_address = 22'd0;
		cache_write = 1'b0;
		cache_wdata = 16'd0;
		cache_flush = 1'b0;
		cache_valid = 1'b0;
		sdram_ready = 1'b1;
		sdram_rdata = 32'd0;
		sdram_rdata_valid = 1'b0;
		error_count = 0;
		write_req_count = 0;
		write_beat_count = 0;
		checked_halfword_count = 0;
		for( bi = 0; bi < TRACK_BLOCKS; bi = bi + 1 ) begin
			checked_block_count[bi] = 0;
			req_block_count[bi] = 0;
			masked_req_block_count[bi] = 0;
		end
		for( ki = 0; ki < 32; ki = ki + 1 ) begin
			req_key_count[ki] = 0;
		end
		for( ki = 0; ki < 8; ki = ki + 1 ) begin
			req_way_count[ki] = 0;
		end
		stream_active = 1'b0;
		stream_base_addr = 18'd0;
		stream_beat = 0;
		stream_block_index = 0;
		stream_checked_halfwords = 0;
		req_debug_print_count = 0;

		repeat(8) @(posedge clk);
		reset = 1'b0;

		timeout = 0;
		while( !cache_ready && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] cache init timeout");
			$finish(1);
		end

		$display("[TB] write phase start (0..%0d, exceeds 3000 words)", LAST_ADDR);
		for( addr = 0; addr <= LAST_ADDR; addr = addr + 1 ) begin
			cache_write16( addr[21:0], addr[15:0] );
		end
		$display("[TB] write phase done");
		cache_issue_flush();
		$display("[TB] flush done");

		repeat(128) @(posedge clk);

		if( stream_active ) begin
			$display("[TB][ERROR] stream still active at end");
			error_count = error_count + 1;
		end

		$display("[TB] stats: write_req=%0d write_beat=%0d checked_halfword=%0d error=%0d",
			write_req_count, write_beat_count, checked_halfword_count, error_count);
		for( bi = 0; bi < TRACK_BLOCKS; bi = bi + 1 ) begin
			$display("[TB] block[%0d] range=%0d..%0d req=%0d masked_req=%0d checked=%0d",
				bi,
				bi * BLOCK_WORDS,
				((bi + 1) * BLOCK_WORDS) - 1,
				req_block_count[bi],
				masked_req_block_count[bi],
				checked_block_count[bi]);
		end
		for( ki = 0; ki < 32; ki = ki + 1 ) begin
			if( req_key_count[ki] != 0 ) begin
				$display("[TB] key[%0d] req=%0d", ki, req_key_count[ki]);
			end
		end
		$display("[TB] way_count: w0=%0d w1=%0d w2=%0d w3=%0d w4=%0d w5=%0d w6=%0d w7=%0d",
			req_way_count[0], req_way_count[1], req_way_count[2], req_way_count[3],
			req_way_count[4], req_way_count[5], req_way_count[6], req_way_count[7]);

		if( write_req_count == 0 ) begin
			$display("[TB][ERROR] no write-back request observed");
			error_count = error_count + 1;
		end

		if( checked_halfword_count == 0 ) begin
			$display("[TB][ERROR] no halfword was checked");
			error_count = error_count + 1;
		end

		if( checked_block_count[0] != BLOCK_WORDS ) begin
			$display("[TB][ERROR] block0 coverage mismatch checked=%0d exp=%0d", checked_block_count[0], BLOCK_WORDS);
			error_count = error_count + 1;
		end

		if( error_count == 0 ) begin
			$display("[TB] PASS");
			$finish;
		end
		else begin
			$display("[TB] FAIL");
			$finish(1);
		end
	end
endmodule
