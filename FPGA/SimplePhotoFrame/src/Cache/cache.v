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
	input	[22:1]		bus_address,
	input				bus_write,
	input	[15:0]		bus_wdata,
	input				bus_flash,
	input				bus_valid,
	output				bus_ready,
	output	[15:0]		bus_rdata,
	output				bus_rdata_valid,
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
	parameter integer c_clk_hz = 108000000;
	parameter integer c_refresh_interval_cycles = (c_clk_hz / 1000) * 32;

	localparam [5:0] c_state_init_tag_clear_req			= 6'd0;
	localparam [5:0] c_state_init_tag_clear_commit		= 6'd1;
	localparam [5:0] c_state_idle						= 6'd2;
	localparam [5:0] c_state_tag_read_req				= 6'd3;
	localparam [5:0] c_state_tag_read_wait				= 6'd4;
	localparam [5:0] c_state_tag_read_analyze			= 6'd38;
	localparam [5:0] c_state_read_hit_line_req			= 6'd5;
	localparam [5:0] c_state_read_hit_line_wait			= 6'd6;
	localparam [5:0] c_state_read_hit_line_analyze		= 6'd40;
	localparam [5:0] c_state_write_hit_line_req			= 6'd7;
	localparam [5:0] c_state_write_hit_line_wait		= 6'd8;
	localparam [5:0] c_state_write_hit_line_commit		= 6'd9;
	localparam [5:0] c_state_prepare_tag_commit			= 6'd10;
	localparam [5:0] c_state_tag_commit					= 6'd11;
	localparam [5:0] c_state_finish_req					= 6'd12;
	localparam [5:0] c_state_refill_read_req			= 6'd13;
	localparam [5:0] c_state_refill_read_wait_accept	= 6'd14;
	localparam [5:0] c_state_refill_read_stream			= 6'd15;
	localparam [5:0] c_state_refill_line_commit			= 6'd16;
	localparam [5:0] c_state_read_resp					= 6'd17;
	localparam [5:0] c_state_alloc_clear_req			= 6'd18;
	localparam [5:0] c_state_alloc_clear_commit			= 6'd19;
	localparam [5:0] c_state_write_miss_line_req		= 6'd20;
	localparam [5:0] c_state_write_miss_line_wait		= 6'd21;
	localparam [5:0] c_state_write_miss_line_commit		= 6'd22;
	localparam [5:0] c_state_prescan_req				= 6'd23;
	localparam [5:0] c_state_prescan_wait				= 6'd24;
	localparam [5:0] c_state_prescan_capture			= 6'd41;
	localparam [5:0] c_state_refresh_req				= 6'd25;
	localparam [5:0] c_state_refresh_wait_accept		= 6'd26;
	localparam [5:0] c_state_refresh_wait_done			= 6'd27;
	localparam [5:0] c_state_flush_tag_req				= 6'd28;
	localparam [5:0] c_state_flush_tag_wait				= 6'd29;
	localparam [5:0] c_state_flush_tag_analyze			= 6'd39;
	localparam [5:0] c_state_flush_tag_clear			= 6'd30;
	localparam [5:0] c_state_flush_next					= 6'd31;
	localparam [5:0] c_state_evict_line_req				= 6'd32;
	localparam [5:0] c_state_evict_line_wait			= 6'd33;
	localparam [5:0] c_state_evict_line_capture			= 6'd42;
	localparam [5:0] c_state_evict_sdram_req			= 6'd34;
	localparam [5:0] c_state_evict_sdram_wait_accept	= 6'd35;
	localparam [5:0] c_state_evict_sdram_stream			= 6'd36;
	localparam [5:0] c_state_evict_sdram_wait_done		= 6'd37;

	localparam [2:0] c_post_evict_write_miss			= 3'd0;
	localparam [2:0] c_post_evict_read_miss				= 3'd1;
	localparam [2:0] c_post_evict_flush					= 3'd2;

	reg		[5:0]	ff_state;

	reg		[31:0]	ff_refresh_counter;
	reg				ff_refresh_pending;
	reg				ff_refresh_seen_busy;

	reg		[22:1]	ff_req_address;
	reg				ff_req_write;
	reg				ff_req_flash;
	reg		[15:0]	ff_req_wdata;

	reg		[6:0]	ff_hash;
	reg		[10:0]	ff_key;
	reg		[2:0]	ff_word_index;
	reg				ff_half_select;
	reg		[1:0]	ff_selected_way;

	reg		[15:0]	ff_tag0;
	reg		[15:0]	ff_tag1;
	reg		[15:0]	ff_tag2;
	reg		[15:0]	ff_tag3;

	reg		[15:0]	ff_tag_new0;
	reg		[15:0]	ff_tag_new1;
	reg		[15:0]	ff_tag_new2;
	reg		[15:0]	ff_tag_new3;

	reg				ff_hit;
	reg		[1:0]	ff_hit_way;
	reg				ff_need_refill;
	reg				ff_refill_partial;
	reg				ff_need_alloc_clear;
	reg				ff_need_evict;

	reg		[7:0]	ff_prescan_valid_bits;

	reg		[17:0]	ff_line0_read;
	reg		[17:0]	ff_line1_read;
	reg		[17:0]	ff_line0_write;
	reg		[17:0]	ff_line1_write;

	reg		[2:0]	ff_burst_count;
	reg		[15:0]	ff_read_result;
	reg		[31:0]	ff_burst_rdata_latched;

	reg		[2:0]	ff_alloc_clear_index;
	reg		[2:0]	ff_prescan_index;
	reg				ff_prescan_line_valid;

	reg		[6:0]	ff_init_hash;

	reg		[6:0]	ff_flush_hash;
	reg		[1:0]	ff_flush_way;

	reg		[6:0]	ff_evict_hash;
	reg		[10:0]	ff_evict_key;
	reg		[2:0]	ff_evict_index;
	reg		[2:0]	ff_evict_post_state;
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
	reg		[11:0]	ff_line_address;
	reg		[17:0]	ff_line0_wdata;
	reg		[17:0]	ff_line1_wdata;
	wire	[17:0]	w_line0_rdata;
	wire	[17:0]	w_line1_rdata;

	reg				ff_tag0_oe_n;
	reg				ff_tag1_oe_n;
	reg				ff_tag2_oe_n;
	reg				ff_tag3_oe_n;
	reg				ff_tag0_we_n;
	reg				ff_tag1_we_n;
	reg				ff_tag2_we_n;
	reg				ff_tag3_we_n;
	reg		[11:0]	ff_tag_address;
	reg		[15:0]	ff_tag0_wdata;
	reg		[15:0]	ff_tag1_wdata;
	reg		[15:0]	ff_tag2_wdata;
	reg		[15:0]	ff_tag3_wdata;
	wire	[15:0]	w_tag0_rdata;
	wire	[15:0]	w_tag1_rdata;
	wire	[15:0]	w_tag2_rdata;
	wire	[15:0]	w_tag3_rdata;

	wire				w_hit0 = ff_tag0[14] && (ff_tag0[10:0] == ff_key);
	wire				w_hit1 = ff_tag1[14] && (ff_tag1[10:0] == ff_key);
	wire				w_hit2 = ff_tag2[14] && (ff_tag2[10:0] == ff_key);
	wire				w_hit3 = ff_tag3[14] && (ff_tag3[10:0] == ff_key);
	wire				w_any_hit = w_hit0 || w_hit1 || w_hit2 || w_hit3;
	wire	[1:0]		w_hit_way = w_hit0 ? 2'd0 : (w_hit1 ? 2'd1 : (w_hit2 ? 2'd2 : 2'd3));

	wire	[1:0]		w_repl_way = fn_choose_way(ff_tag0, ff_tag1, ff_tag2, ff_tag3);
	wire				w_repl_need_evict =
		(w_repl_way == 2'd0) ? (ff_tag0[14] && ff_tag0[13]) :
		(w_repl_way == 2'd1) ? (ff_tag1[14] && ff_tag1[13]) :
		(w_repl_way == 2'd2) ? (ff_tag2[14] && ff_tag2[13]) :
								(ff_tag3[14] && ff_tag3[13]);
	wire	[10:0]		w_repl_key =
		(w_repl_way == 2'd0) ? ff_tag0[10:0] :
		(w_repl_way == 2'd1) ? ff_tag1[10:0] :
		(w_repl_way == 2'd2) ? ff_tag2[10:0] :
								ff_tag3[10:0];

	wire				w_flush_need_evict =
		(ff_flush_way == 2'd0) ? (ff_tag0[14] && ff_tag0[13]) :
		(ff_flush_way == 2'd1) ? (ff_tag1[14] && ff_tag1[13]) :
		(ff_flush_way == 2'd2) ? (ff_tag2[14] && ff_tag2[13]) :
								 (ff_tag3[14] && ff_tag3[13]);
	wire	[10:0]		w_flush_evict_key =
		(ff_flush_way == 2'd0) ? ff_tag0[10:0] :
		(ff_flush_way == 2'd1) ? ff_tag1[10:0] :
		(ff_flush_way == 2'd2) ? ff_tag2[10:0] :
								ff_tag3[10:0];

	wire	[15:0]		w_tag_new_write0 = fn_update_tag(ff_tag0, ff_key, ff_selected_way, 2'd0, 1'b1, 1'b1, 1'b0);
	wire	[15:0]		w_tag_new_write1 = fn_update_tag(ff_tag1, ff_key, ff_selected_way, 2'd1, 1'b1, 1'b1, 1'b0);
	wire	[15:0]		w_tag_new_write2 = fn_update_tag(ff_tag2, ff_key, ff_selected_way, 2'd2, 1'b1, 1'b1, 1'b0);
	wire	[15:0]		w_tag_new_write3 = fn_update_tag(ff_tag3, ff_key, ff_selected_way, 2'd3, 1'b1, 1'b1, 1'b0);

	wire	[15:0]		w_tag_new_read0 = fn_update_tag(ff_tag0, ff_key, ff_selected_way, 2'd0, 1'b0, 1'b0, 1'b1);
	wire	[15:0]		w_tag_new_read1 = fn_update_tag(ff_tag1, ff_key, ff_selected_way, 2'd1, 1'b0, 1'b0, 1'b1);
	wire	[15:0]		w_tag_new_read2 = fn_update_tag(ff_tag2, ff_key, ff_selected_way, 2'd2, 1'b0, 1'b0, 1'b1);
	wire	[15:0]		w_tag_new_read3 = fn_update_tag(ff_tag3, ff_key, ff_selected_way, 2'd3, 1'b0, 1'b0, 1'b1);

	wire	[15:0]		w_tag_new_refill0 = fn_update_tag(ff_tag0, ff_key, ff_selected_way, 2'd0, 1'b1, 1'b0, 1'b0);
	wire	[15:0]		w_tag_new_refill1 = fn_update_tag(ff_tag1, ff_key, ff_selected_way, 2'd1, 1'b1, 1'b0, 1'b0);
	wire	[15:0]		w_tag_new_refill2 = fn_update_tag(ff_tag2, ff_key, ff_selected_way, 2'd2, 1'b1, 1'b0, 1'b0);
	wire	[15:0]		w_tag_new_refill3 = fn_update_tag(ff_tag3, ff_key, ff_selected_way, 2'd3, 1'b1, 1'b0, 1'b0);

	function [1:0] fn_choose_way;
		input [15:0] t0;
		input [15:0] t1;
		input [15:0] t2;
		input [15:0] t3;
		begin
			if( !t0[14] )
				fn_choose_way = 2'd0;
			else if( !t1[14] )
				fn_choose_way = 2'd1;
			else if( !t2[14] )
				fn_choose_way = 2'd2;
			else if( !t3[14] )
				fn_choose_way = 2'd3;
			else if( t0[12:11] == 2'd0 )
				fn_choose_way = 2'd0;
			else if( t1[12:11] == 2'd0 )
				fn_choose_way = 2'd1;
			else if( t2[12:11] == 2'd0 )
				fn_choose_way = 2'd2;
			else
				fn_choose_way = 2'd3;
		end
	endfunction

	function [1:0] fn_dec_prio;
		input [1:0] p;
		begin
			if( p == 2'd0 )
				fn_dec_prio = 2'd0;
			else
				fn_dec_prio = p - 2'd1;
		end
	endfunction

	function [15:0] fn_update_tag;
		input [15:0] old_tag;
		input [10:0] key;
		input [1:0] selected_way;
		input [1:0] this_way;
		input force_valid;
		input force_update;
		input keep_update;
		reg [1:0] nprio;
		reg nvalid;
		reg nupdate;
		begin
			if( this_way == selected_way )
				nprio = 2'd3;
			else
				nprio = fn_dec_prio(old_tag[12:11]);

			nvalid = old_tag[14] | force_valid;
			if( this_way == selected_way ) begin
				if( keep_update )
					nupdate = old_tag[13];
				else
					nupdate = force_update;
			end
			else begin
				nupdate = old_tag[13];
			end

			if( this_way == selected_way )
				fn_update_tag = { 1'b0, nvalid, nupdate, nprio, key };
			else
				fn_update_tag = { old_tag[15], old_tag[14], old_tag[13], nprio, old_tag[10:0] };
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

	// ---------------------------------------------------------
	//	Cache Line
	// ---------------------------------------------------------
	cache_line u_cache_line0 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_line_oe_n		),
		.we_n			( ff_line_we_n		),
		.address		( ff_line_address	),
		.wdata			( ff_line0_wdata	),
		.rdata			( w_line0_rdata		)
	);

	cache_line u_cache_line1 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_line_oe_n		),
		.we_n			( ff_line_we_n		),
		.address		( ff_line_address	),
		.wdata			( ff_line1_wdata	),
		.rdata			( w_line1_rdata		)
	);

	// ---------------------------------------------------------
	//	TAG memory
	// ---------------------------------------------------------
	cache_tag u_cache_tag_way0 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_tag0_oe_n		),
		.we_n			( ff_tag0_we_n		),
		.address		( ff_tag_address	),
		.wdata			( ff_tag0_wdata		),
		.rdata			( w_tag0_rdata		)
	);

	cache_tag u_cache_tag_way1 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_tag1_oe_n		),
		.we_n			( ff_tag1_we_n		),
		.address		( ff_tag_address	),
		.wdata			( ff_tag1_wdata		),
		.rdata			( w_tag1_rdata		)
	);

	cache_tag u_cache_tag_way2 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_tag2_oe_n		),
		.we_n			( ff_tag2_we_n		),
		.address		( ff_tag_address	),
		.wdata			( ff_tag2_wdata		),
		.rdata			( w_tag2_rdata		)
	);

	cache_tag u_cache_tag_way3 (
		.reset			( reset				),
		.clk			( clk				),
		.oe_n			( ff_tag3_oe_n		),
		.we_n			( ff_tag3_we_n		),
		.address		( ff_tag_address	),
		.wdata			( ff_tag3_wdata		),
		.rdata			( w_tag3_rdata		)
	);

	always @( posedge clk ) begin
		if( reset ) begin
			ff_state <= c_state_init_tag_clear_req;
			ff_init_hash <= 7'd0;
			ff_refresh_counter <= 32'd0;
			ff_refresh_pending <= 1'b0;
			ff_refresh_seen_busy <= 1'b0;
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
			ff_line_address <= 12'd0;
			ff_line0_wdata <= 18'd0;
			ff_line1_wdata <= 18'd0;
			ff_tag0_oe_n <= 1'b1;
			ff_tag1_oe_n <= 1'b1;
			ff_tag2_oe_n <= 1'b1;
			ff_tag3_oe_n <= 1'b1;
			ff_tag0_we_n <= 1'b1;
			ff_tag1_we_n <= 1'b1;
			ff_tag2_we_n <= 1'b1;
			ff_tag3_we_n <= 1'b1;
			ff_tag_address <= 12'd0;
			ff_tag0_wdata <= 16'd0;
			ff_tag1_wdata <= 16'd0;
			ff_tag2_wdata <= 16'd0;
			ff_tag3_wdata <= 16'd0;
		end
		else begin
			ff_bus_rdata_valid <= 1'b0;
			ff_line_oe_n <= 1'b1;
			ff_line_we_n <= 1'b1;
			ff_tag0_oe_n <= 1'b1;
			ff_tag1_oe_n <= 1'b1;
			ff_tag2_oe_n <= 1'b1;
			ff_tag3_oe_n <= 1'b1;
			ff_tag0_we_n <= 1'b1;
			ff_tag1_we_n <= 1'b1;
			ff_tag2_we_n <= 1'b1;
			ff_tag3_we_n <= 1'b1;
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
			c_state_init_tag_clear_req: begin
				ff_tag_address <= { 5'd0, ff_init_hash };
				ff_tag0_wdata <= 16'd0;
				ff_tag1_wdata <= 16'd0;
				ff_tag2_wdata <= 16'd0;
				ff_tag3_wdata <= 16'd0;
				ff_tag0_we_n <= 1'b0;
				ff_tag1_we_n <= 1'b0;
				ff_tag2_we_n <= 1'b0;
				ff_tag3_we_n <= 1'b0;
				ff_state <= c_state_init_tag_clear_commit;
			end

			c_state_init_tag_clear_commit: begin
				if( ff_init_hash == 7'd127 ) begin
					ff_state <= c_state_idle;
				end
				else begin
					ff_init_hash <= ff_init_hash + 7'd1;
					ff_state <= c_state_init_tag_clear_req;
				end
			end

			c_state_idle: begin
				if( ff_refresh_pending ) begin
					ff_state <= c_state_refresh_req;
				end
				else if( bus_valid ) begin
					ff_req_address <= bus_address;
					ff_req_write <= bus_write;
					ff_req_flash <= bus_flash;
					ff_req_wdata <= bus_wdata;
					ff_hash <= bus_address[11:5];
					ff_key <= bus_address[22:12];
					ff_word_index <= bus_address[4:2];
					ff_half_select <= bus_address[1];
					if( bus_flash ) begin
						ff_flush_hash <= 7'd0;
						ff_flush_way <= 2'd0;
						ff_state <= c_state_flush_tag_req;
					end
					else begin
						ff_state <= c_state_tag_read_req;
					end
				end
			end

			c_state_tag_read_req: begin
				ff_tag_address <= { 5'd0, ff_hash };
				ff_tag0_oe_n <= 1'b0;
				ff_tag1_oe_n <= 1'b0;
				ff_tag2_oe_n <= 1'b0;
				ff_tag3_oe_n <= 1'b0;
				ff_state <= c_state_tag_read_wait;
			end

			c_state_tag_read_wait: begin
				ff_tag0 <= w_tag0_rdata;
				ff_tag1 <= w_tag1_rdata;
				ff_tag2 <= w_tag2_rdata;
				ff_tag3 <= w_tag3_rdata;
				ff_state <= c_state_tag_read_analyze;
			end

			c_state_tag_read_analyze: begin
				ff_hit <= w_any_hit;
				ff_hit_way <= w_hit_way;

				if( ff_req_write ) begin
					if( w_any_hit ) begin
						ff_selected_way <= w_hit_way;
						ff_state <= c_state_write_hit_line_req;
					end
					else begin
						ff_selected_way <= w_repl_way;
						ff_need_evict <= w_repl_need_evict;
						if( w_repl_need_evict ) begin
							ff_evict_hash <= ff_hash;
							ff_evict_key <= w_repl_key;
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
					if( w_any_hit ) begin
						ff_selected_way <= w_hit_way;
						ff_state <= c_state_read_hit_line_req;
					end
					else begin
						ff_selected_way <= w_repl_way;
						ff_need_evict <= w_repl_need_evict;
						if( w_repl_need_evict ) begin
							ff_evict_hash <= ff_hash;
							ff_evict_key <= w_repl_key;
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
				ff_line_address <= { ff_selected_way, ff_hash, ff_word_index };
				ff_line_oe_n <= 1'b0;
				ff_state <= c_state_read_hit_line_wait;
			end

			c_state_read_hit_line_wait: begin
				ff_line0_read <= w_line0_rdata;
				ff_line1_read <= w_line1_rdata;
				ff_state <= c_state_read_hit_line_analyze;
			end

			c_state_read_hit_line_analyze: begin
				if( ff_line0_read[17] ) begin
					if( ff_half_select )
						ff_read_result <= ff_line1_read[15:0];
					else
						ff_read_result <= ff_line0_read[15:0];
					ff_tag_new0 <= w_tag_new_read0;
					ff_tag_new1 <= w_tag_new_read1;
					ff_tag_new2 <= w_tag_new_read2;
					ff_tag_new3 <= w_tag_new_read3;
					ff_state <= c_state_prepare_tag_commit;
				end
				else begin
					ff_prescan_index <= 3'd0;
					ff_prescan_valid_bits <= 8'd0;
					ff_refill_partial <= 1'b1;
					ff_state <= c_state_prescan_req;
				end
			end

			c_state_prescan_req: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_prescan_index };
				ff_line_oe_n <= 1'b0;
				ff_state <= c_state_prescan_wait;
			end

			c_state_prescan_wait: begin
				ff_prescan_line_valid <= w_line0_rdata[17];
				ff_state <= c_state_prescan_capture;
			end

			c_state_prescan_capture: begin
				ff_prescan_valid_bits[ff_prescan_index] <= ff_prescan_line_valid;
				if( ff_prescan_index == 3'd7 ) begin
					ff_state <= c_state_refill_read_req;
				end
				else begin
					ff_prescan_index <= ff_prescan_index + 3'd1;
					ff_state <= c_state_prescan_req;
				end
			end

			c_state_refill_read_req: begin
				ff_sdram_address <= { ff_key, ff_hash };
				ff_sdram_write <= 1'b0;
				ff_sdram_valid <= 1'b1;
				ff_burst_count <= 3'd0;
				ff_state <= c_state_refill_read_wait_accept;
			end

			c_state_refill_read_wait_accept: begin
				ff_sdram_address <= { ff_key, ff_hash };
				ff_sdram_write <= 1'b0;
				ff_sdram_valid <= 1'b1;
				if( sdram_ready ) begin
					ff_state <= c_state_refill_read_stream;
				end
			end

			c_state_refill_read_stream: begin
				if( sdram_rdata_valid ) begin
					ff_burst_rdata_latched <= sdram_rdata;
					if( !ff_refill_partial || !ff_prescan_valid_bits[ff_burst_count] ) begin
						ff_line_address <= { ff_selected_way, ff_hash, ff_burst_count };
						ff_line0_wdata <= { 1'b1, 1'b0, sdram_rdata[15:0] };
						ff_line1_wdata <= { 1'b1, 1'b0, sdram_rdata[31:16] };
						ff_line_we_n <= 1'b0;
					end
					if( ff_burst_count == ff_word_index ) begin
						if( ff_half_select )
							ff_read_result <= sdram_rdata[31:16];
						else
							ff_read_result <= sdram_rdata[15:0];
					end
					if( ff_burst_count == 3'd7 ) begin
						ff_tag_new0 <= w_tag_new_refill0;
						ff_tag_new1 <= w_tag_new_refill1;
						ff_tag_new2 <= w_tag_new_refill2;
						ff_tag_new3 <= w_tag_new_refill3;
						ff_state <= c_state_prepare_tag_commit;
					end
					else begin
						ff_burst_count <= ff_burst_count + 3'd1;
					end
				end
			end

			c_state_write_hit_line_req: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_word_index };
				ff_line_oe_n <= 1'b0;
				ff_state <= c_state_write_hit_line_wait;
			end

			c_state_write_hit_line_wait: begin
				ff_line0_read <= w_line0_rdata;
				ff_line1_read <= w_line1_rdata;
				ff_state <= c_state_write_hit_line_commit;
			end

			c_state_write_hit_line_commit: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_word_index };
				if( ff_half_select ) begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_line0_read[15:0] };
					ff_line1_wdata <= { 1'b1, 1'b1, ff_req_wdata };
				end
				else begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_req_wdata };
					ff_line1_wdata <= { 1'b1, 1'b1, ff_line1_read[15:0] };
				end
				ff_line_we_n <= 1'b0;
				ff_tag_new0 <= w_tag_new_write0;
				ff_tag_new1 <= w_tag_new_write1;
				ff_tag_new2 <= w_tag_new_write2;
				ff_tag_new3 <= w_tag_new_write3;
				ff_state <= c_state_prepare_tag_commit;
			end

			c_state_alloc_clear_req: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_alloc_clear_index };
				ff_line0_wdata <= 18'd0;
				ff_line1_wdata <= 18'd0;
				ff_line_we_n <= 1'b0;
				ff_state <= c_state_alloc_clear_commit;
			end

			c_state_alloc_clear_commit: begin
				if( ff_alloc_clear_index == 3'd7 ) begin
					ff_state <= c_state_write_miss_line_req;
				end
				else begin
					ff_alloc_clear_index <= ff_alloc_clear_index + 3'd1;
					ff_state <= c_state_alloc_clear_req;
				end
			end

			c_state_write_miss_line_req: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_word_index };
				ff_line_oe_n <= 1'b0;
				ff_state <= c_state_write_miss_line_wait;
			end

			c_state_write_miss_line_wait: begin
				ff_line0_read <= w_line0_rdata;
				ff_line1_read <= w_line1_rdata;
				ff_state <= c_state_write_miss_line_commit;
			end

			c_state_write_miss_line_commit: begin
				ff_line_address <= { ff_selected_way, ff_hash, ff_word_index };
				if( ff_half_select ) begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_line0_read[15:0] };
					ff_line1_wdata <= { 1'b1, 1'b1, ff_req_wdata };
				end
				else begin
					ff_line0_wdata <= { 1'b1, 1'b1, ff_req_wdata };
					ff_line1_wdata <= { 1'b1, 1'b1, ff_line1_read[15:0] };
				end
				ff_line_we_n <= 1'b0;
				ff_tag_new0 <= w_tag_new_write0;
				ff_tag_new1 <= w_tag_new_write1;
				ff_tag_new2 <= w_tag_new_write2;
				ff_tag_new3 <= w_tag_new_write3;
				ff_state <= c_state_prepare_tag_commit;
			end

			c_state_prepare_tag_commit: begin
				ff_state <= c_state_tag_commit;
			end

			c_state_tag_commit: begin
				ff_tag_address <= { 5'd0, ff_hash };
				ff_tag0_wdata <= ff_tag_new0;
				ff_tag1_wdata <= ff_tag_new1;
				ff_tag2_wdata <= ff_tag_new2;
				ff_tag3_wdata <= ff_tag_new3;
				ff_tag0_we_n <= 1'b0;
				ff_tag1_we_n <= 1'b0;
				ff_tag2_we_n <= 1'b0;
				ff_tag3_we_n <= 1'b0;
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

			c_state_refresh_req: begin
				ff_sdram_write <= 1'b0;
				ff_sdram_refresh <= 1'b1;
				ff_sdram_address <= 18'd0;
				ff_sdram_valid <= 1'b1;
				ff_refresh_seen_busy <= 1'b0;
				ff_state <= c_state_refresh_wait_accept;
			end

			c_state_refresh_wait_accept: begin
				ff_sdram_write <= 1'b0;
				ff_sdram_refresh <= 1'b1;
				ff_sdram_address <= 18'd0;
				ff_sdram_valid <= 1'b1;
				if( sdram_ready ) begin
					ff_refresh_pending <= 1'b0;
					ff_state <= c_state_refresh_wait_done;
				end
			end

			c_state_refresh_wait_done: begin
				if( !sdram_ready ) begin
					ff_refresh_seen_busy <= 1'b1;
				end
				else if( ff_refresh_seen_busy ) begin
					ff_state <= c_state_idle;
				end
			end

			c_state_flush_tag_req: begin
				ff_tag_address <= { 5'd0, ff_flush_hash };
				ff_tag0_oe_n <= 1'b0;
				ff_tag1_oe_n <= 1'b0;
				ff_tag2_oe_n <= 1'b0;
				ff_tag3_oe_n <= 1'b0;
				ff_state <= c_state_flush_tag_wait;
			end

			c_state_flush_tag_wait: begin
				ff_tag0 <= w_tag0_rdata;
				ff_tag1 <= w_tag1_rdata;
				ff_tag2 <= w_tag2_rdata;
				ff_tag3 <= w_tag3_rdata;
				ff_state <= c_state_flush_tag_analyze;
			end

			c_state_flush_tag_analyze: begin
				ff_need_evict <= w_flush_need_evict;
				if( w_flush_need_evict ) begin
					ff_evict_hash <= ff_flush_hash;
					ff_evict_key <= w_flush_evict_key;
					ff_selected_way <= ff_flush_way;
					ff_evict_index <= 3'd0;
					ff_evict_post_state <= c_post_evict_flush;
					ff_state <= c_state_evict_line_req;
				end
				else begin
					ff_state <= c_state_flush_tag_clear;
				end
			end

			c_state_flush_tag_clear: begin
				ff_tag_address <= { 5'd0, ff_flush_hash };
				case( ff_flush_way )
				2'd0: begin ff_tag0_wdata <= 16'd0; ff_tag0_we_n <= 1'b0; end
				2'd1: begin ff_tag1_wdata <= 16'd0; ff_tag1_we_n <= 1'b0; end
				2'd2: begin ff_tag2_wdata <= 16'd0; ff_tag2_we_n <= 1'b0; end
				default: begin ff_tag3_wdata <= 16'd0; ff_tag3_we_n <= 1'b0; end
				endcase
				ff_state <= c_state_flush_next;
			end

			c_state_flush_next: begin
				if( ff_flush_way == 2'd3 ) begin
					ff_flush_way <= 2'd0;
					if( ff_flush_hash == 7'd127 )
						ff_state <= c_state_finish_req;
					else begin
						ff_flush_hash <= ff_flush_hash + 7'd1;
						ff_state <= c_state_flush_tag_req;
					end
				end
				else begin
					ff_flush_way <= ff_flush_way + 2'd1;
					ff_state <= c_state_flush_tag_req;
				end
			end

			c_state_evict_line_req: begin
				ff_line_address <= { ff_selected_way, ff_evict_hash, ff_evict_index };
				ff_line_oe_n <= 1'b0;
				ff_state <= c_state_evict_line_wait;
			end

			c_state_evict_line_wait: begin
				ff_evict_line_data <= { w_line1_rdata[15:0], w_line0_rdata[15:0] };
				ff_evict_line_mask <= fn_make_dqm(w_line0_rdata[17], w_line0_rdata[16], w_line1_rdata[17], w_line1_rdata[16]);
				ff_state <= c_state_evict_line_capture;
			end

			c_state_evict_line_capture: begin
				case( ff_evict_index )
				3'd0: begin 	ff_evict_data0 <= ff_evict_line_data; ff_evict_mask0 <= ff_evict_line_mask; end
				3'd1: begin 	ff_evict_data1 <= ff_evict_line_data; ff_evict_mask1 <= ff_evict_line_mask; end
				3'd2: begin 	ff_evict_data2 <= ff_evict_line_data; ff_evict_mask2 <= ff_evict_line_mask; end
				3'd3: begin 	ff_evict_data3 <= ff_evict_line_data; ff_evict_mask3 <= ff_evict_line_mask; end
				3'd4: begin		ff_evict_data4 <= ff_evict_line_data; ff_evict_mask4 <= ff_evict_line_mask; end
				3'd5: begin		ff_evict_data5 <= ff_evict_line_data; ff_evict_mask5 <= ff_evict_line_mask; end
				3'd6: begin		ff_evict_data6 <= ff_evict_line_data; ff_evict_mask6 <= ff_evict_line_mask; end
				default: begin	ff_evict_data7 <= ff_evict_line_data; ff_evict_mask7 <= ff_evict_line_mask; end
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
				ff_sdram_address <= { ff_evict_key, ff_evict_hash };
				ff_sdram_write <= 1'b1;
				ff_sdram_valid <= 1'b1;
				ff_state <= c_state_evict_sdram_wait_accept;
			end

			c_state_evict_sdram_wait_accept: begin
				ff_sdram_address <= { ff_evict_key, ff_evict_hash };
				ff_sdram_write <= 1'b1;
				ff_sdram_valid <= 1'b1;
				if( sdram_ready ) begin
					ff_evict_index <= 3'd0;
					ff_state <= c_state_evict_sdram_stream;
				end
			end

			c_state_evict_sdram_stream: begin
				ff_sdram_wdata <= fn_get_evict_data(ff_evict_index);
				ff_sdram_wdata_mask <= fn_get_evict_mask(ff_evict_index);
				ff_sdram_wdata_valid <= 1'b1;
				if( ff_evict_index == 3'd7 ) begin
					ff_refresh_seen_busy <= 1'b0;
					ff_state <= c_state_evict_sdram_wait_done;
				end
				else begin
					ff_evict_index <= ff_evict_index + 3'd1;
				end
			end

			c_state_evict_sdram_wait_done: begin
				if( !sdram_ready ) begin
					ff_refresh_seen_busy <= 1'b1;
				end
				else if( ff_refresh_seen_busy ) begin
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
			end

			default: begin
				ff_state <= c_state_idle;
			end
			endcase
		end
	end

	assign bus_ready			= (ff_state == c_state_idle) && !ff_refresh_pending;
	assign bus_rdata			= ff_bus_rdata;
	assign bus_rdata_valid		= ff_bus_rdata_valid;

	assign sdram_address		= ff_sdram_address;
	assign sdram_write			= ff_sdram_write;
	assign sdram_refresh		= ff_sdram_refresh;
	assign sdram_valid			= ff_sdram_valid;
	assign sdram_wdata			= ff_sdram_wdata;
	assign sdram_wdata_mask		= ff_sdram_wdata_mask;
	assign sdram_wdata_valid	= ff_sdram_wdata_valid;
endmodule
