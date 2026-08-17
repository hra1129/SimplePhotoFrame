//
// cache.v
//   Cache
//   Revision 1.00
//
// Copyright (c) 2026 Takayuki Hara.
// All rights reserved.
//
// Redistribution and use of this source code or any derivative works, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Redistributions may not be sold, nor may they be used in a commercial
//    product or activity without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ----------------------------------------------------------------------------

module cache (
	input				reset,
	input				clk,					//	System Clock
	//	Bus Interface from Controller (Access unit is 16bits)
	input	[22:1]		cache_address,
	input				cache_write,
	input	[15:0]		cache_wdata,
	input				cache_flush,
	input				cache_valid,
	output				cache_ready,
	output	[15:0]		cache_rdata,
	output				cache_rdata_valid,
	//	Bus Interface to SDRAM (Access unit is 32bits/8words)
	output	[22:5]		sdram_address,
	output				sdram_write,
	output				sdram_refresh,
	output				sdram_valid,
	input				sdram_ready,
	output	[31:0]		sdram_wdata,
	output	[3:0]		sdram_wdata_mask,
	output				sdram_wdata_valid,
	input	[31:0]		sdram_rdata,
	input				sdram_rdata_valid
);
	parameter integer c_clk_hz = 81000000;
	parameter integer c_refresh_interval_cycles = (c_clk_hz / 1000 / 1000) * 64;

	localparam [5:0] c_state_idle						= 6'd0;
	localparam [5:0] c_state_lookup						= 6'd1;
	localparam [5:0] c_state_lookup_decide				= 6'd33;
	localparam [5:0] c_state_read_hit_line_req			= 6'd2;
	localparam [5:0] c_state_read_hit_line_wait			= 6'd3;
	localparam [5:0] c_state_read_hit_line_analyze		= 6'd4;
	localparam [5:0] c_state_write_hit_line_req			= 6'd5;
	localparam [5:0] c_state_write_hit_line_wait		= 6'd6;
	localparam [5:0] c_state_write_hit_line_commit		= 6'd7;
	localparam [5:0] c_state_prepare_tag_commit			= 6'd8;
	localparam [5:0] c_state_tag_commit					= 6'd9;
	localparam [5:0] c_state_finish_req					= 6'd10;
	localparam [5:0] c_state_refill_read_req			= 6'd11;
	localparam [5:0] c_state_refill_read_wait_accept	= 6'd12;
	localparam [5:0] c_state_refill_read_stream			= 6'd13;
	localparam [5:0] c_state_read_resp					= 6'd14;
	localparam [5:0] c_state_alloc_clear_req			= 6'd15;
	localparam [5:0] c_state_alloc_clear_commit			= 6'd16;
	localparam [5:0] c_state_write_miss_line_commit		= 6'd17;
	localparam [5:0] c_state_prescan_req				= 6'd18;
	localparam [5:0] c_state_prescan_wait				= 6'd19;
	localparam [5:0] c_state_prescan_capture			= 6'd20;
	localparam [5:0] c_state_refresh_req				= 6'd21;
	localparam [5:0] c_state_refresh_wait_accept		= 6'd22;
	localparam [5:0] c_state_refresh_wait_done			= 6'd23;
	localparam [5:0] c_state_flush_find_dirty			= 6'd24;
	localparam [5:0] c_state_flush_tag_clear			= 6'd25;
	localparam [5:0] c_state_evict_line_req				= 6'd26;
	localparam [5:0] c_state_evict_line_wait			= 6'd27;
	localparam [5:0] c_state_evict_line_capture			= 6'd28;
	localparam [5:0] c_state_evict_sdram_req			= 6'd29;
	localparam [5:0] c_state_evict_sdram_wait_accept	= 6'd30;
	localparam [5:0] c_state_evict_sdram_stream			= 6'd31;
	localparam [5:0] c_state_evict_sdram_wait_done		= 6'd32;

	localparam [1:0] c_post_evict_write_miss			= 2'd0;
	localparam [1:0] c_post_evict_read_miss				= 2'd1;
	localparam [1:0] c_post_evict_flush					= 2'd2;

	reg		[5:0]	ff_state;
	reg		[31:0]	ff_refresh_counter;
	reg				ff_refresh_pending;

	reg		[22:1]	ff_req_address;
	reg				ff_req_write;
	reg				ff_req_flash;
	reg		[15:0]	ff_req_wdata;

	reg		[17:0]	ff_key;
	reg		[2:0]	ff_word_index;
	reg				ff_half_select;
	reg		[3:0]	ff_selected_way;
	reg		[3:0]	ff_selected_prio;
	reg				ff_refill_partial;

	reg		[17:0]	ff_tag_key [0:7];
	reg		[3:0]	ff_tag_prio [0:7];
	reg				ff_tag_valid [0:7];
	reg				ff_tag_dirty [0:7];
	reg		[7:0]	ff_dirty_map;

	reg		[17:0]	ff_line0_read;
	reg		[17:0]	ff_line1_read;
	reg		[2:0]	ff_burst_count;
	reg		[15:0]	ff_read_result;
	reg				ff_ram_read_wait_phase;

	reg		[2:0]	ff_alloc_clear_index;
	reg		[2:0]	ff_prescan_index;
	reg		[7:0]	ff_prescan_valid0_bits;
	reg		[7:0]	ff_prescan_valid1_bits;
	reg		[17:0]	ff_prescan_line0_word [0:7];
	reg		[17:0]	ff_prescan_line1_word [0:7];

	reg		[3:0]	ff_flush_way;
	reg		[3:0]	ff_flush_scan_index;
	reg		[4:0]	ff_flush_scan_remaining;

	reg		[17:0]	ff_evict_key;
	reg		[2:0]	ff_evict_index;
	reg		[1:0]	ff_evict_post_state;
	reg		[31:0]	ff_evict_line_data;
	reg		[3:0]	ff_evict_line_mask;
	reg		[31:0]	ff_evict_data0;
	reg		[31:0]	ff_evict_data1;
	reg		[31:0]	ff_evict_data2;
	reg		[31:0]	ff_evict_data3;
	reg		[31:0]	ff_evict_data4;
	reg		[31:0]	ff_evict_data5;
	reg		[31:0]	ff_evict_data6;
	reg		[31:0]	ff_evict_data7;
	reg		[3:0]	ff_evict_mask0;
	reg		[3:0]	ff_evict_mask1;
	reg		[3:0]	ff_evict_mask2;
	reg		[3:0]	ff_evict_mask3;
	reg		[3:0]	ff_evict_mask4;
	reg		[3:0]	ff_evict_mask5;
	reg		[3:0]	ff_evict_mask6;
	reg		[3:0]	ff_evict_mask7;

	reg		[15:0]	ff_bus_rdata;
	reg				ff_bus_rdata_valid;

	reg		[22:5]	ff_sdram_address;
	reg				ff_sdram_write;
	reg				ff_sdram_refresh;
	reg				ff_sdram_valid;
	reg		[31:0]	ff_sdram_wdata;
	reg		[3:0]	ff_sdram_wdata_mask;
	reg				ff_sdram_wdata_valid;

	reg				ff_line_oe_n;
	reg				ff_line_we_n;
	reg	[6:0]		ff_line_address;
	reg		[17:0]	ff_line0_wdata;
	reg		[17:0]	ff_line1_wdata;
	wire	[17:0]	w_line0_rdata;
	wire	[17:0]	w_line1_rdata;

	reg				ff_commit_set_valid;
	reg				ff_commit_set_dirty;
	reg				ff_commit_keep_dirty;
	reg				ff_lookup_any_hit;
	reg		[3:0]	ff_lookup_hit_way;
	reg		[3:0]	ff_lookup_repl_way;
	reg				ff_lookup_repl_need_evict;

	reg				w_any_hit;
	reg		[3:0]	w_hit_way;
	wire	[3:0]	w_repl_way;
	wire			w_repl_need_evict;
	integer			i;

	wire	[17:0]	w_lookup_key = ff_key;

	function [6:0] fn_line_addr;
		input [3:0] way;
		input [2:0] word_index;
		begin
			fn_line_addr = { way, word_index };
		end
	endfunction

	function [31:0] fn_get_evict_data;
		input [2:0] idx;
		begin
			case( idx )
			3'd0: fn_get_evict_data = ff_evict_data0;
			3'd1: fn_get_evict_data = ff_evict_data1;
			3'd2: fn_get_evict_data = ff_evict_data2;
			3'd3: fn_get_evict_data = ff_evict_data3;
			3'd4: fn_get_evict_data = ff_evict_data4;
			3'd5: fn_get_evict_data = ff_evict_data5;
			3'd6: fn_get_evict_data = ff_evict_data6;
			default: fn_get_evict_data = ff_evict_data7;
			endcase
		end
	endfunction

	function [3:0] fn_get_evict_mask;
		input [2:0] idx;
		begin
			case( idx )
			3'd0: fn_get_evict_mask = ff_evict_mask0;
			3'd1: fn_get_evict_mask = ff_evict_mask1;
			3'd2: fn_get_evict_mask = ff_evict_mask2;
			3'd3: fn_get_evict_mask = ff_evict_mask3;
			3'd4: fn_get_evict_mask = ff_evict_mask4;
			3'd5: fn_get_evict_mask = ff_evict_mask5;
			3'd6: fn_get_evict_mask = ff_evict_mask6;
			default: fn_get_evict_mask = ff_evict_mask7;
			endcase
		end
	endfunction

	function [3:0] fn_make_dqm;
		input line0_valid;
		input line0_update;
		input line1_valid;
		input line1_update;
		begin
			fn_make_dqm = {
				(line1_valid && line1_update) ? 2'b00 : 2'b11,
				(line0_valid && line0_update) ? 2'b00 : 2'b11
			};
		end
	endfunction

	//	置換候補 {valid, prio[3:0], way[3:0]}。invalid way を最優先し、
	//	同格は左(小さいway番号)優先で元の直列scanと同じ選択結果になる。
	function [8:0] fn_pick_repl;
		input [8:0] a;
		input [8:0] b;
		begin
			if( (!b[8] && a[8]) || ((b[8] == a[8]) && (b[7:4] < a[7:4])) ) begin
				fn_pick_repl = b;
			end
			else begin
				fn_pick_repl = a;
			end
		end
	endfunction

	wire	[8:0]	w_repl_cand0 = { ff_tag_valid[0], (ff_tag_valid[0] ? ff_tag_prio[0] : 4'd0), 4'd0 };
	wire	[8:0]	w_repl_cand1 = { ff_tag_valid[1], (ff_tag_valid[1] ? ff_tag_prio[1] : 4'd0), 4'd1 };
	wire	[8:0]	w_repl_cand2 = { ff_tag_valid[2], (ff_tag_valid[2] ? ff_tag_prio[2] : 4'd0), 4'd2 };
	wire	[8:0]	w_repl_cand3 = { ff_tag_valid[3], (ff_tag_valid[3] ? ff_tag_prio[3] : 4'd0), 4'd3 };
	wire	[8:0]	w_repl_cand4 = { ff_tag_valid[4], (ff_tag_valid[4] ? ff_tag_prio[4] : 4'd0), 4'd4 };
	wire	[8:0]	w_repl_cand5 = { ff_tag_valid[5], (ff_tag_valid[5] ? ff_tag_prio[5] : 4'd0), 4'd5 };
	wire	[8:0]	w_repl_cand6 = { ff_tag_valid[6], (ff_tag_valid[6] ? ff_tag_prio[6] : 4'd0), 4'd6 };
	wire	[8:0]	w_repl_cand7 = { ff_tag_valid[7], (ff_tag_valid[7] ? ff_tag_prio[7] : 4'd0), 4'd7 };

	wire	[8:0]	w_repl_n01 = fn_pick_repl( w_repl_cand0, w_repl_cand1 );
	wire	[8:0]	w_repl_n23 = fn_pick_repl( w_repl_cand2, w_repl_cand3 );
	wire	[8:0]	w_repl_n45 = fn_pick_repl( w_repl_cand4, w_repl_cand5 );
	wire	[8:0]	w_repl_n67 = fn_pick_repl( w_repl_cand6, w_repl_cand7 );
	wire	[8:0]	w_repl_n03 = fn_pick_repl( w_repl_n01, w_repl_n23 );
	wire	[8:0]	w_repl_n47 = fn_pick_repl( w_repl_n45, w_repl_n67 );
	wire	[8:0]	w_repl_sel = fn_pick_repl( w_repl_n03, w_repl_n47 );

	assign	w_repl_way			= w_repl_sel[3:0];
	assign	w_repl_need_evict	= w_repl_sel[8] && ff_tag_dirty[w_repl_sel[3:0]];

	always @* begin
		w_any_hit = 1'b0;
		w_hit_way = 4'd0;
		for( i = 0; i < 8; i = i + 1 ) begin
			if( !w_any_hit && ff_tag_valid[i] && (ff_tag_key[i] == w_lookup_key) ) begin
				w_any_hit = 1'b1;
				w_hit_way = i;
			end
		end
	end

	cache_line u_cache_line0 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_line_oe_n		),
		.we_n			( ff_line_we_n		),
		.address	( ff_line_address	),
		.wdata			( ff_line0_wdata	),
		.rdata			( w_line0_rdata		)
	);

	cache_line u_cache_line1 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_line_oe_n		),
		.we_n			( ff_line_we_n		),
		.address	( ff_line_address	),
		.wdata			( ff_line1_wdata	),
		.rdata			( w_line1_rdata		)
	);

	always @( posedge clk ) begin
		if( reset ) begin
			ff_state <= c_state_idle;
			ff_refresh_counter <= 32'd0;
			ff_refresh_pending <= 1'b0;
			ff_req_address <= 22'd0;
			ff_req_write <= 1'b0;
			ff_req_flash <= 1'b0;
			ff_req_wdata <= 16'd0;
			ff_key <= 18'd0;
			ff_word_index <= 3'd0;
			ff_half_select <= 1'b0;
			ff_selected_way <= 4'd0;
			ff_selected_prio <= 4'd0;
			ff_refill_partial <= 1'b0;
			ff_line0_read <= 18'd0;
			ff_line1_read <= 18'd0;
			ff_burst_count <= 3'd0;
			ff_read_result <= 16'd0;
			ff_ram_read_wait_phase <= 1'b0;
			ff_alloc_clear_index <= 3'd0;
			ff_prescan_index <= 3'd0;
			ff_prescan_valid0_bits <= 8'd0;
			ff_prescan_valid1_bits <= 8'd0;
			ff_flush_way <= 4'd0;
			ff_flush_scan_index <= 4'd0;
			ff_flush_scan_remaining <= 5'd0;
			ff_evict_key <= 18'd0;
			ff_evict_index <= 3'd0;
			ff_evict_post_state <= c_post_evict_write_miss;
			ff_evict_line_data <= 32'd0;
			ff_evict_line_mask <= 4'd0;
			ff_bus_rdata <= 16'd0;
			ff_bus_rdata_valid <= 1'b0;
			ff_sdram_address <= 18'd0;
			ff_sdram_write <= 1'b0;
			ff_sdram_refresh <= 1'b0;
			ff_sdram_valid <= 1'b0;
			ff_sdram_wdata <= 32'd0;
			ff_sdram_wdata_mask <= 4'hF;
			ff_sdram_wdata_valid <= 1'b0;
			ff_line_oe_n <= 1'b1;
			ff_line_we_n <= 1'b1;
			ff_line_address <= 7'd0;
			ff_line0_wdata <= 18'd0;
			ff_line1_wdata <= 18'd0;
			ff_commit_set_valid <= 1'b0;
			ff_commit_set_dirty <= 1'b0;
			ff_commit_keep_dirty <= 1'b0;
			ff_lookup_any_hit <= 1'b0;
			ff_lookup_hit_way <= 4'd0;
			ff_lookup_repl_way <= 4'd0;
			ff_lookup_repl_need_evict <= 1'b0;
			ff_dirty_map <= 8'd0;
			ff_evict_data0 <= 32'd0;
			ff_evict_data1 <= 32'd0;
			ff_evict_data2 <= 32'd0;
			ff_evict_data3 <= 32'd0;
			ff_evict_data4 <= 32'd0;
			ff_evict_data5 <= 32'd0;
			ff_evict_data6 <= 32'd0;
			ff_evict_data7 <= 32'd0;
			ff_evict_mask0 <= 4'd0;
			ff_evict_mask1 <= 4'd0;
			ff_evict_mask2 <= 4'd0;
			ff_evict_mask3 <= 4'd0;
			ff_evict_mask4 <= 4'd0;
			ff_evict_mask5 <= 4'd0;
			ff_evict_mask6 <= 4'd0;
			ff_evict_mask7 <= 4'd0;
			for( i = 0; i < 8; i = i + 1 ) begin
				ff_tag_key[i] <= 18'd0;
				ff_tag_prio[i] <= 4'd0;
				ff_tag_valid[i] <= 1'b0;
				ff_tag_dirty[i] <= 1'b0;
			end
		end
		else begin
			ff_bus_rdata_valid <= 1'b0;
			ff_line_oe_n <= 1'b1;
			ff_line_we_n <= 1'b1;
			ff_sdram_valid <= 1'b0;
			ff_sdram_wdata_valid <= 1'b0;
			ff_sdram_refresh <= 1'b0;

			if( ff_refresh_counter >= c_refresh_interval_cycles - 1 ) begin
				ff_refresh_counter <= 32'd0;
				ff_refresh_pending <= 1'b1;
			end
			else begin
				ff_refresh_counter <= ff_refresh_counter + 32'd1;
			end

			case( ff_state )
			c_state_idle: begin
				if( ff_refresh_pending ) begin
					ff_state <= c_state_refresh_req;
				end
				else if( cache_valid ) begin
					ff_req_address <= cache_address;
					ff_req_write <= cache_write;
					ff_req_flash <= cache_flush;
					ff_req_wdata <= cache_wdata;
					ff_key <= cache_address[22:5];
					ff_word_index <= cache_address[4:2];
					ff_half_select <= cache_address[1];
					if( cache_flush ) begin
						ff_flush_scan_index <= 4'd0;
						ff_flush_scan_remaining <= 5'd8;
						ff_state <= c_state_flush_find_dirty;
					end
					else begin
						ff_state <= c_state_lookup;
					end
				end
			end

			c_state_lookup: begin
				ff_lookup_any_hit <= w_any_hit;
				ff_lookup_hit_way <= w_hit_way;
				ff_lookup_repl_way <= w_repl_way;
				ff_lookup_repl_need_evict <= w_repl_need_evict;
				ff_state <= c_state_lookup_decide;
			end

			c_state_lookup_decide: begin
				if( ff_req_write ) begin
					if( ff_lookup_any_hit ) begin
						ff_selected_way <= ff_lookup_hit_way;
						ff_selected_prio <= ff_tag_prio[ff_lookup_hit_way];
						ff_state <= c_state_write_hit_line_req;
					end
					else begin
						ff_selected_way <= ff_lookup_repl_way;
						ff_selected_prio <= ff_tag_prio[ff_lookup_repl_way];
						if( ff_lookup_repl_need_evict ) begin
							ff_evict_key <= ff_tag_key[ff_lookup_repl_way];
							ff_evict_index <= 3'd0;
							ff_evict_post_state <= c_post_evict_write_miss;
							ff_state <= c_state_evict_line_req;
						end
						else begin
							ff_alloc_clear_index <= 3'd0;
							ff_state <= c_state_alloc_clear_req;
						end
					end
				end
				else begin
					if( ff_lookup_any_hit ) begin
						ff_selected_way <= ff_lookup_hit_way;
						ff_selected_prio <= ff_tag_prio[ff_lookup_hit_way];
						ff_state <= c_state_read_hit_line_req;
					end
					else begin
						ff_selected_way <= ff_lookup_repl_way;
						ff_selected_prio <= ff_tag_prio[ff_lookup_repl_way];
						if( ff_lookup_repl_need_evict ) begin
							ff_evict_key <= ff_tag_key[ff_lookup_repl_way];
							ff_evict_index <= 3'd0;
							ff_evict_post_state <= c_post_evict_read_miss;
							ff_state <= c_state_evict_line_req;
						end
						else begin
							ff_refill_partial <= 1'b0;
							ff_state <= c_state_refill_read_req;
						end
					end
				end
			end

			c_state_read_hit_line_req: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_word_index );
				ff_line_oe_n <= 1'b0;
				ff_ram_read_wait_phase <= 1'b0;
				ff_state <= c_state_read_hit_line_wait;
			end

			c_state_read_hit_line_wait: begin
				if( !ff_ram_read_wait_phase ) begin
					ff_line_oe_n <= 1'b0;
					ff_ram_read_wait_phase <= 1'b1;
				end
				else begin
					ff_line0_read <= w_line0_rdata;
					ff_line1_read <= w_line1_rdata;
					ff_ram_read_wait_phase <= 1'b0;
					ff_state <= c_state_read_hit_line_analyze;
				end
			end

			c_state_read_hit_line_analyze: begin
				if( ff_half_select ? ff_line1_read[17] : ff_line0_read[17] ) begin
					if( ff_half_select )
						ff_read_result <= ff_line1_read[15:0];
					else
						ff_read_result <= ff_line0_read[15:0];
					ff_commit_set_valid <= 1'b1;
					ff_commit_set_dirty <= 1'b0;
					ff_commit_keep_dirty <= 1'b1;
					ff_state <= c_state_prepare_tag_commit;
				end
				else begin
					ff_prescan_index <= 3'd0;
					ff_prescan_valid0_bits <= 8'd0;
					ff_prescan_valid1_bits <= 8'd0;
					ff_refill_partial <= 1'b1;
					ff_state <= c_state_prescan_req;
				end
			end

			c_state_write_hit_line_req: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_word_index );
				ff_line_oe_n <= 1'b0;
				ff_ram_read_wait_phase <= 1'b0;
				ff_state <= c_state_write_hit_line_wait;
			end

			c_state_write_hit_line_wait: begin
				if( !ff_ram_read_wait_phase ) begin
					ff_line_oe_n <= 1'b0;
					ff_ram_read_wait_phase <= 1'b1;
				end
				else begin
					ff_line0_read <= w_line0_rdata;
					ff_line1_read <= w_line1_rdata;
					ff_ram_read_wait_phase <= 1'b0;
					ff_state <= c_state_write_hit_line_commit;
				end
			end

			c_state_write_hit_line_commit: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_word_index );
				if( ff_half_select ) begin
					ff_line0_wdata <= ff_line0_read;
					ff_line1_wdata <= { 1'b1, 1'b1, ff_req_wdata };
				end
				else begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_req_wdata };
					ff_line1_wdata <= ff_line1_read;
				end
				ff_line_we_n <= 1'b0;
				ff_commit_set_valid <= 1'b1;
				ff_commit_set_dirty <= 1'b1;
				ff_commit_keep_dirty <= 1'b0;
				ff_state <= c_state_tag_commit;
			end

			c_state_alloc_clear_req: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_alloc_clear_index );
				ff_line0_wdata <= 18'd0;
				ff_line1_wdata <= 18'd0;
				ff_line_we_n <= 1'b0;
				ff_state <= c_state_alloc_clear_commit;
			end

			c_state_alloc_clear_commit: begin
				if( ff_alloc_clear_index == 3'd7 ) begin
					ff_state <= c_state_write_miss_line_commit;
				end
				else begin
					ff_alloc_clear_index <= ff_alloc_clear_index + 3'd1;
					ff_state <= c_state_alloc_clear_req;
				end
			end

			c_state_write_miss_line_commit: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_word_index );
				if( ff_half_select ) begin
					ff_line0_wdata <= 18'd0;
					ff_line1_wdata <= { 1'b1, 1'b1, ff_req_wdata };
				end
				else begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_req_wdata };
					ff_line1_wdata <= 18'd0;
				end
				ff_line_we_n <= 1'b0;
				ff_commit_set_valid <= 1'b1;
				ff_commit_set_dirty <= 1'b1;
				ff_commit_keep_dirty <= 1'b0;
				ff_state <= c_state_prepare_tag_commit;
			end

			c_state_prepare_tag_commit: begin
				ff_state <= c_state_tag_commit;
			end

			c_state_tag_commit: begin
				for( i = 0; i < 8; i = i + 1 ) begin
					if( i == ff_selected_way ) begin
						ff_tag_key[i] <= ff_key;
						ff_tag_valid[i] <= ff_commit_set_valid;
						ff_tag_dirty[i] <= ff_commit_keep_dirty ? ff_tag_dirty[i] : ff_commit_set_dirty;
						ff_tag_prio[i] <= 4'd7;
					end
					else if( ff_tag_valid[i] && (ff_tag_prio[i] > ff_selected_prio) ) begin
						ff_tag_prio[i] <= ff_tag_prio[i] - 4'd1;
					end
				end
				ff_dirty_map[ff_selected_way] <= ff_commit_keep_dirty ? ff_tag_dirty[ff_selected_way] : ff_commit_set_dirty;
				if( ff_req_write )
					ff_state <= c_state_finish_req;
				else
					ff_state <= c_state_read_resp;
			end

			c_state_read_resp: begin
				ff_bus_rdata <= ff_read_result;
				ff_bus_rdata_valid <= 1'b1;
				ff_state <= c_state_finish_req;
			end

			c_state_finish_req: begin
				ff_state <= c_state_idle;
			end

			c_state_prescan_req: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_prescan_index );
				ff_line_oe_n <= 1'b0;
				ff_ram_read_wait_phase <= 1'b0;
				ff_state <= c_state_prescan_wait;
			end

			c_state_prescan_wait: begin
				if( !ff_ram_read_wait_phase ) begin
					ff_line_oe_n <= 1'b0;
					ff_ram_read_wait_phase <= 1'b1;
				end
				else begin
					ff_line0_read <= w_line0_rdata;
					ff_line1_read <= w_line1_rdata;
					ff_ram_read_wait_phase <= 1'b0;
					ff_state <= c_state_prescan_capture;
				end
			end

			c_state_prescan_capture: begin
				ff_prescan_valid0_bits[ff_prescan_index] <= ff_line0_read[17];
				ff_prescan_valid1_bits[ff_prescan_index] <= ff_line1_read[17];
				ff_prescan_line0_word[ff_prescan_index] <= ff_line0_read;
				ff_prescan_line1_word[ff_prescan_index] <= ff_line1_read;
				if( ff_prescan_index == 3'd7 ) begin
					ff_state <= c_state_refill_read_req;
				end
				else begin
					ff_prescan_index <= ff_prescan_index + 3'd1;
					ff_state <= c_state_prescan_req;
				end
			end

			c_state_refill_read_req: begin
				ff_sdram_address <= ff_key;
				ff_sdram_write <= 1'b0;
				ff_sdram_valid <= 1'b1;
				ff_burst_count <= 3'd0;
				ff_state <= c_state_refill_read_wait_accept;
			end

			c_state_refill_read_wait_accept: begin
				ff_sdram_address <= ff_key;
				ff_sdram_write <= 1'b0;
				if( sdram_ready ) begin
					ff_sdram_valid <= 1'b0;
					ff_state <= c_state_refill_read_stream;
				end
				else begin
					ff_sdram_valid <= 1'b1;
				end
			end

			c_state_refill_read_stream: begin
				if( sdram_rdata_valid ) begin
					if( !ff_refill_partial || !ff_prescan_valid0_bits[ff_burst_count] || !ff_prescan_valid1_bits[ff_burst_count] ) begin
						ff_line_address <= fn_line_addr( ff_selected_way, ff_burst_count );
						ff_line0_wdata <= (!ff_refill_partial || !ff_prescan_valid0_bits[ff_burst_count]) ? { 1'b1, 1'b0, sdram_rdata[15:0] } : ff_prescan_line0_word[ff_burst_count];
						ff_line1_wdata <= (!ff_refill_partial || !ff_prescan_valid1_bits[ff_burst_count]) ? { 1'b1, 1'b0, sdram_rdata[31:16] } : ff_prescan_line1_word[ff_burst_count];
						ff_line_we_n <= 1'b0;
					end
					if( ff_burst_count == ff_word_index ) begin
						if( ff_half_select )
							ff_read_result <= sdram_rdata[31:16];
						else
							ff_read_result <= sdram_rdata[15:0];
					end
					if( ff_burst_count == 3'd7 ) begin
						ff_commit_set_valid <= 1'b1;
						ff_commit_set_dirty <= 1'b0;
						ff_commit_keep_dirty <= ff_refill_partial;
						ff_state <= c_state_prepare_tag_commit;
					end
					else begin
						ff_burst_count <= ff_burst_count + 3'd1;
					end
				end
			end

			c_state_refresh_req: begin
				ff_sdram_write <= 1'b0;
				ff_sdram_refresh <= 1'b1;
				ff_sdram_address <= 18'd0;
				ff_sdram_valid <= 1'b1;
				ff_state <= c_state_refresh_wait_accept;
			end

			c_state_refresh_wait_accept: begin
				ff_sdram_write <= 1'b0;
				ff_sdram_refresh <= 1'b1;
				ff_sdram_address <= 18'd0;
				if( sdram_ready ) begin
					ff_sdram_valid <= 1'b0;
					ff_refresh_pending <= 1'b0;
					ff_state <= c_state_refresh_wait_done;
				end
				else begin
					ff_sdram_valid <= 1'b1;
				end
			end

			c_state_refresh_wait_done: begin
				ff_state <= c_state_idle;
			end

			c_state_flush_find_dirty: begin
				if( ff_flush_scan_remaining == 5'd0 ) begin
					ff_state <= c_state_finish_req;
				end
				else if( ff_tag_valid[ff_flush_scan_index] ) begin
					ff_flush_way <= ff_flush_scan_index;
					if( ff_tag_valid[ff_flush_scan_index] && ff_tag_dirty[ff_flush_scan_index] ) begin
						ff_selected_way <= ff_flush_scan_index;
						ff_selected_prio <= ff_tag_prio[ff_flush_scan_index];
						ff_evict_key <= ff_tag_key[ff_flush_scan_index];
						ff_evict_index <= 3'd0;
						ff_evict_post_state <= c_post_evict_flush;
						ff_state <= c_state_evict_line_req;
					end
					else begin
						ff_state <= c_state_flush_tag_clear;
					end
				end
				else begin
					ff_flush_scan_index <= ff_flush_scan_index + 4'd1;
					ff_flush_scan_remaining <= ff_flush_scan_remaining - 5'd1;
				end
			end

			c_state_flush_tag_clear: begin
				ff_tag_key[ff_flush_way] <= 18'd0;
				ff_tag_prio[ff_flush_way] <= 4'd0;
				ff_tag_valid[ff_flush_way] <= 1'b0;
				ff_tag_dirty[ff_flush_way] <= 1'b0;
				ff_dirty_map[ff_flush_way] <= 1'b0;
				ff_flush_scan_index <= ff_flush_scan_index + 4'd1;
				ff_flush_scan_remaining <= ff_flush_scan_remaining - 5'd1;
				ff_state <= c_state_flush_find_dirty;
			end

			c_state_evict_line_req: begin
				ff_line_address <= fn_line_addr( ff_selected_way, ff_evict_index );
				ff_line_oe_n <= 1'b0;
				ff_ram_read_wait_phase <= 1'b0;
				ff_state <= c_state_evict_line_wait;
			end

			c_state_evict_line_wait: begin
				if( !ff_ram_read_wait_phase ) begin
					ff_line_oe_n <= 1'b0;
					ff_ram_read_wait_phase <= 1'b1;
				end
				else begin
					ff_evict_line_data <= { w_line1_rdata[15:0], w_line0_rdata[15:0] };
					ff_evict_line_mask <= fn_make_dqm( w_line0_rdata[17], w_line0_rdata[16], w_line1_rdata[17], w_line1_rdata[16] );
					ff_ram_read_wait_phase <= 1'b0;
					ff_state <= c_state_evict_line_capture;
				end
			end

			c_state_evict_line_capture: begin
				case( ff_evict_index )
				3'd0: begin ff_evict_data0 <= ff_evict_line_data; ff_evict_mask0 <= ff_evict_line_mask; end
				3'd1: begin ff_evict_data1 <= ff_evict_line_data; ff_evict_mask1 <= ff_evict_line_mask; end
				3'd2: begin ff_evict_data2 <= ff_evict_line_data; ff_evict_mask2 <= ff_evict_line_mask; end
				3'd3: begin ff_evict_data3 <= ff_evict_line_data; ff_evict_mask3 <= ff_evict_line_mask; end
				3'd4: begin ff_evict_data4 <= ff_evict_line_data; ff_evict_mask4 <= ff_evict_line_mask; end
				3'd5: begin ff_evict_data5 <= ff_evict_line_data; ff_evict_mask5 <= ff_evict_line_mask; end
				3'd6: begin ff_evict_data6 <= ff_evict_line_data; ff_evict_mask6 <= ff_evict_line_mask; end
				default: begin ff_evict_data7 <= ff_evict_line_data; ff_evict_mask7 <= ff_evict_line_mask; end
				endcase
				if( ff_evict_index == 3'd7 ) begin
					ff_evict_index <= 3'd0;
					ff_state <= c_state_evict_sdram_req;
				end
				else begin
					ff_evict_index <= ff_evict_index + 3'd1;
					ff_state <= c_state_evict_line_req;
				end
			end

			c_state_evict_sdram_req: begin
				ff_sdram_address <= ff_evict_key;
				ff_sdram_write <= 1'b1;
				ff_sdram_valid <= 1'b1;
				ff_state <= c_state_evict_sdram_wait_accept;
			end

			c_state_evict_sdram_wait_accept: begin
				ff_sdram_address <= ff_evict_key;
				ff_sdram_write <= 1'b1;
				if( sdram_ready ) begin
					ff_sdram_valid <= 1'b0;
					ff_evict_index <= 3'd0;
					ff_state <= c_state_evict_sdram_stream;
				end
				else begin
					ff_sdram_valid <= 1'b1;
				end
			end

			c_state_evict_sdram_stream: begin
				ff_sdram_wdata <= fn_get_evict_data( ff_evict_index );
				ff_sdram_wdata_mask <= fn_get_evict_mask( ff_evict_index );
				ff_sdram_wdata_valid <= 1'b1;
				if( ff_evict_index == 3'd7 ) begin
					ff_state <= c_state_evict_sdram_wait_done;
				end
				else begin
					ff_evict_index <= ff_evict_index + 3'd1;
				end
			end

			c_state_evict_sdram_wait_done: begin
				if( ff_evict_post_state == c_post_evict_write_miss ) begin
					ff_alloc_clear_index <= 3'd0;
					ff_state <= c_state_alloc_clear_req;
				end
				else if( ff_evict_post_state == c_post_evict_read_miss ) begin
					ff_refill_partial <= 1'b0;
					ff_state <= c_state_refill_read_req;
				end
				else begin
					ff_state <= c_state_flush_tag_clear;
				end
			end

			default: begin
				ff_state <= c_state_idle;
			end
			endcase
		end
	end

	assign cache_ready = (ff_state == c_state_idle) && !ff_refresh_pending;
	assign cache_rdata = ff_bus_rdata;
	assign cache_rdata_valid = ff_bus_rdata_valid;

	assign sdram_address = ff_sdram_address;
	assign sdram_write = ff_sdram_write;
	assign sdram_refresh = ff_sdram_refresh;
	assign sdram_valid = ff_sdram_valid;
	assign sdram_wdata = ff_sdram_wdata;
	assign sdram_wdata_mask = ff_sdram_wdata_mask;
	assign sdram_wdata_valid = ff_sdram_wdata_valid;
endmodule
