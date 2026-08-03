//
// display_controller.v
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

module display_controller (
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
	// LCD interface
	output			lcd_ck,
	output			lcd_hs,
	output			lcd_vs,
	output			lcd_de,
	output	[4:0]	lcd_r,
	output	[5:0]	lcd_g,
	output	[4:0]	lcd_b,
	output			lcd_bl,
	// SDRAM interface
	output	[22:5]	sdram_address,
	output			sdram_address_valid,
	input			sdram_address_ready,
	input	[31:0]	sdram_rdata,
	input			sdram_rdata_valid
);
	wire			fifo_full;
	wire	[31:0]	fifo_wdata;
	wire			fifo_valid;
	wire			display_on;
	wire			p_valid;
	wire			p_ready;
	wire	[15:0]	p_data;

	display_address_generator display_address_generator (
		.clk					( clk					),
		.reset					( reset					),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.fifo_full				( fifo_full				),
		.fifo_wdata				( fifo_wdata			),
		.fifo_valid				( fifo_valid			),
		.sdram_address			( sdram_address			),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
	);

	display_preload_buffer display_preload_buffer (
		.clk					( clk					),
		.reset					( reset					),
		.in_data				( fifo_wdata			),
		.in_valid				( fifo_valid			),
		.in_ready				( 						),
		.in_nearly_full			( fifo_full				),
		.out_data				( p_data				),
		.out_valid				( p_valid				),
		.out_ready				( p_ready				)
	);

	display_timing_generator display_timing_generator (
		.clk					( clk					),
		.reset					( reset					),
		.p_data					( p_data				),
		.p_valid				( p_valid				),
		.p_ready				( p_ready				),
		.lcd_ck					( lcd_ck				),
		.lcd_hs					( lcd_hs				),
		.lcd_vs					( lcd_vs				),
		.lcd_de					( lcd_de				),
		.lcd_r					( lcd_r					),
		.lcd_g					( lcd_g					),
		.lcd_b					( lcd_b					),
		.lcd_bl					( lcd_bl				)
	);
endmodule
