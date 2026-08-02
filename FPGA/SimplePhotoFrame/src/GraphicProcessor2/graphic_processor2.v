//
// graphic_processor2.v
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

module graphic_processor2 (
	input			clk,
	input			reset,
	input			sdram_init_busy,
	//	Register interface
	input			bus_cs,
	input	[4:0]	bus_address,
	input			bus_valid,
	output			bus_ready,
	input			bus_write,
	input	[15:0]	bus_wdata,
	output	[15:0]	bus_rdata,
	output			bus_rdata_valid,
	// SDRAM interface
	output	[22:1]	sdram_address,
	output			sdram_write,
	output	[15:0]	sdram_wdata,
	output			sdram_valid,
	output			sdram_flush,
	input			sdram_ready,
	input	[15:0]	sdram_rdata,
	input			sdram_rdata_valid
);
	localparam [15:0] c_rop_put = 16'h0000;
	localparam [15:0] c_rop_or  = 16'h0001;
	localparam [15:0] c_rop_and = 16'h0002;
	localparam [15:0] c_rop_xor = 16'h0003;
	localparam [15:0] c_rop_add = 16'h0004;
	localparam [15:0] c_rop_sub = 16'h0005;
	localparam [15:0] c_rop_mix = 16'h0006;
	localparam [15:0] c_rop_min = 16'h0007;
	localparam [15:0] c_rop_max = 16'h0008;

	localparam [2:0] c_state_idle           = 3'd0;
	localparam [2:0] c_state_issue_src_read = 3'd1;
	localparam [2:0] c_state_wait_src_read  = 3'd2;
	localparam [2:0] c_state_issue_dst_read = 3'd3;
	localparam [2:0] c_state_wait_dst_read  = 3'd4;
	localparam [2:0] c_state_issue_write    = 3'd5;
	localparam [2:0] c_state_issue_flush    = 3'd6;

	reg signed	[15:0]	reg_sx;
	reg signed	[15:0]	reg_sy;
	reg		[15:0]	reg_swidth;
	reg		[15:0]	reg_sheight;
	reg signed	[15:0]	reg_dx;
	reg signed	[15:0]	reg_dy;
	reg		[15:0]	reg_dwidth;
	reg		[15:0]	reg_dheight;
	reg		[15:0]	reg_rop;
	reg		[22:1]	reg_vram_address;

	reg		[2:0]	ff_state;
	reg				ff_busy;
	reg		[15:0]	ff_bus_rdata;
	reg				ff_bus_rdata_valid;

	reg signed	[15:0]	ff_exec_sx;
	reg signed	[15:0]	ff_exec_sy;
	reg		[15:0]	ff_exec_swidth;
	reg		[15:0]	ff_exec_sheight;
	reg signed	[15:0]	ff_exec_dx;
	reg signed	[15:0]	ff_exec_dy;
	reg		[15:0]	ff_exec_dwidth;
	reg		[15:0]	ff_exec_dheight;
	reg		[15:0]	ff_exec_rop;
	reg		[22:1]	ff_exec_base_address;

	reg		[15:0]	ff_cur_dx;
	reg		[15:0]	ff_cur_dy;
	reg		[15:0]	ff_cur_src_x;
	reg		[15:0]	ff_cur_src_y;

	reg		[15:0]	ff_cur_dst_x;
	reg		[15:0]	ff_cur_dst_y;

	reg		[22:1]	ff_cur_src_address;
	reg		[22:1]	ff_cur_dst_address;

	reg		[15:0]	ff_src_color;
	reg		[15:0]	ff_dst_color;
	reg		[15:0]	ff_src_x_offset;
	reg		[15:0]	ff_src_y_offset;
	reg		[15:0]	ff_src_x_error;
	reg		[15:0]	ff_src_y_error;
	reg		[22:1]	ff_src_row_address;

	reg		[22:1]	ff_sdram_address;
	reg				ff_sdram_write;
	reg		[15:0]	ff_sdram_wdata;
	reg				ff_sdram_valid;
	reg				ff_sdram_flush;
	reg				ff_flush_pending;

	reg		[15:0]	ff_clipped_swidth;
	reg		[15:0]	ff_clipped_sheight;
	reg		[15:0]	ff_clipped_dwidth;
	reg		[15:0]	ff_clipped_dheight;
	reg		[15:0]	ff_clipped_sx;
	reg		[15:0]	ff_clipped_sy;
	reg		[15:0]	ff_clipped_dx;
	reg		[15:0]	ff_clipped_dy;

	function [15:0] f_clip_start;
		input signed [15:0] start;
		input [15:0] limit;
	begin
		if( start < 16'sd0 ) begin
			f_clip_start = 16'd0;
		end
		else if( start >= $signed({1'b0, limit}) ) begin
			f_clip_start = 16'd0;
		end
		else begin
			f_clip_start = start[15:0];
		end
	end
	endfunction

	function [15:0] f_clip_size;
		input signed [15:0] start;
		input [15:0] size;
		input [15:0] limit;
		reg signed [16:0] left;
		reg signed [16:0] right;
		reg signed [16:0] end_pos;
	begin
		end_pos = start + $signed({1'b0, size});

		if( start < 16'sd0 ) begin
			left = 17'sd0;
		end
		else begin
			left = $signed({1'b0, start});
		end

		if( end_pos > $signed({1'b0, limit}) ) begin
			right = $signed({1'b0, limit});
		end
		else begin
			right = end_pos;
		end

		if( right <= left ) begin
			f_clip_size = 16'd0;
		end
		else begin
			f_clip_size = right - left;
		end
	end
	endfunction

	function [15:0] f_apply_rop;
		input [15:0] op;
		input [15:0] src;
		input [15:0] dst;
		reg [5:0] src_r;
		reg [5:0] src_g;
		reg [5:0] src_b;
		reg [5:0] dst_r;
		reg [5:0] dst_g;
		reg [5:0] dst_b;
		reg [6:0] tmp7;
		reg [5:0] out_r;
		reg [5:0] out_g;
		reg [5:0] out_b;
	begin
		src_r = { 1'b0, src[15:11] };
		src_g = src[10:5];
		src_b = { 1'b0, src[4:0] };
		dst_r = { 1'b0, dst[15:11] };
		dst_g = dst[10:5];
		dst_b = { 1'b0, dst[4:0] };
		out_r = dst_r;
		out_g = dst_g;
		out_b = dst_b;

		case( op )
		c_rop_put: begin
			f_apply_rop = src;
		end
		c_rop_or: begin
			f_apply_rop = dst | src;
		end
		c_rop_and: begin
			f_apply_rop = dst & src;
		end
		c_rop_xor: begin
			f_apply_rop = dst ^ src;
		end
		c_rop_add: begin
			tmp7 = dst_r + src_r;
			out_r = (tmp7 > 7'd31) ? 6'd31 : tmp7[5:0];
			tmp7 = dst_g + src_g;
			out_g = (tmp7 > 7'd63) ? 6'd63 : tmp7[5:0];
			tmp7 = dst_b + src_b;
			out_b = (tmp7 > 7'd31) ? 6'd31 : tmp7[5:0];
			f_apply_rop = { out_r[4:0], out_g, out_b[4:0] };
		end
		c_rop_sub: begin
			out_r = (dst_r > src_r) ? (dst_r - src_r) : 6'd0;
			out_g = (dst_g > src_g) ? (dst_g - src_g) : 6'd0;
			out_b = (dst_b > src_b) ? (dst_b - src_b) : 6'd0;
			f_apply_rop = { out_r[4:0], out_g, out_b[4:0] };
		end
		c_rop_mix: begin
			out_r = (dst_r + src_r) >> 1;
			out_g = (dst_g + src_g) >> 1;
			out_b = (dst_b + src_b) >> 1;
			f_apply_rop = { out_r[4:0], out_g, out_b[4:0] };
		end
		c_rop_min: begin
			out_r = (dst_r < src_r) ? dst_r : src_r;
			out_g = (dst_g < src_g) ? dst_g : src_g;
			out_b = (dst_b < src_b) ? dst_b : src_b;
			f_apply_rop = { out_r[4:0], out_g, out_b[4:0] };
		end
		c_rop_max: begin
			out_r = (dst_r > src_r) ? dst_r : src_r;
			out_g = (dst_g > src_g) ? dst_g : src_g;
			out_b = (dst_b > src_b) ? dst_b : src_b;
			f_apply_rop = { out_r[4:0], out_g, out_b[4:0] };
		end
		default: begin
			f_apply_rop = src;
		end
		endcase
	end
	endfunction

	always @( posedge clk ) begin
		if( reset ) begin
			ff_state				<= c_state_idle;

			ff_cur_dx				<= 16'd0;
			ff_cur_dy				<= 16'd0;
			ff_cur_src_x			<= 16'd0;
			ff_cur_src_y			<= 16'd0;
			ff_cur_dst_x			<= 16'd0;
			ff_cur_dst_y			<= 16'd0;
			ff_cur_src_address		<= 22'd0;
			ff_cur_dst_address		<= 22'd0;

			ff_src_color			<= 16'd0;
			ff_dst_color			<= 16'd0;
			ff_src_x_offset			<= 16'd0;
			ff_src_y_offset			<= 16'd0;
			ff_src_x_error			<= 16'd0;
			ff_src_y_error			<= 16'd0;
			ff_src_row_address		<= 22'd0;

			ff_flush_pending		<= 1'b0;

			ff_clipped_swidth		<= 16'd0;
			ff_clipped_sheight		<= 16'd0;
			ff_clipped_dwidth		<= 16'd0;
			ff_clipped_dheight		<= 16'd0;
			ff_clipped_sx			<= 16'd0;
			ff_clipped_sy			<= 16'd0;
			ff_clipped_dx			<= 16'd0;
			ff_clipped_dy			<= 16'd0;
		end
		else begin
			if( sdram_init_busy ) begin
				ff_state			<= c_state_idle;
				ff_flush_pending	<= 1'b0;
			end
			else begin
				if( bus_cs && bus_valid && bus_write && bus_address == 5'h09 && bus_wdata[0] && !ff_busy && !ff_flush_pending ) begin
					ff_clipped_sx <= f_clip_start( reg_sx, 16'd800 );
					ff_clipped_sy <= f_clip_start( reg_sy, 16'd480 );
					ff_clipped_dx <= f_clip_start( reg_dx, 16'd800 );
					ff_clipped_dy <= f_clip_start( reg_dy, 16'd480 );

					ff_clipped_swidth <= f_clip_size( reg_sx, reg_swidth, 16'd800 );
					ff_clipped_sheight <= f_clip_size( reg_sy, reg_sheight, 16'd480 );
					ff_clipped_dwidth <= f_clip_size( reg_dx, reg_dwidth, 16'd800 );
					ff_clipped_dheight <= f_clip_size( reg_dy, reg_dheight, 16'd480 );

					ff_cur_dx <= 16'd0;
					ff_cur_dy <= 16'd0;
					ff_src_x_offset <= 16'd0;
					ff_src_y_offset <= 16'd0;
					ff_src_x_error <= 16'd0;
					ff_src_y_error <= 16'd0;
					ff_src_row_address <= reg_vram_address + f_clip_start( reg_sx, 16'd800 ) + ({ 6'd0, f_clip_start( reg_sy, 16'd480 ) } << 10);
					ff_state <= c_state_issue_src_read;
				end

				case( ff_state )
				c_state_idle: begin
					// do nothing
				end

				c_state_issue_src_read: begin
					if( ff_clipped_swidth == 16'd0 || ff_clipped_sheight == 16'd0 || ff_clipped_dwidth == 16'd0 || ff_clipped_dheight == 16'd0 ) begin
						ff_flush_pending <= 1'b1;
						ff_state <= c_state_issue_flush;
					end
					else begin
						ff_cur_src_x <= ff_clipped_sx + ff_src_x_offset;
						ff_cur_src_y <= ff_clipped_sy + ff_src_y_offset;
						ff_cur_dst_x <= ff_clipped_dx + ff_cur_dx;
						ff_cur_dst_y <= ff_clipped_dy + ff_cur_dy;
						ff_cur_src_address <= ff_src_row_address + ff_src_x_offset;
						ff_cur_dst_address <= ff_exec_base_address + (ff_clipped_dx + ff_cur_dx) + ({ 6'd0, (ff_clipped_dy + ff_cur_dy) } << 10);
					end
				end

				c_state_wait_src_read: begin
					if( sdram_rdata_valid ) begin
						ff_src_color <= sdram_rdata;
						if( ff_exec_rop == c_rop_put ) begin
							ff_dst_color <= 16'd0;
							ff_state <= c_state_issue_write;
						end
						else begin
							ff_state <= c_state_issue_dst_read;
						end
					end
				end

				c_state_issue_dst_read: begin
					if( sdram_ready ) begin
						ff_state <= c_state_wait_dst_read;
					end
				end

				c_state_wait_dst_read: begin
					if( sdram_rdata_valid ) begin
						ff_dst_color <= sdram_rdata;
						ff_state <= c_state_issue_write;
					end
				end

				c_state_issue_write: begin
					if( sdram_ready ) begin
						if( (ff_cur_dx + 16'd1) < ff_clipped_dwidth ) begin
							if( (ff_src_x_error + ff_clipped_swidth) >= ff_clipped_dwidth ) begin
								ff_src_x_error <= (ff_src_x_error + ff_clipped_swidth) - ff_clipped_dwidth;
								ff_src_x_offset <= ff_src_x_offset + 16'd1;
							end
							else begin
								ff_src_x_error <= ff_src_x_error + ff_clipped_swidth;
							end
							ff_cur_dx <= ff_cur_dx + 16'd1;
							ff_state <= c_state_issue_src_read;
						end
						else if( (ff_cur_dy + 16'd1) < ff_clipped_dheight ) begin
							ff_cur_dx <= 16'd0;
							ff_cur_dy <= ff_cur_dy + 16'd1;
							ff_src_x_offset <= 16'd0;
							ff_src_x_error <= 16'd0;
							if( (ff_src_y_error + ff_clipped_sheight) >= ff_clipped_dheight ) begin
								ff_src_y_error <= (ff_src_y_error + ff_clipped_sheight) - ff_clipped_dheight;
								ff_src_y_offset <= ff_src_y_offset + 16'd1;
								ff_src_row_address <= ff_src_row_address + 22'd1024;
							end
							else begin
								ff_src_y_error <= ff_src_y_error + ff_clipped_sheight;
							end
							ff_state <= c_state_issue_src_read;
						end
						else begin
							ff_flush_pending <= 1'b1;
							ff_state <= c_state_issue_flush;
						end
					end
				end

				c_state_issue_flush: begin
					if( ff_flush_pending ) begin
						if( sdram_ready ) begin
							ff_flush_pending <= 1'b0;
							ff_state <= c_state_idle;
						end
					end
					else begin
						ff_state <= c_state_idle;
					end
				end

				default: begin
					ff_state <= c_state_idle;
				end
				endcase
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			reg_sx					<= 16'd0;
			reg_sy					<= 16'd0;
			reg_swidth				<= 16'd0;
			reg_sheight				<= 16'd0;
			reg_dx					<= 16'd0;
			reg_dy					<= 16'd0;
			reg_dwidth				<= 16'd0;
			reg_dheight				<= 16'd0;
			reg_rop					<= c_rop_put;
			reg_vram_address		<= 22'd0;

			ff_bus_rdata			<= 16'd0;
			ff_bus_rdata_valid		<= 1'b0;
		end
		else begin
			ff_bus_rdata_valid <= 1'b0;

			if( bus_cs && bus_valid && bus_write ) begin
				case( bus_address )
				5'h00: reg_sx <= bus_wdata;
				5'h01: reg_sy <= bus_wdata;
				5'h02: reg_swidth <= bus_wdata;
				5'h03: reg_sheight <= bus_wdata;
				5'h04: reg_dx <= bus_wdata;
				5'h05: reg_dy <= bus_wdata;
				5'h06: reg_dwidth <= bus_wdata;
				5'h07: reg_dheight <= bus_wdata;
				5'h08: reg_rop <= bus_wdata;
				5'h0A: reg_vram_address[15:1] <= bus_wdata[15:1];
				5'h0B: reg_vram_address[22:16] <= bus_wdata[6:0];
				default: begin
					// do nothing
				end
				endcase
			end

			if( bus_cs && bus_valid && !bus_write ) begin
				case( bus_address )
				5'h00:		ff_bus_rdata <= reg_sx;
				5'h01:		ff_bus_rdata <= reg_sy;
				5'h02:		ff_bus_rdata <= reg_swidth;
				5'h03:		ff_bus_rdata <= reg_sheight;
				5'h04:		ff_bus_rdata <= reg_dx;
				5'h05:		ff_bus_rdata <= reg_dy;
				5'h06:		ff_bus_rdata <= reg_dwidth;
				5'h07:		ff_bus_rdata <= reg_dheight;
				5'h08:		ff_bus_rdata <= reg_rop;
				5'h09:		ff_bus_rdata <= { 15'd0, ff_busy };
				5'h0A:		ff_bus_rdata <= { reg_vram_address[15:1], 1'b0 };
				5'h0B:		ff_bus_rdata <= { 9'd0, reg_vram_address[22:16] };
				default:	ff_bus_rdata <= 16'd0;
				endcase
				ff_bus_rdata_valid <= 1'b1;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_busy <= 1'b0;
		end
		else if( sdram_init_busy ) begin
			ff_busy <= 1'b0;
		end
		else if( bus_cs && bus_valid && bus_write && bus_address == 5'h09 && bus_wdata[0] && !ff_busy && !ff_flush_pending ) begin
			ff_busy <= 1'b1;
		end
		else if( ff_state == c_state_issue_src_read && (ff_clipped_swidth == 16'd0 || ff_clipped_sheight == 16'd0 || ff_clipped_dwidth == 16'd0 || ff_clipped_dheight == 16'd0) ) begin
			ff_busy <= 1'b0;
		end
		else if( ff_state == c_state_issue_write && sdram_ready && !((ff_cur_dx + 16'd1) < ff_clipped_dwidth) && !((ff_cur_dy + 16'd1) < ff_clipped_dheight) ) begin
			ff_busy <= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_exec_sx				<= 16'd0;
			ff_exec_sy				<= 16'd0;
			ff_exec_swidth			<= 16'd0;
			ff_exec_sheight			<= 16'd0;
			ff_exec_dx				<= 16'd0;
			ff_exec_dy				<= 16'd0;
			ff_exec_dwidth			<= 16'd0;
			ff_exec_dheight			<= 16'd0;
			ff_exec_rop				<= c_rop_put;
			ff_exec_base_address	<= 22'd0;
		end
		else if( bus_cs && bus_valid && bus_write && bus_address == 5'h09 && bus_wdata[0] && !ff_busy && !ff_flush_pending ) begin
			ff_exec_sx				<= reg_sx;
			ff_exec_sy				<= reg_sy;
			ff_exec_swidth			<= reg_swidth;
			ff_exec_sheight			<= reg_sheight;
			ff_exec_dx				<= reg_dx;
			ff_exec_dy				<= reg_dy;
			ff_exec_dwidth			<= reg_dwidth;
			ff_exec_dheight			<= reg_dheight;
			ff_exec_rop				<= reg_rop;
			ff_exec_base_address	<= reg_vram_address;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_sdram_address		<= 22'd0;
			ff_sdram_write			<= 1'b0;
			ff_sdram_wdata			<= 16'd0;
			ff_sdram_valid			<= 1'b0;
			ff_sdram_flush			<= 1'b0;
		end
		else if( sdram_init_busy ) begin
			ff_sdram_valid			<= 1'b0;
			ff_sdram_flush			<= 1'b0;
		end
		else begin
			case( ff_state )
			c_state_issue_src_read: begin
				if( !ff_sdram_valid ) begin
					ff_sdram_address		<= ff_src_row_address + ff_src_x_offset;
					ff_sdram_write			<= 1'b0;
					ff_sdram_wdata			<= 16'd0;
					ff_sdram_flush			<= 1'b0;
					ff_sdram_valid			<= 1'b1;
				end
				else if( sdram_ready ) begin
					ff_sdram_valid			<= 1'b0;
				end
			end

			c_state_issue_dst_read: begin
				if( !ff_sdram_valid ) begin
					ff_sdram_address		<= ff_cur_dst_address;
					ff_sdram_write			<= 1'b0;
					ff_sdram_wdata			<= 16'd0;
					ff_sdram_flush			<= 1'b0;
					ff_sdram_valid			<= 1'b1;
				end
				else if( sdram_ready ) begin
					ff_sdram_valid			<= 1'b0;
				end
			end

			c_state_issue_write: begin
				if( !ff_sdram_valid ) begin
					ff_sdram_address		<= ff_cur_dst_address;
					ff_sdram_write			<= 1'b1;
					ff_sdram_wdata			<= f_apply_rop( ff_exec_rop, ff_src_color, ff_dst_color );
					ff_sdram_flush			<= 1'b0;
					ff_sdram_valid			<= 1'b1;
				end
				else if( sdram_ready ) begin
					ff_sdram_valid			<= 1'b0;
				end
			end

			c_state_issue_flush: begin
				if( ff_flush_pending ) begin
					if( !ff_sdram_valid ) begin
						ff_sdram_address		<= 22'd0;
						ff_sdram_write			<= 1'b0;
						ff_sdram_wdata			<= 16'd0;
						ff_sdram_flush			<= 1'b1;
						ff_sdram_valid			<= 1'b1;
					end
					else if( sdram_ready ) begin
						ff_sdram_valid			<= 1'b0;
						ff_sdram_flush			<= 1'b0;
					end
				end
			end

			default: begin
				// hold previous SDRAM request values
			end
			endcase
		end
	end

	assign bus_ready			= ~sdram_init_busy;
	assign bus_rdata			= ff_bus_rdata;
	assign bus_rdata_valid		= ff_bus_rdata_valid;
	assign sdram_address		= ff_sdram_address;
	assign sdram_write			= ff_sdram_write;
	assign sdram_wdata			= ff_sdram_wdata;
	assign sdram_valid			= ff_sdram_valid;
	assign sdram_flush			= ff_sdram_flush;
endmodule
