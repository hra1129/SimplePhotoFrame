//
// bus_selector.v
//
//	Copyright (C) 2026 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module bus_selector (
	input			clk,
	input			reset,
	// SDRAM interface for Display controller (read only)
	input	[22:5]	sdram_display_address,
	input			sdram_display_address_valid,
	output			sdram_display_address_ready,
	output	[31:0]	sdram_display_rdata,
	output			sdram_display_rdata_valid,
	// SDRAM interface for Cache memory
	input	[22:5]	sdram_cache_address,
	input			sdram_cache_write,
	input			sdram_cache_refresh,
	input			sdram_cache_address_valid,
	output			sdram_cache_address_ready,
	input	[31:0]	sdram_cache_wdata,
	input	[3:0]	sdram_cache_wdata_mask,
	input			sdram_cache_wdata_valid,
	output	[31:0]	sdram_cache_rdata,
	output			sdram_cache_rdata_valid,
	// SDRAM interface
	output	[22:5]	sdram_address,
	output			sdram_write,
	output			sdram_refresh,
	output			sdram_address_valid,
	input			sdram_address_ready,
	output	[31:0]	sdram_wdata,
	output	[3:0]	sdram_wdata_mask,
	output			sdram_wdata_valid,
	input	[31:0]	sdram_rdata,
	input			sdram_rdata_valid
);
	localparam [2:0] c_read_burst_last = 3'd7;

	reg				ff_grant_bus;
	reg				ff_read_bus;
	reg				ff_read_stall;
	reg				ff_write_stall;
	reg				ff_ready;
	reg				ff_rr_turn;
	reg		[2:0]	ff_read_count;
	reg		[2:0]	ff_write_count;
	reg				ff_read_seen_busy;
	reg				ff_read_data_started;
	reg				ff_write_seen_busy;
	reg				ff_prefetch_valid;
	reg				ff_prefetch_bus;
	reg	[22:5]	ff_prefetch_address;
	wire			w_request_valid;
	wire			w_cache_request_valid;
	wire			w_active;
	wire			w_prefetch_issue;
	wire			w_prefetch_capture;
	wire			w_prefetch_display_valid;
	wire			w_prefetch_cache_valid;
	wire			w_prefetch_selected_bus;
	wire			w_active_bus;
	wire	[0:0]	w_selected_bus;
	wire			w_selected_bus_write;
	wire			w_selected_bus_refresh;
	wire			w_selected_bus_read;
	wire			w_output_bus;
	//	display または cache からのリクエストを受理するかどうかを決定する
	assign w_cache_request_valid		= sdram_cache_address_valid;
	assign w_request_valid				= (sdram_display_address_valid | w_cache_request_valid) & ff_ready & !ff_read_stall & !ff_write_stall;
	//	さらに、SDRAM Controller が受理可能かどうかを考慮して、active 信号を生成する
	assign w_active						= (w_request_valid || w_prefetch_issue) & sdram_address_ready;
	//	Display / Cache が同時に valid のときは、受理ごとに交互に選択する。
	assign w_selected_bus				= (sdram_display_address_valid && sdram_cache_address_valid)
										? ff_rr_turn
										: w_cache_request_valid;

	assign w_selected_bus_write			= w_selected_bus ? sdram_cache_write       : 1'b0;
	assign w_selected_bus_refresh		= w_selected_bus ? sdram_cache_refresh     : 1'b0;
	assign w_selected_bus_read			= !w_selected_bus_write & !w_selected_bus_refresh;
	assign w_output_bus					= (ff_read_stall || ff_write_stall) ? ff_grant_bus : w_selected_bus;
	assign w_prefetch_display_valid		= sdram_display_address_valid;
	assign w_prefetch_cache_valid		= sdram_cache_address_valid && !sdram_cache_write && !sdram_cache_refresh;
	assign w_prefetch_selected_bus		= (w_prefetch_display_valid && w_prefetch_cache_valid)
										? ff_rr_turn
										: w_prefetch_cache_valid;
	assign w_prefetch_capture			= ff_read_stall && ff_read_data_started && !ff_prefetch_valid && (w_prefetch_display_valid || w_prefetch_cache_valid);
	assign w_prefetch_issue				= ff_prefetch_valid && !ff_read_stall && !ff_write_stall;
	assign w_active_bus					= w_prefetch_issue ? ff_prefetch_bus : w_selected_bus;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_grant_bus	<= 1'd0;
			ff_rr_turn		<= 1'b0;
		end
		else begin
			if( w_active ) begin
				ff_grant_bus	<= w_active_bus;
				ff_rr_turn		<= ~w_active_bus;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_ready		<= 1'b0;
			ff_read_bus		<= 1'd0;
			ff_read_stall	<= 1'b0;
			ff_write_stall	<= 1'b0;
			ff_read_count	<= 3'd0;
			ff_write_count	<= 3'd0;
			ff_read_seen_busy <= 1'b0;
			ff_read_data_started <= 1'b0;
			ff_write_seen_busy <= 1'b0;
			ff_prefetch_valid <= 1'b0;
			ff_prefetch_bus <= 1'b0;
			ff_prefetch_address <= 18'd0;
		end
		else if( !ff_ready ) begin
			if( ff_read_stall ) begin
				if( w_prefetch_capture ) begin
					ff_prefetch_valid <= 1'b1;
					ff_prefetch_bus <= w_prefetch_selected_bus;
					ff_prefetch_address <= w_prefetch_selected_bus ? sdram_cache_address : sdram_display_address;
				end
				if( !sdram_address_ready ) begin
					ff_read_seen_busy <= 1'b1;
				end
				if( sdram_rdata_valid ) begin
					ff_read_data_started <= 1'b1;
					if( ff_read_count == c_read_burst_last ) begin
						ff_ready		<= 1'b0;
						ff_read_stall	<= 1'b0;
						ff_read_count	<= 3'd0;
						ff_read_seen_busy <= 1'b0;
						ff_read_data_started <= 1'b0;
					end
					else begin
						ff_read_count	<= ff_read_count + 3'd1;
					end
				end
				else if( ff_read_seen_busy && sdram_address_ready && !ff_read_data_started ) begin
					// Failsafe: request was likely not accepted yet. Once data starts,
					// keep read_stall until the full 8-beat burst is consumed.
					ff_read_stall			<= 1'b0;
					ff_read_count			<= 3'd0;
					ff_read_seen_busy		<= 1'b0;
					ff_read_data_started	<= 1'b0;
				end
			end
			else if( ff_write_stall ) begin
				if( !sdram_address_ready ) begin
					ff_write_seen_busy	<= 1'b1;
				end
				if( sdram_cache_wdata_valid ) begin
					if( ff_write_count == c_read_burst_last ) begin
						ff_ready			<= 1'b0;
						ff_write_stall		<= 1'b0;
						ff_write_seen_busy	<= 1'b0;
						ff_write_count		<= 3'd0;
					end
					else begin
						ff_write_count		<= ff_write_count + 3'd1;
					end
				end
				else if( ff_write_seen_busy && sdram_address_ready ) begin
					ff_write_stall		<= 1'b0;
					ff_write_count		<= 3'd0;
					ff_write_seen_busy	<= 1'b0;
				end
			end
			else if( w_prefetch_issue && sdram_address_ready ) begin
				ff_prefetch_valid		<= 1'b0;
				ff_read_stall			<= 1'b1;
				ff_read_bus				<= ff_prefetch_bus;
				ff_read_count			<= 3'd0;
				ff_read_seen_busy		<= 1'b0;
				ff_read_data_started	<= 1'b0;
			end
			else if( sdram_address_ready ) begin
				ff_ready	<= 1'b1;
			end
		end
		else if( w_active ) begin
			ff_ready <= 1'b0;
			if( w_selected_bus_read ) begin
				ff_read_stall			<= 1'b1;
				ff_read_bus				<= w_active_bus;
				ff_read_count			<= 3'd0;
				ff_read_seen_busy		<= 1'b0;
				ff_read_data_started	<= 1'b0;
			end
			else if( w_selected_bus_write ) begin
				ff_write_stall			<= 1'b1;
				ff_write_count			<= 3'd0;
				ff_write_seen_busy		<= 1'b0;
			end
		end
	end

	assign sdram_display_rdata			= !ff_read_bus ? sdram_rdata : 32'd0;
	assign sdram_cache_rdata			=  ff_read_bus ? sdram_rdata : 32'd0;

	assign sdram_display_rdata_valid	= !ff_read_bus ? sdram_rdata_valid : 1'b0;
	assign sdram_cache_rdata_valid		=  ff_read_bus ? sdram_rdata_valid : 1'b0;

	assign sdram_display_address_ready	= ((!w_selected_bus && sdram_display_address_valid) ? (ff_ready & !ff_read_stall & !ff_write_stall & sdram_address_ready) : 1'b0)
										| (w_prefetch_capture && !w_prefetch_selected_bus);
	assign sdram_cache_address_ready	= ((w_selected_bus && sdram_cache_address_valid) ? (ff_ready & !ff_read_stall & !ff_write_stall & sdram_address_ready) : 1'b0)
										| (w_prefetch_capture && w_prefetch_selected_bus);

	assign sdram_address_valid			= w_request_valid || w_prefetch_issue;
	assign sdram_address				= w_prefetch_issue ? ff_prefetch_address : (w_output_bus ? sdram_cache_address : sdram_display_address);
	assign sdram_write					= w_prefetch_issue ? 1'b0 : (w_output_bus ? sdram_cache_write : 1'b0);
	assign sdram_refresh				= w_prefetch_issue ? 1'b0 : (w_output_bus ? sdram_cache_refresh : 1'b0);
	assign sdram_wdata					= w_prefetch_issue ? 32'd0 : (w_output_bus ? sdram_cache_wdata : 32'd0);
	assign sdram_wdata_mask				= w_prefetch_issue ? 4'd0 : (w_output_bus ? sdram_cache_wdata_mask : 4'd0);
	assign sdram_wdata_valid			= w_prefetch_issue ? 1'b0 : (w_output_bus ? sdram_cache_wdata_valid : 1'b0);
endmodule


