//
// display_address_generator.v
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

module display_address_generator (
	input			clk,
	input			reset,
	input			sdram_init_busy,
	input			frame_end,
	//	Register interface
	input			bus_cs,
	input	[4:0]	bus_address,
	input			bus_valid,
	output			bus_ready,
	input			bus_write,
	input	[15:0]	bus_wdata,
	output	[15:0]	bus_rdata,
	output			bus_rdata_valid,
	output			display_on,
	output	[15:0]	fill_color,
	//	SDRAM address
	output	[22:5]	sdram_address,
	output			sdram_address_valid,
	input			sdram_address_ready
);
	localparam		IMG_WIDTH	= 800 / 16;		//	表示対象ピクセル数/バーストリードワード数
	localparam		IMG_HEIGHT	= 480;
	localparam		[$clog2(IMG_WIDTH)-1:0]		H_COUNTER_MAX = IMG_WIDTH - 1;
	localparam		[$clog2(IMG_WIDTH)-1:0]		H_COUNTER_ONE = {{($clog2(IMG_WIDTH)-1){1'b0}}, 1'b1};
	localparam		[$clog2(IMG_HEIGHT)-1:0]	V_COUNTER_MAX = IMG_HEIGHT - 1;
	localparam		[$clog2(IMG_HEIGHT)-1:0]	V_COUNTER_ONE = {{($clog2(IMG_HEIGHT)-1){1'b0}}, 1'b1};
	reg				[$clog2(IMG_WIDTH)-1:0]		ff_h_counter;
	reg				[$clog2(IMG_HEIGHT)-1:0]	ff_v_counter;

	reg				ff_ready;
	reg				ff_rdata_valid;
	reg		[22:5]	reg_base_address;
	reg				reg_display_on;
	reg		[15:0]	reg_fill_color;
	reg		[22:5]	ff_base_address;
	reg				ff_base_address_valid;
	reg				ff_display_on;
	reg				ff_wait_frame_sync;
	reg				reg_frame_end_wait;
	wire			w_issue_enable;
	wire			w_valid;
	wire	[22:5]	w_sdram_address;

	assign w_issue_enable		= ~ff_wait_frame_sync;
	assign w_issue_accept		= w_issue_enable && sdram_address_ready;
	assign w_valid				= w_issue_enable;
	assign w_sdram_address		= ff_base_address + { ff_v_counter, 6'd0 } + ff_h_counter;

	// ---------------------------------------------------------
	//	Access ready/busy logic
	// ---------------------------------------------------------
	always @(posedge clk) begin
		if( reset ) begin
			ff_ready <= 1'b0;
			ff_rdata_valid <= 1'b0;
		end
		else if( sdram_init_busy ) begin
			ff_ready <= 1'b0;
			ff_rdata_valid <= 1'b0;
		end 
		else if( !bus_cs ) begin
			//	バスアクセスがない場合は、常に ready を返す
			ff_ready <= 1'b1;
			ff_rdata_valid <= 1'b0;
		end
		else if( bus_valid && bus_write && bus_cs && bus_address <= 5'd5 ) begin
			ff_ready <= 1'b1;
			ff_rdata_valid <= 1'b0;
		end 
		else if( bus_valid && !bus_write && bus_cs && (bus_address == 5'd4 || bus_address == 5'd5) ) begin
			ff_ready <= 1'b0;
			ff_rdata_valid <= 1'b1;
		end 
		else begin
			ff_ready <= 1'b1;
			ff_rdata_valid <= 1'b0;
		end
	end

	// ---------------------------------------------------------
	//	Register interface
	//	Register# | Description
	//	----------+---------------------------------------------
	//		0     | bit0-7:レジスタアドレスL [20:5]
	//		1     | bit0-1:レジスタアドレスH [22:21], bit2-15: 未使用
	//		2     | bit0: 液晶表示 ON(1)/OFF(0:Default)
	//		3     | bit0: SDRAM初期化完了フラグ(読み取り専用)
	//		4     | bit0-7: display off 時の色
	//		5     | bit0: 1を書き込むとそのままリードバックできる。frame_end で 0 にクリアされる。
	//		6-7   | 未使用
	// ---------------------------------------------------------
	always @(posedge clk) begin
		if( reset ) begin
			reg_base_address <= 18'd0;
			reg_display_on <= 1'b0;
			reg_fill_color <= { 5'd31, 6'd63, 5'd31 };	// 白
		end
		else if( bus_cs && bus_valid && bus_ready && bus_write ) begin
			case( bus_address )
				5'd0: begin
					reg_base_address[16:5] <= bus_wdata[15:4];
				end
				5'd1: begin
					reg_base_address[22:17] <= bus_wdata[5:0];
				end
				5'd2: begin
					reg_display_on <= bus_wdata[0];
				end
				5'd4: begin
					reg_fill_color <= bus_wdata;
				end
				default: begin
					// それ以外のアドレスは無視
				end
			endcase
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			reg_frame_end_wait <= 1'b0;
		end
		else begin
			if( frame_end ) begin
				reg_frame_end_wait <= 1'b0;
			end
			else if( bus_cs && bus_valid && bus_ready && bus_write && bus_address == 5'd5 ) begin
				reg_frame_end_wait <= bus_wdata[0];
			end
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_base_address	<= 18'd0;
		end
		else if( bus_cs && bus_valid && bus_ready && bus_write && bus_address == 5'd1 ) begin
			// 必ず、下位→上位の順で更新するルール
			ff_base_address_valid	<= 1'b1;
		end
		else if( ff_base_address_valid && frame_end ) begin
			ff_base_address_valid	<= 1'b0;
			ff_base_address			<= reg_base_address;
		end
	end

	// ---------------------------------------------------------
	//	カウンター
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( reset ) begin
			ff_h_counter <= { $clog2(IMG_WIDTH){1'b0} };
		end
		else if( w_issue_accept ) begin
			if( ff_h_counter == H_COUNTER_MAX ) begin
				ff_h_counter <= { $clog2(IMG_WIDTH){1'b0} };
			end 
			else begin
				ff_h_counter <= ff_h_counter + H_COUNTER_ONE;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_v_counter <= { $clog2(IMG_HEIGHT){1'b0} };
		end
		else if( w_issue_accept ) begin
			if( ff_h_counter == H_COUNTER_MAX ) begin
				if( ff_v_counter == V_COUNTER_MAX ) begin
					ff_v_counter <= { $clog2(IMG_HEIGHT){1'b0} };
				end 
				else begin
					ff_v_counter <= ff_v_counter + V_COUNTER_ONE;
				end
			end 
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_wait_frame_sync <= 1'b0;
		end
		else if( frame_end ) begin
			ff_wait_frame_sync <= 1'b0;
		end
		else if( w_issue_accept && (ff_h_counter == H_COUNTER_MAX) && (ff_v_counter == V_COUNTER_MAX) ) begin
			ff_wait_frame_sync <= 1'b1;
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_display_on <= 1'b0;
		end
		else if( frame_end ) begin
			// display_on update is synchronized to timing-generator frame boundary
			ff_display_on <= reg_display_on;
		end
	end

	assign bus_ready			= ff_ready;
	assign bus_rdata			= ( bus_address == 5'd5 ) ? { 15'd0, reg_frame_end_wait } : { 15'd0, sdram_init_busy };
	assign bus_rdata_valid		= ff_rdata_valid;

	assign sdram_address		= w_sdram_address;
	assign sdram_address_valid	= w_valid;
	assign display_on			= ff_display_on;
	assign fill_color			= reg_fill_color;
endmodule
