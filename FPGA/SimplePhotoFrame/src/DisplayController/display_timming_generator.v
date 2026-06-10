//
// display_timming_generator.v
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

module display_timming_generator (
	input			clk,
	input			reset,
	// Pixel input (valid/ready handshake, RGB565 format)
	//   p_data[15:11] = R[4:0]
	//   p_data[10: 5] = G[5:0]  (G[0] is discarded; lcd_g[0] is fixed 0)
	//   p_data[ 4: 0] = B[4:0]
	input			p_valid,
	output			p_ready,
	input	[15:0]	p_data,
	// LCD interface
	output			lcd_ck,
	output			lcd_hs,
	output			lcd_vs,
	output			lcd_de,
	output	[4:0]	lcd_r,
	output	[5:0]	lcd_g,		// bit0 is fixed 0
	output	[4:0]	lcd_b,
	output			lcd_bl
);

	// -------------------------------------------------------------------------
	// Parameters
	// -------------------------------------------------------------------------
	// Horizontal (unit: pixel = 1 lcd_ck cycle = 4 clocks @ 132MHz)
	//   sync+BP:    0..45   (46 pixels total; sync=20px, remaining BP=26px, negative logic during 0..19)
	//   active :   46..845  (800 pixels)
	//   FP     :  846..1055 (210 pixels)  total 1056
	localparam [10:0] H_SYNC_END   = 11'd19;
	localparam [10:0] H_BP_END     = 11'd45;
	localparam [10:0] H_ACTIVE_END = 11'd845;
	localparam [10:0] H_TOTAL      = 11'd1055;

	// Vertical (unit: line)
	//   sync+BP:   0..22  (23 lines total; sync=10line, remaining BP=13line, negative logic during 0..9)
	//   active :  23..502 (480 lines)
	//   FP     : 503..520 (18 lines)  total 521
	localparam [9:0] V_SYNC_END   = 10'd9;
	localparam [9:0] V_BP_END     = 10'd22;
	localparam [9:0] V_ACTIVE_END = 10'd502;
	localparam [9:0] V_TOTAL      = 10'd520;

	// -------------------------------------------------------------------------
	// Register declarations
	// -------------------------------------------------------------------------
	reg			ff_lcd_ck;
	reg			ff_ck_phase;
	reg [10:0]	ff_h_counter;
	reg [9:0]	ff_v_counter;

	// -------------------------------------------------------------------------
	// Active video area / pixel handshake
	// -------------------------------------------------------------------------
	// w_de: high while counters are in the active video region
	wire w_de = ( ff_h_counter >  H_BP_END     ) && ( ff_h_counter <= H_ACTIVE_END ) &&
	            ( ff_v_counter >  V_BP_END      ) && ( ff_v_counter <= V_ACTIVE_END );

	// p_ready: asserted during the low phase of lcd_ck inside active area.
	//          The upstream module must hold p_data stable until the handshake.
	assign p_ready = ( !ff_lcd_ck && ff_ck_phase && w_de );

	// w_stall: hold the entire timing machine when pixel data is not available
	wire w_stall = p_ready && !p_valid;

	// -------------------------------------------------------------------------
	// lcd_ck: 4-divider of 132MHz → 33MHz  (stalls when pixel data is missing)
	// -------------------------------------------------------------------------

	always @( posedge clk or posedge reset ) begin
		if( reset ) begin
			ff_ck_phase <= 1'b0;
			ff_lcd_ck <= 1'b0;
		end
		else if( !w_stall ) begin
			ff_ck_phase <= ~ff_ck_phase;
			if( ff_ck_phase ) begin
				ff_lcd_ck <= ~ff_lcd_ck;
			end
		end
	end

	assign lcd_ck = ff_lcd_ck;

	// true on cycles where lcd_ck will rise (0 -> 1)
	wire w_lcd_ck_rise = ( !w_stall && ff_ck_phase && !ff_lcd_ck );

	// -------------------------------------------------------------------------
	// Horizontal counter (11bit)
	// Increments on every lcd_ck rising edge
	// -------------------------------------------------------------------------
	always @( posedge clk or posedge reset ) begin
		if( reset ) begin
			ff_h_counter <= 11'd0;
		end
		else if( w_lcd_ck_rise ) begin
			if( ff_h_counter == H_TOTAL ) begin
				ff_h_counter <= 11'd0;
			end
			else begin
				ff_h_counter <= ff_h_counter + 11'd1;
			end
		end
	end

	// -------------------------------------------------------------------------
	// Vertical counter (10bit)
	// Increments at the end of each horizontal line
	// -------------------------------------------------------------------------
	always @( posedge clk or posedge reset ) begin
		if( reset ) begin
			ff_v_counter <= 10'd0;
		end
		else if( w_lcd_ck_rise && ( ff_h_counter == H_TOTAL ) ) begin
			if( ff_v_counter == V_TOTAL ) begin
				ff_v_counter <= 10'd0;
			end
			else begin
				ff_v_counter <= ff_v_counter + 10'd1;
			end
		end
	end

	// -------------------------------------------------------------------------
	// Timing output signals
	// -------------------------------------------------------------------------
	// lcd_hs: negative logic (low = sync active)
	assign lcd_hs = ( ff_h_counter > H_SYNC_END );

	// lcd_vs: negative logic (low = sync active)
	assign lcd_vs = ( ff_v_counter > V_SYNC_END );

	// lcd_de: high during active video area
	assign lcd_de = w_de;

	// -------------------------------------------------------------------------
	// Pixel output
	// Pixel data is presented combinatorially from p_data during the active area.
	// The LCD samples lcd_r/g/b at the lcd_ck rising edge.  Since the stall
	// mechanism prevents lcd_ck from rising until p_valid is asserted, p_data
	// is guaranteed to be stable at the sampling edge.
	// -------------------------------------------------------------------------
	assign lcd_r = w_de ? p_data[15:11]        : 5'd0;
	assign lcd_g = w_de ? {p_data[10:6], 1'b0} : 6'd0;	// G[0] fixed 0
	assign lcd_b = w_de ? p_data[4:0]          : 5'd0;
	assign lcd_bl = 1'b1;
endmodule
