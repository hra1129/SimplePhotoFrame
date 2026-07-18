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

	reg				ff_priority;
	reg				ff_read_bus;
	reg				ff_read_stall;
	reg				ff_write_stall;
	reg				ff_ready;
	reg		[2:0]	ff_read_count;
	reg		[2:0]	ff_write_count;
	wire			w_active;
	wire	[1:0]	w_valid;
	wire	[1:0]	w_priority_valid;
	wire	[0:0]	w_selected_valid;
	wire	[0:0]	w_selected_bus;
	wire	[22:5]	w_selected_bus_address;
	wire	[31:0]	w_selected_bus_wdata;
	wire	[3:0]	w_selected_bus_wdata_mask;
	wire			w_selected_bus_write;
	wire			w_selected_bus_refresh;
	wire			w_selected_bus_wdata_valid;
	wire			w_selected_bus_read;

	function [1:0] func_rotate_priority(
		input [1:0] valid,
		input [0:0] priority
	);
		case( priority )
			1'd0:		func_rotate_priority = valid;
			default:	func_rotate_priority = { valid[0], valid[1] };
		endcase
	endfunction

	function [0:0] func_select_valid(
		input [1:0] valid
	);
		casex( valid )
			2'bx1:		func_select_valid = 1'd0;
			default:	func_select_valid = 1'd1;
		endcase
	endfunction

	function [22:5] func_select_address(
		input 			bus,
		input [22:5]	sdram_display_address,
		input [22:5]	sdram_cache_address
	);
		case( bus )
			1'd0:		func_select_address = sdram_display_address;
			default:	func_select_address = sdram_cache_address;
		endcase
	endfunction

	function [31:0] func_select_wdata(
		input 			bus,
		input [31:0]	sdram_cache_wdata
	);
		case( bus )
			1'd0:		func_select_wdata = 32'd0;
			default:	func_select_wdata = sdram_cache_wdata;
		endcase
	endfunction

	function [3:0] func_select_wdata_mask(
		input 			bus,
		input [3:0]		sdram_cache_wdata_mask
	);
		case( bus )
			1'd0:		func_select_wdata_mask = 4'd0;
			default:	func_select_wdata_mask = sdram_cache_wdata_mask;
		endcase
	endfunction

	function func_select_1bit(
		input 			bus,
		input			sdram_display_sig,
		input			sdram_cache_sig
	);
		case( bus )
			1'd0:		func_select_1bit = sdram_display_sig;
			default:	func_select_1bit = sdram_cache_sig;
		endcase
	endfunction

	assign w_active						= (sdram_display_address_valid | sdram_cache_address_valid) & ff_ready & !ff_read_stall & !ff_write_stall;
	assign w_valid						= { sdram_cache_address_valid, sdram_display_address_valid };
	assign w_priority_valid				= func_rotate_priority( w_valid, ff_priority );
	assign w_selected_valid				= func_select_valid( w_priority_valid );
	assign w_selected_bus				= w_selected_valid + ff_priority;

	assign w_selected_bus_address		= func_select_address( w_selected_bus, sdram_display_address, sdram_cache_address );
	assign w_selected_bus_wdata			= func_select_wdata( w_selected_bus, sdram_cache_wdata );
	assign w_selected_bus_wdata_mask	= func_select_wdata_mask( w_selected_bus, sdram_cache_wdata_mask );
	assign w_selected_bus_write			= func_select_1bit( w_selected_bus, 1'b0, sdram_cache_write );
	assign w_selected_bus_refresh		= func_select_1bit( w_selected_bus, 1'b0, sdram_cache_refresh );
	assign w_selected_bus_wdata_valid	= func_select_1bit( w_selected_bus, 1'b0, sdram_cache_wdata_valid );
	assign w_selected_bus_read			= !w_selected_bus_write & !w_selected_bus_refresh;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_priority <= 1'd0;
		end
		else if( w_active ) begin
			ff_priority <= w_selected_bus ^ 1'd1;
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
		end
		else if( !ff_ready ) begin
			if( ff_read_stall ) begin
				if( sdram_rdata_valid ) begin
					if( ff_read_count == c_read_burst_last ) begin
						ff_ready		<= 1'b0;
						ff_read_stall	<= 1'b0;
						ff_read_count	<= 3'd0;
					end
					else begin
						ff_read_count <= ff_read_count + 3'd1;
					end
				end
			end
			else if( ff_write_stall ) begin
				if( sdram_cache_wdata_valid ) begin
					if( ff_write_count == c_read_burst_last ) begin
						ff_ready		<= 1'b0;
						ff_write_stall	<= 1'b0;
						ff_write_count	<= 3'd0;
					end
					else begin
						ff_write_count <= ff_write_count + 3'd1;
					end
				end
			end
			else if( sdram_address_ready ) begin
				ff_ready <= 1'b1;
			end
		end
		else if( w_active ) begin
			ff_ready <= 1'b0;
			if( w_selected_bus_read ) begin
				ff_read_stall <= 1'b1;
				ff_read_bus <= w_selected_bus;
				ff_read_count <= 3'd0;
			end
			else if( w_selected_bus_write ) begin
				ff_write_stall <= 1'b1;
				ff_write_count <= 3'd0;
			end
		end
	end

	assign sdram_display_rdata			= (ff_read_bus == 1'd0) ? sdram_rdata : 32'd0;
	assign sdram_cache_rdata			= (ff_read_bus == 1'd1) ? sdram_rdata : 32'd0;

	assign sdram_display_rdata_valid	= (ff_read_bus == 1'd0) ? sdram_rdata_valid : 1'b0;
	assign sdram_cache_rdata_valid		= (ff_read_bus == 1'd1) ? sdram_rdata_valid : 1'b0;

	assign sdram_display_address_ready	= (w_selected_bus == 1'd0) ? (ff_ready & !ff_read_stall & !ff_write_stall) : 1'b0;
	assign sdram_cache_address_ready	= (w_selected_bus == 1'd1) ? (ff_ready & !ff_read_stall & !ff_write_stall) : 1'b0;

	assign sdram_address				= w_selected_bus_address;
	assign sdram_write					= w_selected_bus_write;
	assign sdram_refresh				= w_selected_bus_refresh;
	assign sdram_address_valid			= w_active;
	assign sdram_wdata					= w_selected_bus_wdata;
	assign sdram_wdata_mask				= w_selected_bus_wdata_mask;
	assign sdram_wdata_valid			= w_selected_bus_wdata_valid;

endmodule
