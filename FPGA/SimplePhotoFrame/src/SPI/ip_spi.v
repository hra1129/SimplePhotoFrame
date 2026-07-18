//
// ip_spi.v
//   SPI Slave Controller
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

module ip_spi (
	input			reset,
	input			clk,					//	System Clock
	input			clk_serial,				//	Serial Clock
	//	Bus (Master)
	output	[7:0]	bus_cs,
	output			bus_write,
	output			bus_valid,
	input			bus_ready,
	output	[15:0]	bus_wdata,
	output	[4:0]	bus_address,
	input	[15:0]	bus_rdata,
	input			bus_rdata_en,
	//	SPI
	input			spi_cs_n,
	input			spi_clk,
	input			spi_mosi,
	output			spi_miso,
	output			spi_intr
);
	localparam		ST_IDLE			= 3'd0;
	localparam		ST_COMMAND		= 3'd1;
	localparam		ST_ADDRESS		= 3'd2;
	localparam		ST_WDATA_L		= 3'd3;
	localparam		ST_WDATA_H		= 3'd4;
	localparam		ST_DO			= 3'd5;
	localparam		ST_SEND			= 3'd6;
	localparam		ST_READ_DATA	= 3'd7;
	reg				ff_spi_cs_n_pre;
	reg				ff_spi_cs_n;
	reg		[2:0]	ff_state;
	reg		[7:0]	ff_spi_wdata;
	reg				ff_spi_write;
	reg				ff_spi_valid;
	reg				ff_spi_intr;
	reg				ff_spi_tx_load_en_d1;
	wire			spi_ready;
	wire	[7:0]	spi_rdata;
	wire			spi_rdata_en;
	wire				spi_tx_load_en;
	reg		[4:0]	ff_bus_address;
	reg		[15:0]	ff_bus_wdata;
	reg		[15:0]	ff_bus_rdata;
	reg				ff_send_data_h;
	reg		[7:0]	ff_bus_cs;
	reg				ff_bus_write;
	reg				ff_bus_valid;
	reg				ff_spi_send_started;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_spi_cs_n_pre <= 1'b1;
			ff_spi_cs_n     <= 1'b1;
		end
		else begin
			ff_spi_cs_n_pre <= spi_cs_n;
			ff_spi_cs_n     <= ff_spi_cs_n_pre;
		end
	end

	// ---------------------------------------------------------
	// 	SPI interrupt control
	// 	TX data が実際に SPI シフタへロードされたタイミングで立てる。
	// 	最初の MISO bit が出せる状態になったら MCU に通知する。
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( reset ) begin
			ff_spi_intr				<= 1'b0;
			ff_spi_tx_load_en_d1	<= 1'b0;
		end
		else if( ff_spi_cs_n ) begin
			ff_spi_intr				<= 1'b0;
			ff_spi_tx_load_en_d1	<= 1'b0;
		end
		else begin
			ff_spi_tx_load_en_d1	<= spi_tx_load_en;
			if( ff_spi_tx_load_en_d1 ) begin
				ff_spi_intr	<= 1'b1;
			end
			else if( ff_spi_intr && spi_clk ) begin
				ff_spi_intr	<= 1'b0;
			end
		end
	end

	function [7:0] func_bus_decoder(
		input	[2:0]	address_h
	);
		case( address_h )
		3'h0:		func_bus_decoder = 8'h01;	// I/O #0
		3'h1:		func_bus_decoder = 8'h02;	// I/O #1
		3'h2:		func_bus_decoder = 8'h04;	// I/O #2
		3'h3:		func_bus_decoder = 8'h08;	// I/O #3
		3'h4:		func_bus_decoder = 8'h10;	// I/O #4
		3'h5:		func_bus_decoder = 8'h20;	// I/O #5
		3'h6:		func_bus_decoder = 8'h40;	// I/O #6
		3'h7:		func_bus_decoder = 8'h80;	// I/O #7
		default:	func_bus_decoder = 8'h00; // invalid I/O #
		endcase
	endfunction

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( reset ) begin
			ff_state		<= ST_IDLE;
			ff_bus_address	<= 5'd0;
			ff_bus_wdata	<= 16'd0;
			ff_bus_rdata	<= 16'd0;
			ff_send_data_h	<= 1'b0;
			ff_bus_cs		<= 8'd0;
			ff_bus_write	<= 1'b0;
			ff_bus_valid	<= 1'b0;
			ff_spi_wdata	<= 8'd0;
			ff_spi_write	<= 1'b0;
			ff_spi_valid	<= 1'b0;
			ff_spi_send_started <= 1'b0;
		end
		else if( ff_state == ST_SEND ) begin
			if( !ff_spi_send_started ) begin
				// request accepted when valid and ready are high together
				if( ff_spi_valid && spi_ready ) begin
					ff_spi_valid			<= 1'b0;
					ff_spi_send_started	<= 1'b1;
				end
			end
			else begin
				// byte finished when ready rises high again
				if( spi_ready ) begin
					ff_spi_send_started <= 1'b0;
					if( !ff_send_data_h ) begin
						ff_send_data_h	<= 1'b1;
						ff_spi_wdata	<= ff_bus_rdata[15:8];
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b1;
					end
					else begin
						ff_send_data_h	<= 1'b0;
						if( ff_spi_cs_n ) begin
							ff_state <= ST_IDLE;
						end
						else begin
							ff_state		<= ST_COMMAND;
							ff_spi_valid	<= 1'b1;
							ff_spi_write	<= 1'b0;
						end
					end
				end
			end
		end
		else if( ff_state == ST_DO ) begin
			if( ff_bus_write ) begin
				if( bus_ready ) begin
					ff_bus_valid	<= 1'b0;
					if( ff_spi_cs_n ) begin
						ff_state <= ST_IDLE;
					end
					else begin
						ff_state		<= ST_COMMAND;
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b0;
					end
				end
			end
			else begin
				if( bus_rdata_en ) begin
					ff_bus_valid	<= 1'b0;
					ff_state		<= ST_READ_DATA;
				end
			end
		end
		else if( ff_state == ST_READ_DATA ) begin
			ff_state		<= ST_SEND;
			ff_bus_rdata	<= bus_rdata;
			ff_spi_wdata	<= bus_rdata[7:0];
			ff_send_data_h	<= 1'b0;
			ff_spi_valid	<= 1'b1;
			ff_spi_write	<= 1'b1;
			ff_spi_send_started <= 1'b0;
		end
		else if( ff_spi_cs_n ) begin
			ff_state		<= ST_IDLE;
			ff_send_data_h	<= 1'b0;
			ff_spi_valid	<= 1'b0;
			ff_bus_valid	<= 1'b0;
			ff_spi_send_started <= 1'b0;
		end
		else if( ff_spi_valid ) begin
			if( spi_ready ) begin
				ff_spi_valid	<= 1'b0;
			end
		end
		else begin
			case( ff_state )
			ST_IDLE: begin
				ff_state		<= ST_COMMAND;
				ff_spi_valid	<= 1'b1;
				ff_spi_write	<= 1'b0;
				ff_spi_send_started <= 1'b0;
			end
			// -------------------------------------------------
			// COMMAND:
			//   01h, io#, data_l, data_h .................... I/O write
			//   02h, io#, dummy_l, dummy_h .................. I/O read (return data_l, data_h)
			ST_COMMAND: begin
				if( spi_rdata_en ) begin
					case( spi_rdata )
					8'h01: begin
						//	I/O write
						ff_state		<= ST_ADDRESS;
						ff_bus_write	<= 1'b1;
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b0;
					end
					8'h02: begin
						//	I/O read
						ff_state		<= ST_ADDRESS;
						ff_bus_write	<= 1'b0;
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b0;
					end
					default: begin
						// unknown command --> ignore
					end
					endcase
				end
				else begin
					//	hold
				end
			end
			ST_ADDRESS: begin
				if( spi_rdata_en ) begin
					ff_bus_address			<= spi_rdata[4:0];
					ff_bus_cs				<= func_bus_decoder( spi_rdata[7:5] );
					if( ff_bus_write ) begin
						ff_state			<= ST_WDATA_L;
						ff_spi_valid		<= 1'b1;
						ff_spi_write		<= 1'b0;
					end
					else begin
						ff_state			<= ST_DO;
						ff_bus_valid		<= 1'b1;
					end
				end
			end
			ST_WDATA_L: begin
				if( spi_rdata_en ) begin
					ff_bus_wdata[7:0]	<= spi_rdata;
					ff_state		<= ST_WDATA_H;
					ff_spi_valid	<= 1'b1;
					ff_spi_write	<= 1'b0;
				end
			end
			ST_WDATA_H: begin
				if( spi_rdata_en ) begin
					ff_bus_wdata[15:8]	<= spi_rdata;
					ff_state		<= ST_DO;
					ff_bus_valid	<= 1'b1;
				end
			end
			default: begin
				// unknown state
				ff_state <= ST_COMMAND;
			end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	SPI slave module for connect the micro controller.
	// ---------------------------------------------------------
	spi u_spi (
	.reset_n		( ~reset			),
	.clk			( clk				),
	.clk_serial		( clk_serial		),
	.spi_valid		( ff_spi_valid		),
	.spi_ready		( spi_ready			),
	.spi_write		( ff_spi_write		),
	.spi_wdata		( ff_spi_wdata		),
	.spi_rdata		( spi_rdata			),
	.spi_rdata_en	( spi_rdata_en		),
	.spi_tx_load_en	( spi_tx_load_en	),
	.spi_cs_n		( spi_cs_n			),
	.spi_clk		( spi_clk			),
	.spi_mosi		( spi_mosi			),
	.spi_miso		( spi_miso			)
	);

	assign spi_intr		= ff_spi_intr;

	// ---------------------------------------------------------
	//	BUS access
	// ---------------------------------------------------------
	assign bus_cs			= ff_bus_cs;
	assign bus_write		= ff_bus_write;
	assign bus_address		= ff_bus_address;
	assign bus_wdata		= ff_bus_wdata;
	assign bus_valid		= ff_bus_valid;
endmodule
