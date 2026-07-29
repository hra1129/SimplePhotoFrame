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
	// -------------------------------------------------
	// COMMAND:
	//   01h, io#, data_l, data_h .................... I/O write
	//   02h, io#, dummy_l, dummy_h .................. I/O read (return data_l, data_h)
	//   03h, io#, busy .............................. I/O status read (return bus_ready for selected I/O)
	localparam		CMD_IO_WRITE	= 8'h01;
	localparam		CMD_IO_READ		= 8'h02;
	localparam		CMD_IO_STATUS	= 8'h03;

	localparam		ST_IDLE			= 4'd0;
	localparam		ST_COMMAND		= 4'd1;		//	受けたコマンドから分岐する
	localparam		ST_ADDRESS		= 4'd2;		//	アドレス(1byte)受信
	localparam		ST_WDATA_L		= 4'd3;		//	データ(下位1byte)受信
	localparam		ST_WDATA_H		= 4'd4;		//	データ(上位1byte)受信
	localparam		ST_BUS_READ		= 4'd5;		//	バスからの読み出し応答待ち
	localparam		ST_RDATA_L		= 4'd6;		//	データ(下位1byte)送信
	localparam		ST_RDATA_H		= 4'd7;		//	データ(上位1byte)送信
	reg				ff_spi_cs_n_pre;
	reg				ff_spi_cs_n;
	reg		[3:0]	ff_state;
	reg		[7:0]	ff_spi_wdata;
	reg				ff_spi_write;
	reg				ff_spi_valid;
	reg				ff_spi_intr;
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
	reg				ff_status_read;
	wire			w_bus_ready;

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

	assign w_bus_ready	= (ff_bus_cs == 8'd0) ? 1'b1: bus_ready;

	// ---------------------------------------------------------
	// 	SPI interrupt control
	// 	TX data が実際に SPI シフタへロードされたタイミングで立てる。
	// 	最初の MISO bit が出せる状態になったら MCU に通知する。
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( reset ) begin
			ff_spi_intr				<= 1'b0;
		end
		else if( ff_spi_cs_n ) begin
			ff_spi_intr				<= 1'b0;
		end
		else begin
			if( spi_tx_load_en ) begin
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
			ff_state				<= ST_IDLE;
			ff_bus_address			<= 5'd0;
			ff_bus_wdata			<= 16'd0;
			ff_bus_rdata			<= 16'd0;
			ff_send_data_h			<= 1'b0;
			ff_bus_cs				<= 8'd0;
			ff_bus_write			<= 1'b0;
			ff_bus_valid			<= 1'b0;
			ff_spi_wdata			<= 8'd0;
			ff_spi_write			<= 1'b0;
			ff_spi_valid			<= 1'b0;
			ff_status_read			<= 1'b0;
		end
		else if( ff_spi_cs_n ) begin
			//	CS_N = H になったら、リセット
			ff_state				<= ST_IDLE;
			ff_send_data_h			<= 1'b0;
			ff_spi_valid			<= 1'b0;
			ff_bus_valid			<= 1'b0;
		end
		else if( ff_bus_valid ) begin
			if( w_bus_ready ) begin
				ff_bus_valid		<= 1'b0;
			end
		end
		else if( ff_spi_valid ) begin
			if( spi_ready ) begin
				ff_spi_valid		<= 1'b0;
			end
		end
		else begin
			case( ff_state )
			ST_IDLE: begin
				ff_state			<= ST_COMMAND;
				ff_spi_valid		<= 1'b1;
				ff_spi_write		<= 1'b0;
			end
			ST_COMMAND: begin
				if( spi_rdata_en ) begin
					case( spi_rdata )
					CMD_IO_WRITE: begin
						//	I/O write
						ff_state		<= ST_ADDRESS;
						ff_status_read	<= 1'b0;
						ff_bus_write	<= 1'b1;
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b0;
					end
					CMD_IO_READ: begin
						//	I/O read
						ff_state		<= ST_ADDRESS;
						ff_status_read	<= 1'b0;
						ff_bus_write	<= 1'b0;
						ff_spi_valid	<= 1'b1;
						ff_spi_write	<= 1'b0;
					end
					CMD_IO_STATUS: begin
						//	I/O status read
						ff_state		<= ST_ADDRESS;
						ff_status_read	<= 1'b1;
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
					if( ff_status_read ) begin
						//	I/O status read
						ff_state				<= ST_RDATA_H;
						ff_bus_rdata			<= { 7'd0, w_bus_ready, 8'd0 };
					end
					else if( ff_bus_write ) begin
						//	I/O write
						ff_state				<= ST_WDATA_L;
						ff_spi_valid			<= 1'b1;
						ff_spi_write			<= 1'b0;
					end
					else begin
						//	I/O read
						ff_state				<= ST_BUS_READ;
						ff_bus_valid			<= 1'b1;
						ff_bus_write			<= 1'b0;
					end
				end
			end

			// -------------------------------------------------
			//	I/O write
			// -------------------------------------------------
			ST_WDATA_L: begin
				if( spi_rdata_en ) begin
					ff_bus_wdata[7:0]	<= spi_rdata;
					ff_state			<= ST_WDATA_H;
					ff_spi_valid		<= 1'b1;
					ff_spi_write		<= 1'b0;
				end
			end
			ST_WDATA_H: begin
				if( spi_rdata_en ) begin
					ff_bus_wdata[15:8]	<= spi_rdata;
					ff_state			<= ST_IDLE;
					ff_bus_valid		<= 1'b1;
				end
			end

			// -------------------------------------------------
			//	I/O read and I/O status read
			// -------------------------------------------------
			ST_BUS_READ: begin
				if( bus_rdata_en ) begin
					//	バスからの応答が来た
					ff_state			<= ST_RDATA_L;
					ff_bus_rdata		<= bus_rdata;
				end
			end
			ST_RDATA_L: begin
				ff_state			<= ST_RDATA_H;
				ff_spi_wdata		<= ff_bus_rdata[7:0];
				ff_spi_valid		<= 1'b1;
				ff_spi_write		<= 1'b1;
			end
			ST_RDATA_H: begin
				ff_state			<= ST_IDLE;
				ff_spi_wdata		<= ff_bus_rdata[15:8];
				ff_spi_valid		<= 1'b1;
				ff_spi_write		<= 1'b1;
			end

			// -------------------------------------------------
			//	Others
			// -------------------------------------------------
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
