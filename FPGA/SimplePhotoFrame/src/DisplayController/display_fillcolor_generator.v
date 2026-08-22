//
// display_fillcolor_generator.v
//
// Copyright (C) 2026 Takayuki Hara
//

module display_fillcolor_generator (
	input			clk,
	input			reset,
	input			clear,
	input			display_on,
	input	[15:0]	fill_color,
	input	[22:5]	in_sdram_address,
	input			in_sdram_address_valid,
	output			in_sdram_address_ready,
	output	[22:5]	sdram_address,
	output			sdram_address_valid,
	input			sdram_address_ready,
	input	[31:0]	sdram_rdata,
	input			sdram_rdata_valid,
	output	[31:0]	out_data,
	output			out_valid,
	input			out_ready
);
	localparam [2:0] BURST_WORDS = 3'd8;

	reg			ff_busy;
	reg			ff_mode_on;
	reg	[2:0]	ff_remain;
	reg			ff_req_valid;
	reg	[22:5]	ff_req_address;

	wire w_can_accept		= ~ff_busy && ~ff_req_valid && out_ready;
	wire w_accept_request	= in_sdram_address_valid && w_can_accept;
	wire w_issue_request	= ff_req_valid && sdram_address_ready;
	wire w_emit_on			= ff_busy && ff_mode_on && sdram_rdata_valid;
	wire w_emit_off			= ff_busy && ~ff_mode_on && out_ready;
	wire w_emit				= w_emit_on || w_emit_off;

	// busy はリクエスト受理不可 / バースト転送中を示す
	always @( posedge clk ) begin
		if( reset || clear ) begin
			ff_busy	<= 1'b0;
		end
		else if( !ff_busy ) begin
			if( w_issue_request || ( w_accept_request && !display_on ) ) begin
				ff_busy	<= 1'b1;
			end
		end
		else if( w_emit ) begin
			if( ff_remain == 3'd1 ) begin
				ff_busy	<= 1'b0;
			end
		end
	end

	// mode_on / remain はバースト種別と残ワード数を管理する
	always @( posedge clk)  begin
		if( reset || clear ) begin
			ff_mode_on <= 1'b0;
			ff_remain	<= 3'd0;
		end
		else if( !ff_busy ) begin
			if( w_accept_request ) begin
				ff_mode_on <= display_on;
				ff_remain	<= BURST_WORDS;
			end
		end
		else if( w_emit ) begin
			if( ff_remain != 3'd1 ) begin
				ff_remain	<= ff_remain - 3'd1;
			end
		end
	end

	// req_valid / req_address は SDRAM への読み出し要求を管理する
	always @( posedge clk ) begin
		if( reset || clear ) begin
			ff_req_valid	<= 1'b0;
			ff_req_address	<= 18'd0;
		end
		else if( w_issue_request ) begin
			ff_req_valid	<= 1'b0;
		end
		else if( w_accept_request && display_on ) begin
			ff_req_valid	<= 1'b1;
			ff_req_address	<= in_sdram_address;
		end
	end

	assign in_sdram_address_ready	= w_can_accept;
	assign sdram_address			= ff_req_address;
	assign sdram_address_valid		= ff_req_valid;
	assign out_valid				= ff_busy && (ff_mode_on ? sdram_rdata_valid : 1'b1);
	assign out_data					= ff_mode_on ? sdram_rdata : {fill_color, fill_color};
endmodule
