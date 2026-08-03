// -----------------------------------------------------------------------------
//	Test of display_timing_generator.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
// --------------------------------------------------------------------

module tb ();
	// 132 MHz clock: period = 1,000,000 ps / 132 = 7575.7... ps
	//   half period = 3788 ps  (actual freq ≈ 131.996 MHz)
	localparam		CLK_HALF_PS		= 3788;

	reg				clk;
	reg				reset;

	wire			lcd_ck;
	wire			lcd_hs;
	wire			lcd_vs;
	wire			lcd_de;
	wire			frame_sync;
	wire			frame_end;
	wire	[4:0]	lcd_r;
	wire	[5:0]	lcd_g;
	wire	[4:0]	lcd_b;

	reg				p_valid;
	wire			p_ready;
	reg		[15:0]	p_data;

	// -----------------------------------------------------------------------
	// DUT
	// -----------------------------------------------------------------------
	display_timing_generator u_dut (
		.clk		( clk		),
		.reset		( reset		),
		.lcd_ck		( lcd_ck	),
		.lcd_hs		( lcd_hs	),
		.lcd_vs		( lcd_vs	),
		.lcd_de		( lcd_de	),
		.frame_sync	( frame_sync	),
		.frame_end	( frame_end	),
		.lcd_r		( lcd_r		),
		.lcd_g		( lcd_g		),
		.lcd_b		( lcd_b		),
		.p_valid	( p_valid	),
		.p_ready	( p_ready	),
		.p_data		( p_data	)
	);

	// -----------------------------------------------------------------------
	// 132 MHz clock generation
	// -----------------------------------------------------------------------
	initial		clk		= 1'b0;
	always		#(CLK_HALF_PS) clk = ~clk;

	// -----------------------------------------------------------------------
	// Pixel data supply
	//   p_data is updated on each rising edge of lcd_ck during active area.
	//   This ensures the next pixel value is ready before the next low phase
	//   of lcd_ck (= next p_ready assertion).
	// -----------------------------------------------------------------------
	always @( posedge lcd_ck or posedge reset ) begin
		if( reset ) begin
			p_data <= 16'h0000;
		end
		else if( lcd_de ) begin
			p_data <= p_data + 16'd1;
		end
	end

	// -----------------------------------------------------------------------
	// Stimulus
	// -----------------------------------------------------------------------
	initial begin
		reset	= 1'b1;
		p_valid	= 1'b0;

		// Hold reset for 20 clocks
		repeat( 20 ) @( posedge clk );
		@( negedge clk );
		reset	= 1'b0;
		p_valid	= 1'b1;

		// --- Stall test ---
		// Wait until well inside the first active line then withhold p_valid
		// for 10 clocks to verify the whole timing machine stalls.
		repeat( 3000 ) @( posedge clk );
		p_valid = 1'b0;
		repeat( 10 ) @( posedge clk );
		p_valid = 1'b1;

		// Simulation ends via run.do
	end

endmodule
