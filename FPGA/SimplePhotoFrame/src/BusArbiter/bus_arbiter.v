//
// bus_arbiter.v
//   Bus Arbiter
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

module bus_arbiter (
	input				reset,
	input				clk,					//	System Clock
	//	Bus0 Interface from Controller (Access unit is 16bits)
	input	[22:1]		sdram0_address,
	input				sdram0_write,
	input	[15:0]		sdram0_wdata,
	input				sdram0_flush,
	input				sdram0_valid,
	output				sdram0_ready,
	output	[15:0]		sdram0_rdata,
	output				sdram0_rdata_valid,
	//	Bus1 Interface from Controller (Access unit is 16bits)
	input	[22:1]		sdram1_address,
	input				sdram1_write,
	input	[15:0]		sdram1_wdata,
	input				sdram1_flush,
	input				sdram1_valid,
	output				sdram1_ready,
	output	[15:0]		sdram1_rdata,
	output				sdram1_rdata_valid,
	//	Bus2 Interface from Controller (Access unit is 16bits)
	input	[22:1]		sdram2_address,
	input				sdram2_write,
	input	[15:0]		sdram2_wdata,
	input				sdram2_flush,
	input				sdram2_valid,
	output				sdram2_ready,
	output	[15:0]		sdram2_rdata,
	output				sdram2_rdata_valid,
	//	Bus3 Interface from Controller (Access unit is 16bits)
	input	[22:1]		sdram3_address,
	input				sdram3_write,
	input	[15:0]		sdram3_wdata,
	input				sdram3_flush,
	input				sdram3_valid,
	output				sdram3_ready,
	output	[15:0]		sdram3_rdata,
	output				sdram3_rdata_valid,
	//	Bus Interface to SDRAM (Access unit is 32bits/8words)
	output	[22:1]		sdram_address,
	output				sdram_write,
	output	[15:0]		sdram_wdata,
	output				sdram_flush,
	output				sdram_valid,
	input				sdram_ready,
	input	[15:0]		sdram_rdata,
	input				sdram_rdata_valid
);
	reg		[1:0]		ff_priority;
	reg		[1:0]		ff_read_bus;
	reg					ff_read_stall;
	reg					ff_ready;
	reg					ff_pending_valid;
	reg	[22:1]		ff_pending_address;
	reg	[15:0]		ff_pending_wdata;
	reg					ff_pending_write;
	reg					ff_pending_flush;
	wire				w_active;
	wire	[3:0]		w_valid;
	wire	[3:0]		w_priority_valid;
	wire	[1:0]		w_selected_valid;
	wire	[1:0]		w_selected_bus;
	wire	[22:1]		w_selected_bus_address;
	wire	[15:0]		w_selected_bus_wdata;
	wire				w_selected_bus_write;
	wire				w_selected_bus_flush;
	wire				w_selected_bus_read;
	wire	[22:1]		w_request_address;
	wire	[15:0]		w_request_wdata;
	wire				w_request_write;
	wire				w_request_flush;
	wire				w_request_valid;

	function [3:0] func_rotate_priority(
		input [3:0]		valid,
		input [1:0]		priority
	);
		case( priority )
			2'd0:		func_rotate_priority =   valid;
			2'd1:		func_rotate_priority = { valid[  0], valid[3:1] };
			2'd2:		func_rotate_priority = { valid[1:0], valid[3:2] };
			default:	func_rotate_priority = { valid[2:0], valid[3  ] };
		endcase
	endfunction

	function [1:0] func_select_valid(
		input [3:0]		valid
	);
		casex( valid )
			4'bxxx1:	func_select_valid = 2'd0;
			4'bxx10:	func_select_valid = 2'd1;
			4'bx100:	func_select_valid = 2'd2;
			default:	func_select_valid = 2'd3;
		endcase
	endfunction

	function [22:1] func_select_address(
		input [1:0]		bus,
		input [22:1]	sdram0_address,
		input [22:1]	sdram1_address,
		input [22:1]	sdram2_address,
		input [22:1]	sdram3_address
	);
		case( bus )
			2'd0:		func_select_address = sdram0_address;
			2'd1:		func_select_address = sdram1_address;
			2'd2:		func_select_address = sdram2_address;
			default:	func_select_address = sdram3_address;
		endcase
	endfunction

	function [15:0] func_select_wdata(
		input [1:0]		bus,
		input [15:0]	sdram0_wdata,
		input [15:0]	sdram1_wdata,
		input [15:0]	sdram2_wdata,
		input [15:0]	sdram3_wdata
	);
		case( bus )
			2'd0:		func_select_wdata = sdram0_wdata;
			2'd1:		func_select_wdata = sdram1_wdata;
			2'd2:		func_select_wdata = sdram2_wdata;
			default:	func_select_wdata = sdram3_wdata;
		endcase
	endfunction

	function func_select_1bit(
		input [1:0]		bus,
		input			sdram0_sig,
		input			sdram1_sig,
		input			sdram2_sig,
		input			sdram3_sig
	);
		case( bus )
			2'd0:		func_select_1bit = sdram0_sig;
			2'd1:		func_select_1bit = sdram1_sig;
			2'd2:		func_select_1bit = sdram2_sig;
			default:	func_select_1bit = sdram3_sig;
		endcase
	endfunction

	assign w_active					= (sdram0_valid | sdram1_valid | sdram2_valid | sdram3_valid) & ff_ready;
	assign w_valid					= { sdram3_valid, sdram2_valid, sdram1_valid, sdram0_valid };
	assign w_priority_valid			= func_rotate_priority( w_valid, ff_priority );
	assign w_selected_valid 		= func_select_valid( w_priority_valid );
	assign w_selected_bus			= w_selected_valid + ff_priority;

	assign w_selected_bus_address	= func_select_address( w_selected_bus, sdram0_address, sdram1_address, sdram2_address, sdram3_address );
	assign w_selected_bus_wdata		= func_select_wdata( w_selected_bus, sdram0_wdata, sdram1_wdata, sdram2_wdata, sdram3_wdata );
	assign w_selected_bus_write		= func_select_1bit( w_selected_bus, sdram0_write, sdram1_write, sdram2_write, sdram3_write );
	assign w_selected_bus_flush		= func_select_1bit( w_selected_bus, sdram0_flush, sdram1_flush, sdram2_flush, sdram3_flush );
	assign w_selected_bus_read		= !w_selected_bus_write && !w_selected_bus_flush;

	assign w_request_address		= ff_pending_valid ? ff_pending_address : w_selected_bus_address;
	assign w_request_wdata			= ff_pending_valid ? ff_pending_wdata : w_selected_bus_wdata;
	assign w_request_write			= ff_pending_valid ? ff_pending_write : w_selected_bus_write;
	assign w_request_flush			= ff_pending_valid ? ff_pending_flush : w_selected_bus_flush;
	assign w_request_valid			= ff_pending_valid | w_active;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_priority		<= 2'd0;
		end
		else if( w_active ) begin
			ff_priority		<= w_selected_bus + 2'd1;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_pending_valid	<= 1'b0;
		end
		else if( w_active && !sdram_ready ) begin
			ff_pending_valid	<= 1'b1;
		end
		else if( ff_pending_valid && sdram_ready ) begin
			ff_pending_valid	<= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_pending_address	<= 22'd0;
			ff_pending_wdata	<= 16'd0;
			ff_pending_write	<= 1'b0;
			ff_pending_flush	<= 1'b0;
		end
		else if( w_active && !sdram_ready ) begin
			ff_pending_address	<= w_selected_bus_address;
			ff_pending_wdata	<= w_selected_bus_wdata;
			ff_pending_write	<= w_selected_bus_write;
			ff_pending_flush	<= w_selected_bus_flush;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_ready		<= 1'b0;
			ff_read_bus		<= 2'd0;
			ff_read_stall	<= 1'b0;
		end
		else if( !ff_ready ) begin
			if( sdram_ready && !ff_read_stall ) begin
				//	readによる待機時間ではなく、かつ後段から busy が来ていない場合は次のサイクルで ready にする
				ff_ready		<= 1'b1;
			end
			else if( sdram_rdata_valid ) begin
				//	sdram_rdata_valid が来たら read による待機時間を終える
				ff_ready		<= sdram_ready;
				ff_read_stall	<= 1'b0;
			end
		end
		else if( w_active ) begin
			if( !sdram_ready || w_selected_bus_read ) begin
				//	後段から busy が来ているか、あるいは read要求だった場合は次のサイクルで busy にする
				ff_ready		<= 1'b0;
				ff_read_stall	<= w_selected_bus_read;
				if( w_selected_bus_read ) begin
					ff_read_bus	<= w_selected_bus;
				end
			end
		end
	end

	assign sdram0_rdata			= (ff_read_bus == 2'd0) ? sdram_rdata : 16'd0;
	assign sdram1_rdata			= (ff_read_bus == 2'd1) ? sdram_rdata : 16'd0;
	assign sdram2_rdata			= (ff_read_bus == 2'd2) ? sdram_rdata : 16'd0;
	assign sdram3_rdata			= (ff_read_bus == 2'd3) ? sdram_rdata : 16'd0;

	assign sdram0_rdata_valid	= (ff_read_bus == 2'd0) ? sdram_rdata_valid : 1'b0;
	assign sdram1_rdata_valid	= (ff_read_bus == 2'd1) ? sdram_rdata_valid : 1'b0;
	assign sdram2_rdata_valid	= (ff_read_bus == 2'd2) ? sdram_rdata_valid : 1'b0;
	assign sdram3_rdata_valid	= (ff_read_bus == 2'd3) ? sdram_rdata_valid : 1'b0;

	assign sdram0_ready			= (w_selected_bus == 2'd0) ? ff_ready : 1'b0;
	assign sdram1_ready			= (w_selected_bus == 2'd1) ? ff_ready : 1'b0;
	assign sdram2_ready			= (w_selected_bus == 2'd2) ? ff_ready : 1'b0;
	assign sdram3_ready			= (w_selected_bus == 2'd3) ? ff_ready : 1'b0;

	assign sdram_address		= w_request_address;
	assign sdram_write			= w_request_write;
	assign sdram_wdata			= w_request_wdata;
	assign sdram_flush			= w_request_flush;
	assign sdram_valid			= w_request_valid;
endmodule
