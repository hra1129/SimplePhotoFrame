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
	input	[22:1]		bus0_address,
	input				bus0_write,
	input	[15:0]		bus0_wdata,
	input				bus0_flash,
	input				bus0_valid,
	output				bus0_ready,
	output	[15:0]		bus0_rdata,
	output				bus0_rdata_valid,
	//	Bus1 Interface from Controller (Access unit is 16bits)
	input	[22:1]		bus1_address,
	input				bus1_write,
	input	[15:0]		bus1_wdata,
	input				bus1_flash,
	input				bus1_valid,
	output				bus1_ready,
	output	[15:0]		bus1_rdata,
	output				bus1_rdata_valid,
	//	Bus2 Interface from Controller (Access unit is 16bits)
	input	[22:1]		bus2_address,
	input				bus2_write,
	input	[15:0]		bus2_wdata,
	input				bus2_flash,
	input				bus2_valid,
	output				bus2_ready,
	output	[15:0]		bus2_rdata,
	output				bus2_rdata_valid,
	//	Bus3 Interface from Controller (Access unit is 16bits)
	input	[22:1]		bus3_address,
	input				bus3_write,
	input	[15:0]		bus3_wdata,
	input				bus3_flash,
	input				bus3_valid,
	output				bus3_ready,
	output	[15:0]		bus3_rdata,
	output				bus3_rdata_valid,
	//	Bus Interface to SDRAM (Access unit is 32bits/8words)
	output	[22:1]		bus_address,
	output				bus_write,
	output	[15:0]		bus_wdata,
	output				bus_flash,
	output				bus_valid,
	input				bus_ready,
	input	[15:0]		bus_rdata,
	input				bus_rdata_valid
);
	reg		[1:0]		ff_priority;
	reg		[1:0]		ff_read_bus;
	reg					ff_read_stall;
	reg					ff_ready;
	wire				w_active;
	wire	[3:0]		w_valid;
	wire	[3:0]		w_priority_valid;
	wire	[1:0]		w_selected_valid;
	wire	[1:0]		w_selected_bus;
	wire	[22:1]		w_selected_bus_address;
	wire	[15:0]		w_selected_bus_wdata;
	wire				w_selected_bus_write;
	wire				w_selected_bus_flash;

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
		input [22:1]	bus0_address,
		input [22:1]	bus1_address,
		input [22:1]	bus2_address,
		input [22:1]	bus3_address
	);
		case( bus )
			2'd0:		func_select_address = bus0_address;
			2'd1:		func_select_address = bus1_address;
			2'd2:		func_select_address = bus2_address;
			default:	func_select_address = bus3_address;
		endcase
	endfunction

	function [15:0] func_select_wdata(
		input [1:0]		bus,
		input [15:0]	bus0_wdata,
		input [15:0]	bus1_wdata,
		input [15:0]	bus2_wdata,
		input [15:0]	bus3_wdata
	);
		case( bus )
			2'd0:		func_select_wdata = bus0_wdata;
			2'd1:		func_select_wdata = bus1_wdata;
			2'd2:		func_select_wdata = bus2_wdata;
			default:	func_select_wdata = bus3_wdata;
		endcase
	endfunction

	function func_select_1bit(
		input [1:0]		bus,
		input			bus0_write,
		input			bus1_write,
		input			bus2_write,
		input			bus3_write
	);
		case( bus )
			2'd0:		func_select_1bit = bus0_write;
			2'd1:		func_select_1bit = bus1_write;
			2'd2:		func_select_1bit = bus2_write;
			default:	func_select_1bit = bus3_write;
		endcase
	endfunction

	assign w_active					= (bus0_valid | bus1_valid | bus2_valid | bus3_valid) & ff_ready;
	assign w_valid					= { bus3_valid, bus2_valid, bus1_valid, bus0_valid };
	assign w_priority_valid			= func_rotate_priority( w_valid, ff_priority );
	assign w_selected_valid 		= func_select_valid( w_priority_valid );
	assign w_selected_bus			= w_selected_valid + ff_priority;

	assign w_selected_bus_address	= func_select_address( w_selected_bus, bus0_address, bus1_address, bus2_address, bus3_address );
	assign w_selected_bus_wdata		= func_select_wdata( w_selected_bus, bus0_wdata, bus1_wdata, bus2_wdata, bus3_wdata );
	assign w_selected_bus_write		= func_select_1bit( w_selected_bus, bus0_write, bus1_write, bus2_write, bus3_write );
	assign w_selected_bus_flash		= func_select_1bit( w_selected_bus, bus0_flash, bus1_flash, bus2_flash, bus3_flash );

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
			ff_ready		<= 1'b0;
			ff_read_bus		<= 2'd0;
			ff_read_stall	<= 1'b0;
		end
		else if( !ff_ready ) begin
			if( bus_ready && !ff_read_stall ) begin
				//	readによる待機時間ではなく、かつ後段から busy が来ていない場合は次のサイクルで ready にする
				ff_ready		<= 1'b1;
			end
			else if( bus_rdata_valid ) begin
				//	bus_rdata_valid が来たら read による待機時間を終える
				ff_ready		<= bus_ready;
				ff_read_stall	<= 1'b0;
			end
		end
		else if( w_active ) begin
			if( !bus_ready || !w_selected_bus_write ) begin
				//	後段から busy が来ているか、あるいは read要求だった場合は次のサイクルで busy にする
				ff_ready		<= 1'b0;
				ff_read_stall	<= ~w_selected_bus_write;
				if( !w_selected_bus_write ) begin
					ff_read_bus	<= w_selected_bus;
				end
			end
		end
	end

	assign bus0_rdata		= (ff_read_bus == 2'd0) ? bus_rdata : 16'd0;
	assign bus1_rdata		= (ff_read_bus == 2'd1) ? bus_rdata : 16'd0;
	assign bus2_rdata		= (ff_read_bus == 2'd2) ? bus_rdata : 16'd0;
	assign bus3_rdata		= (ff_read_bus == 2'd3) ? bus_rdata : 16'd0;

	assign bus0_rdata_valid	= (ff_read_bus == 2'd0) ? bus_rdata_valid : 1'b0;
	assign bus1_rdata_valid	= (ff_read_bus == 2'd1) ? bus_rdata_valid : 1'b0;
	assign bus2_rdata_valid	= (ff_read_bus == 2'd2) ? bus_rdata_valid : 1'b0;
	assign bus3_rdata_valid	= (ff_read_bus == 2'd3) ? bus_rdata_valid : 1'b0;

	assign bus0_ready		= (w_selected_bus == 2'd0) ? ff_ready : 1'b0;
	assign bus1_ready		= (w_selected_bus == 2'd1) ? ff_ready : 1'b0;
	assign bus2_ready		= (w_selected_bus == 2'd2) ? ff_ready : 1'b0;
	assign bus3_ready		= (w_selected_bus == 2'd3) ? ff_ready : 1'b0;

	assign bus_address		= w_selected_bus_address;
	assign bus_write		= w_selected_bus_write;
	assign bus_wdata		= w_selected_bus_wdata;
	assign bus_flash		= w_selected_bus_flash;
	assign bus_valid		= w_active;
endmodule
