//
// vram_accessor.v
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

module vram_accessor (
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
	reg		[22:1]	reg_vram_address;
	reg		[15:0]	reg_vram_data;

	reg		[15:0]	ff_bus_rdata;
	reg				ff_bus_rdata_valid;

	reg		[22:1]	ff_sdram_address;
	reg				ff_sdram_write;
	reg		[15:0]	ff_sdram_wdata;
	reg				ff_sdram_valid;
	reg				ff_sdram_flush;
	reg				ff_wait_rdata;
	wire			w_bus_ready;

	assign w_bus_ready = ~sdram_init_busy && ~(ff_sdram_valid || ff_wait_rdata);

	always @( posedge clk ) begin
		if( reset ) begin
			reg_vram_address		<= 22'd0;
			reg_vram_data			<= 16'd0;
			ff_bus_rdata			<= 16'd0;
			ff_bus_rdata_valid		<= 1'b0;
			ff_sdram_address		<= 22'd0;
			ff_sdram_write			<= 1'b0;
			ff_sdram_wdata			<= 16'd0;
			ff_sdram_valid			<= 1'b0;
			ff_sdram_flush			<= 1'b0;
			ff_wait_rdata			<= 1'b0;
		end
		else begin
			ff_bus_rdata_valid 		<= 1'b0;

			if( sdram_init_busy ) begin
				ff_sdram_valid			<= 1'b0;
				ff_sdram_flush			<= 1'b0;
				ff_wait_rdata			<= 1'b0;
			end
			else begin
				if( ff_sdram_valid && sdram_ready ) begin
					ff_sdram_valid			<= 1'b0;
					if( ff_sdram_flush ) begin
						ff_sdram_flush			<= 1'b0;
						ff_wait_rdata			<= 1'b0;
					end
					else begin
						ff_wait_rdata			<= ~ff_sdram_write;
						reg_vram_address		<= reg_vram_address + 22'd1;
					end
				end

				if( ff_wait_rdata && sdram_rdata_valid ) begin
					ff_wait_rdata			<= 1'b0;
					reg_vram_data			<= sdram_rdata;
					ff_bus_rdata			<= sdram_rdata;
					ff_bus_rdata_valid		<= 1'b1;
				end

				if( bus_cs && bus_valid && w_bus_ready ) begin
					if( bus_write ) begin
						case( bus_address )
						5'h00: begin
							reg_vram_address[16:1] <= bus_wdata[15:0];
						end
						5'h01: begin
							reg_vram_address[22:17] <= bus_wdata[5:0];
						end
						5'h02: begin
							reg_vram_data <= bus_wdata;
							ff_sdram_address		<= reg_vram_address;
							ff_sdram_write			<= 1'b1;
							ff_sdram_wdata			<= bus_wdata;
							ff_sdram_flush			<= 1'b0;
							ff_sdram_valid			<= 1'b1;
						end
						5'h03: begin
							if( bus_wdata[0] ) begin
								ff_sdram_address	<= reg_vram_address;
								ff_sdram_write		<= 1'b0;
								ff_sdram_wdata		<= 16'd0;
								ff_sdram_flush		<= 1'b1;
								ff_sdram_valid		<= 1'b1;
							end
						end
						default: begin
							// do nothing
						end
						endcase
					end
					else begin
						case( bus_address )
						5'h00: begin
							ff_bus_rdata		<= reg_vram_address[16:1];
							ff_bus_rdata_valid	<= 1'b1;
						end
						5'h01: begin
							ff_bus_rdata		<= { 10'd0, reg_vram_address[22:17] };
							ff_bus_rdata_valid	<= 1'b1;
						end
						5'h02: begin
							ff_sdram_address		<= reg_vram_address;
							ff_sdram_write			<= 1'b0;
							ff_sdram_wdata			<= 16'd0;
							ff_sdram_flush			<= 1'b0;
							ff_sdram_valid			<= 1'b1;
						end
						default: begin
							ff_bus_rdata		<= 16'd0;
							ff_bus_rdata_valid	<= 1'b1;
						end
						endcase
					end
				end
			end
		end
	end

	assign bus_ready			= w_bus_ready;
	assign bus_rdata			= ff_bus_rdata;
	assign bus_rdata_valid		= ff_bus_rdata_valid;
	assign sdram_address		= ff_sdram_address;
	assign sdram_write			= ff_sdram_write;
	assign sdram_wdata			= ff_sdram_wdata;
	assign sdram_valid			= ff_sdram_valid;
	assign sdram_flush			= ff_sdram_flush;


endmodule
