// -----------------------------------------------------------------------------
//	ip_qspi_rom.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		QSPI serial flash ROM controller
// -----------------------------------------------------------------------------

module ip_qspi_rom(
	input			reset,				//	System Reset (Active High)
	input			clk,				//	System Clock
	input			clk_serial,			//	Serial Clock (High speed)
	//	Internal BUS interface
	input			bus_cs,
	input			bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	//	QSPI interface
	output			srom0_cs_n,
	output			srom1_cs_n,
	output			srom_clk,
	inout	[3:0]	srom_sio
);
	localparam	[2:0]	MODE_STD_WRITE				= 3'd0;
	localparam	[2:0]	MODE_STD_READ				= 3'd1;
	localparam	[2:0]	MODE_QUAD_WRITE				= 3'd2;
	localparam	[2:0]	MODE_QUAD_READ				= 3'd3;
	localparam	[2:0]	MODE_QUAD_DUMMY				= 3'd4;
	localparam	[2:0]	MODE_QUAD_DUMMY2			= 3'd5;

	localparam	[7:0]	SROM_PAGE_PROGRAM			= 8'h02;
	localparam	[7:0]	SROM_WRITE_DISABLE			= 8'h04;
	localparam	[7:0]	SROM_READ_STATUS_1			= 8'h05;
	localparam	[7:0]	SROM_WRITE_ENABLE			= 8'h06;
	localparam	[7:0]	SROM_READ_STATUS_2			= 8'h35;
	localparam	[7:0]	SROM_WRITE_STATUS_2			= 8'h31;
	localparam	[7:0]	SROM_CHIP_ERASE				= 8'h60;
	localparam	[7:0]	SROM_FAST_READ_QUAD_IO		= 8'hEB;
	localparam	[7:0]	SROM_STATUS_2_QE			= 8'h02;

	localparam	[3:0]	CMD_SET_ADDRESS				= 4'd0;
	localparam	[3:0]	CMD_SINGLE_READ				= 4'd1;
	localparam	[3:0]	CMD_BURST_READ				= 4'd2;
	localparam	[3:0]	CMD_BURST_WRITE				= 4'd3;
	localparam	[3:0]	CMD_CHIP_ERASE				= 4'd4;
	localparam	[3:0]	CMD_READ_STATUS				= 4'd5;
	localparam	[3:0]	CMD_SELECT_SROM				= 4'd6;
	localparam	[3:0]	CMD_ACCESS_END				= 4'd7;
	localparam	[3:0]	CMD_SET_QUAD_ENABLE			= 4'd8;

	
	reg				ff_bus_ready;
	reg		[7:0]	ff_bus_rdata;
	reg				ff_bus_rdata_en;

	reg		[3:0]	ff_command_mode;
	reg		[23:0]	ff_rom_address;
	reg		[1:0]	ff_byte_count;
	reg		[7:0]	ff_burst_wdata;
	reg		[7:0]	ff_burst_count;
	reg				ff_do_command;
	reg				ff_finish_command;

	reg		[2:0]	ff_serial_mode;
	reg		[7:0]	ff_serial_wdata;
	reg				ff_serial_write;
	reg				ff_serial_valid;
	wire			w_serial_ready;
	wire	[7:0]	w_serial_rdata;
	wire			w_serial_rdata_en;
	wire			w_serial_idle;
	reg				ff_srom0_cs_n;
	reg				ff_srom1_cs_n;
	reg				ff_cs_n;

	localparam [2:0]	CS_WAIT_10NS	= 1;
	localparam [2:0]	CS_WAIT_50NS	= 5;
	reg		[2:0]		ff_wait_count;
	reg					ff_wait_count_active;

	// ---------------------------------------------------------
	//	bus_address
	//		0: command port
	//		1: data port
	//
	//	command port:
	//		0x00: set address mode
	//			0x00を書き込むと 24bit のアドレスをセットするモード
	//			になる。この後に続けて data port へ、3byte 書き込む
	//			と、その値がアドレスとしてセットされる。
	//			3byte は、MSB から順に書き込む。
	//			1byte, 2byte しか書き込んでない状態で、command port
	//			に 0x00 を書き込むと、また 1byte目からに戻る。
	//		0x01: single read mode
	//			1byte の読み出しを行うモード。読み出しは、data port から行う。
	//			このモードでは、アドレスは自動でインクリメントされる。
	//			アドレスは、set address mode を使う。
	//			Serial ROM に対しては、data port からの読み出しのたびに
	//			アドレスをセットしに行く。
	//		0x02: burst read mode
	//			256byte の読み出しを行うモード。0x02 を書いた時点でアドレスを
	//			発行し、その後の data port からの読み出しは、
	//			1byte 読み出しのみである。
	//			開始アドレスは、アドレスの下位 1byte が無視される。
	//		0x03: burst write mode
	//			256byte の書き込みを行うモード。0x03 を書いた時点でアドレスを
	//			発行し、その後の data port への書き込みは、
	//			1byte 書き込みのみである。
	//			開始アドレスは、アドレスの下位 1byte が無視される。
	//		0x04: chip erase
	//			Serial ROM 全体を消去するコマンドを発行する。
	//			このモードでは、data port へのアクセスは行わない。
	//		0x05: read status register
	//			Serial ROM のステータスレジスタを読み出すモード。
	//			data port から、1byte 読み出すと、その最下位に busy ステータス
	//			が入る。
	//		0x06: select serial ROM
	//			このモードでは、接続する Serial ROM を選択する。
	//			data port へ Serial ROM 番号を書き込むと、その Serial ROM を選択する。
	//			0x00: srom0_cs_n をアクティブにする
	//			0x01: srom1_cs_n をアクティブにする
	//			0x02-0xFE: reserved
	//			0xFF: 未接続
	//		0x07: access end
	//			w_serial_idle が 1 になるのを待ってから、ff_cs_n を 1 に戻す。
	//		0x08: set quad enable
	//			このモードでは、Quad Enable ビットをセットするコマンド
	//		0x09-0xFF: reserved
	// ---------------------------------------------------------
	//	SerialROM Status Register
	//	S0: busy
	//	S1: write enable latch
	//	S2: block protect bit 0
	//	S3: block protect bit 1
	//	S4: block protect bit 2
	//	S5: top/bottom write protect
	//	S6: sector protect
	//	S7: status register protect 0
	//	S8: status register protect 1
	//	S9: quad enable
	//	S10-15: reserved
	// ---------------------------------------------------------

	// ---------------------------------------------------------
	//	Register interface
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( reset ) begin
			ff_command_mode			<= 4'd0;
			ff_srom0_cs_n			<= 1'b1;
			ff_srom1_cs_n			<= 1'b1;
			ff_bus_ready			<= 1'b1;
			ff_do_command			<= 1'b0;
			ff_burst_wdata			<= 8'd0;
			ff_burst_count			<= 8'd0;
		end
		else if( !ff_bus_ready ) begin
			ff_do_command			<= 1'b0;
			if( ff_finish_command && (!ff_cs_n || (ff_wait_count == 0)) ) begin
				ff_bus_ready		<= 1'b1;
			end
		end
		else if( bus_cs && bus_valid ) begin
			if( (bus_address == 1'b0) && bus_write ) begin
				//	command port
				case( bus_wdata )
					8'h00: begin
						//	set address mode
						ff_command_mode	<= CMD_SET_ADDRESS;
						ff_byte_count	<= 2'd0;
					end
					8'h01: begin
						//	single read mode
						ff_command_mode	<= CMD_SINGLE_READ;
					end
					8'h02: begin
						//	burst read mode
						ff_command_mode	<= CMD_BURST_READ;
					end
					8'h03: begin
						//	burst write mode
						ff_command_mode			<= CMD_BURST_WRITE;
						ff_rom_address[7:0]		<= 8'h00;
						ff_burst_count			<= 8'd0;
					end
					8'h04: begin
						//	chip erase
						ff_command_mode			<= CMD_CHIP_ERASE;
					end
					8'h05: begin
						//	read status register
						ff_command_mode			<= CMD_READ_STATUS;
					end
					8'h06: begin
						//	select serial ROM
						ff_command_mode			<= CMD_SELECT_SROM;
					end
					8'h07: begin
						//	access end
						ff_command_mode			<= CMD_ACCESS_END;
						ff_bus_ready			<= 1'b0;
						ff_do_command			<= 1'b1;
					end
					8'h08: begin
						//	set quad enable
						//	このモードでは、Quad Enable ビットをセットするコマンドを発行する。
						//	Quad Enable ビットは、Status Register 2 のビット 1 である。
						ff_command_mode			<= CMD_SET_QUAD_ENABLE;
						ff_bus_ready			<= 1'b0;
						ff_do_command			<= 1'b1;
					end
					default: begin
						//	reserved command, do nothing.
					end
				endcase
			end
			else if( (bus_address == 1'b1) && bus_write ) begin
				//	data port
				case( ff_command_mode )
					CMD_SET_ADDRESS: begin
						case( ff_byte_count )
							2'd0: begin
								ff_rom_address[23:16]	<= bus_wdata;
								ff_byte_count			<= 2'd1;
							end
							2'd1: begin
								ff_rom_address[15: 8]	<= bus_wdata;
								ff_byte_count			<= 2'd2;
							end
							2'd2: begin
								ff_rom_address[ 7: 0]	<= bus_wdata;
								ff_byte_count			<= 2'd0;
							end
							default: begin
								//	invalid operation
							end
						endcase
					end
					CMD_BURST_WRITE: begin
						//	data port への書き込みは、burst write で 1byte ずつ送る。
						if( ff_cs_n ) begin
							//	初回の burst write の場合は、ff_cs_n = 1 なので、コマンド発行処理を実施。
							ff_burst_wdata			<= bus_wdata;
							ff_bus_ready			<= 1'b0;
							ff_do_command			<= 1'b1;
						end
						else begin
							//	2回目以降の burst write の場合は、ff_cs_n = 0 なので、コマンド発行処理は不要。
							ff_burst_wdata			<= bus_wdata;
							ff_bus_ready			<= 1'b0;
							ff_burst_count			<= ff_burst_count + 8'd1;
							ff_do_command			<= 1'b1;
						end
					end
					CMD_CHIP_ERASE: begin
						//	このモードでは、data port へのアクセスは行わない。
						ff_bus_ready			<= 1'b0;
						ff_do_command			<= 1'b1;
					end
					CMD_SELECT_SROM: begin
						//	data port へ Serial ROM 番号を書き込むと、その Serial ROM を選択する。
						case( bus_wdata )
							8'h00: begin
								//	srom0_cs_n をアクティベートする
								ff_srom0_cs_n <= 1'b0;
								ff_srom1_cs_n <= 1'b1;
							end
							8'h01: begin
								//	srom1_cs_n をアクティベートする
								ff_srom0_cs_n <= 1'b1;
								ff_srom1_cs_n <= 1'b0;
							end
							default: begin
								//	未接続にする
								ff_srom0_cs_n <= 1'b1;
								ff_srom1_cs_n <= 1'b1;
							end
						endcase
					end
					default: begin
						//	reserved command, do nothing.
					end
				endcase
			end
			else if( (bus_address == 1'b1) && !bus_write ) begin
				case( ff_command_mode )
					CMD_SINGLE_READ: begin
						//	Serial ROM に対しては、data port からの読み出しのたびにアドレスをセットしに行く。
						ff_bus_ready		<= 1'b0;
						ff_do_command		<= 1'b1;
					end
					CMD_BURST_READ: begin
						//	0x02 を書いた時点でアドレスを発行し、その後の data port からの読み出しは、1byte 読み出しのみである。
						ff_bus_ready		<= 1'b0;
						ff_do_command		<= 1'b1;
					end
					CMD_READ_STATUS: begin
						//	data port から、1byte 読み出すと、その最下位に busy ステータスが入る。
						ff_bus_ready		<= 1'b0;
						ff_do_command		<= 1'b1;
					end
					default: begin
						//	reserved command, do nothing.
					end
				endcase
			end
		end
	end

	assign bus_ready	= ff_bus_ready;
	assign bus_rdata	= ff_bus_rdata;
	assign bus_rdata_en	= ff_bus_rdata_en;

	// ---------------------------------------------------------
	//	コマンド実行ステートマシン
	// ---------------------------------------------------------
	localparam	[4:0]	ST_IDLE			= 5'd0;
	localparam	[4:0]	ST_READ_BYTE	= 5'd1;
	localparam	[4:0]	ST_RECEIVE_BYTE	= 5'd2;
	localparam	[4:0]	ST_WAIT			= 5'd3;
	localparam	[4:0]	ST_WRITE_MODE	= 5'd4;
	localparam	[4:0]	ST_WRITE_ADDR_H	= 5'd5;
	localparam	[4:0]	ST_WRITE_ADDR_M	= 5'd6;
	localparam	[4:0]	ST_WRITE_ADDR_L	= 5'd7;
	localparam	[4:0]	ST_WRITE_BYTE	= 5'd8;
	localparam	[4:0]	ST_ERASE		= 5'd9;
	localparam	[4:0]	ST_FINISH		= 5'd10;
	localparam	[4:0]	ST_READ_MODE	= 5'd11;
	localparam	[4:0]	ST_READ_ADDR_H	= 5'd12;
	localparam	[4:0]	ST_READ_ADDR_M	= 5'd13;
	localparam	[4:0]	ST_READ_ADDR_L	= 5'd14;
	localparam	[4:0]	ST_READ_DUMMY	= 5'd15;
	localparam	[4:0]	ST_SET_QE_CMD	= 5'd16;
	localparam	[4:0]	ST_SET_QE_DATA	= 5'd17;

	reg		[4:0]		ff_command_state;
	reg		[4:0]		ff_next_command_state;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_wait_count	<= 0;
		end
		else if( ff_cs_n == 1'b0 ) begin
			if( ff_command_mode == CMD_BURST_READ || ff_command_mode == CMD_READ_STATUS ) begin
				ff_wait_count	<= CS_WAIT_10NS;
			end
			else begin
				ff_wait_count	<= CS_WAIT_50NS;
			end
		end
		else if( ff_wait_count_active && ff_wait_count != 0 ) begin
			ff_wait_count	<= ff_wait_count - 1;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_wait_count_active	<= 1'b0;
		end
		else if( ff_cs_n ) begin
			ff_wait_count_active	<= 1'b1;
		end
		else if( ff_wait_count_active ) begin
			//	ff_wait_count_active が 1 の場合は、ff_wait_count が 0 になるまで待つ。
			if( ff_wait_count == 0 ) begin
				ff_wait_count_active	<= 1'b0;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_finish_command		<= 1'b0;
		end
		else if( ff_serial_valid ) begin
		end
		else if( ff_finish_command && !ff_bus_ready && (!ff_cs_n || (ff_wait_count == 0)) ) begin
			ff_finish_command		<= 1'b0;
		end
		else begin
			if( ff_command_state == ST_FINISH ) begin
				if( w_serial_idle ) begin
					ff_finish_command		<= 1'b1;
				end
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_cs_n					<= 1'b1;
			ff_command_state		<= ST_IDLE;
			ff_serial_mode			<= MODE_STD_WRITE;
			ff_serial_wdata			<= 8'd0;
			ff_serial_write			<= 1'b0;
			ff_serial_valid			<= 1'b0;
			ff_bus_rdata_en			<= 1'b0;
		end
		else if( ff_bus_rdata_en ) begin
			//	bus_rdata_en を 1clk だけアクティブにするための処理
			ff_bus_rdata_en	<= 1'b0;
		end
		else if( ff_serial_valid ) begin
			if( w_serial_ready ) begin
				ff_serial_valid	<= 1'b0;
			end
		end
		else begin
			case( ff_command_state )
				ST_IDLE: begin
					if( ff_do_command ) begin
						case( ff_command_mode )
							CMD_SINGLE_READ: begin
								//	このモードでは、data port からの読み出しのたびに
								//	Fast Read Quad I/O(EBh) を発行する。
								ff_command_state		<= ST_READ_MODE;
								ff_serial_mode			<= MODE_STD_WRITE;
								ff_serial_wdata 		<= SROM_FAST_READ_QUAD_IO;
								ff_serial_write 		<= 1'b1;
								ff_serial_valid 		<= 1'b1;
								ff_cs_n					<= 1'b0;
							end
							CMD_BURST_READ: begin
								if( ff_cs_n ) begin
									//	burst read の初回は ff_cs_n = 1 なので、コマンド発行処理を実施。
									//	このモードでは、0x02 を書いた時点で EBh + address + dummy を発行し、
									//	その後の data port からの読み出しは、1byte 読み出しのみである。
									ff_command_state		<= ST_READ_MODE;
									ff_serial_mode			<= MODE_STD_WRITE;	//	通常の SPI モード
									ff_serial_wdata 		<= SROM_FAST_READ_QUAD_IO;
									ff_serial_write 		<= 1'b1;
									ff_serial_valid 		<= 1'b1;
									ff_cs_n					<= 1'b0;
								end
								else begin
									//	burst read の 2回目以降は、ff_cs_n = 0 のままデータを読み出す。
									ff_command_state		<= ST_RECEIVE_BYTE;
									ff_serial_mode			<= MODE_QUAD_READ;
									ff_serial_wdata 		<= 8'd0;
									ff_serial_write 		<= 1'b0;
									ff_serial_valid 		<= 1'b1;
								end
							end
							CMD_BURST_WRITE: begin
								if( ff_cs_n ) begin
									//	burst write の初回は ff_cs_n = 1 なので、コマンド発行処理を実施。
									//	このモードでは、0x03 を書いた時点でアドレスを発行し、その後の data port への書き込みは、1byte 書き込みのみである。
									ff_command_state		<= ST_WAIT;
									ff_next_command_state	<= ST_WRITE_MODE;
									ff_serial_mode			<= MODE_STD_WRITE;	//	通常の SPI モード
									ff_serial_wdata 		<= SROM_WRITE_ENABLE;
									ff_serial_write 		<= 1'b1;
									ff_serial_valid 		<= 1'b1;
									ff_cs_n					<= 1'b0;
								end
								else begin
									//	burst write の 2回目以降は、ff_cs_n = 0 なので、コマンド発行処理は不要。
									ff_command_state		<= ST_FINISH;
									ff_serial_mode			<= MODE_STD_WRITE;	//	通常の SPI モード
									ff_serial_wdata 		<= ff_burst_wdata;
									ff_serial_write 		<= 1'b1;
									ff_serial_valid 		<= 1'b1;
								end
							end
							CMD_CHIP_ERASE: begin
								//	Serial ROM 全体を消去するコマンドを発行する。
								ff_command_state		<= ST_WAIT;
								ff_next_command_state	<= ST_ERASE;
								ff_serial_mode			<= MODE_STD_WRITE;	//	通常の SPI モード
								ff_serial_wdata 		<= SROM_WRITE_ENABLE;
								ff_serial_write 		<= 1'b1;
								ff_serial_valid 		<= 1'b1;
								ff_cs_n					<= 1'b0;
							end
							CMD_READ_STATUS: begin
								if( ff_cs_n ) begin
									//	Serial ROM のステータスレジスタを読み出すモード。data port から、1byte 読み出すと、その最下位に busy ステータスが入る。
									ff_command_state		<= ST_READ_BYTE;
									ff_serial_mode			<= MODE_STD_WRITE;	//	通常の SPI モード
									ff_serial_wdata 		<= SROM_READ_STATUS_1;
									ff_serial_write 		<= 1'b1;
									ff_serial_valid 		<= 1'b1;
									ff_cs_n					<= 1'b0;
								end
								else begin
									ff_command_state		<= ST_RECEIVE_BYTE;
									ff_serial_mode			<= MODE_STD_READ;	//	通常の SPI モード
									ff_serial_wdata 		<= 8'd0;
									ff_serial_write 		<= 1'b0;
									ff_serial_valid 		<= 1'b1;
								end
							end
							CMD_ACCESS_END: begin
								//	w_serial_idle が 1 になるのを待って、アクセスを終了する。
								ff_command_state	<= ST_FINISH;
							end
							CMD_SET_QUAD_ENABLE: begin
								//	WREN の後に Status Register-2 を書き換えて QE bit を立てる。
								ff_command_state		<= ST_WAIT;
								ff_next_command_state	<= ST_SET_QE_CMD;
								ff_serial_mode			<= MODE_STD_WRITE;
								ff_serial_wdata 		<= SROM_WRITE_ENABLE;
								ff_serial_write 		<= 1'b1;
								ff_serial_valid 		<= 1'b1;
								ff_cs_n					<= 1'b0;
							end
							default: begin
								//	reserved command, do nothing.
							end
						endcase
					end
				end
				ST_READ_MODE: begin
					ff_command_state	<= ST_READ_ADDR_H;
					ff_serial_mode		<= MODE_QUAD_WRITE;
					ff_serial_wdata		<= ff_rom_address[23:16];
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_READ_ADDR_H: begin
					ff_command_state	<= ST_READ_ADDR_M;
					ff_serial_mode		<= MODE_QUAD_WRITE;
					ff_serial_wdata		<= ff_rom_address[15:8];
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_READ_ADDR_M: begin
					ff_command_state	<= ST_READ_ADDR_L;
					ff_serial_mode		<= MODE_QUAD_WRITE;
					if( ff_command_mode == CMD_BURST_READ ) begin
						ff_serial_wdata	<= 8'h00;
					end
					else begin
						ff_serial_wdata	<= ff_rom_address[7:0];
					end
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_READ_ADDR_L: begin
					ff_command_state	<= ST_READ_DUMMY;
					ff_serial_mode		<= MODE_QUAD_WRITE;
					ff_serial_wdata		<= 8'h00;
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_READ_DUMMY: begin
					ff_command_state	<= ST_READ_BYTE;
					ff_serial_mode		<= MODE_QUAD_DUMMY2;
					ff_serial_wdata		<= 8'd0;
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_SET_QE_CMD: begin
					if( ff_wait_count == 0 ) begin
						ff_command_state	<= ST_SET_QE_DATA;
						ff_serial_mode		<= MODE_STD_WRITE;
						ff_serial_wdata		<= SROM_WRITE_STATUS_2;
						ff_serial_write		<= 1'b1;
						ff_serial_valid		<= 1'b1;
						ff_cs_n				<= 1'b0;
					end
				end
				ST_SET_QE_DATA: begin
					ff_command_state	<= ST_FINISH;
					ff_serial_mode		<= MODE_STD_WRITE;
					ff_serial_wdata		<= SROM_STATUS_2_QE;
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_READ_BYTE: begin
					ff_command_state	<= ST_RECEIVE_BYTE;
					if( ff_command_mode == CMD_READ_STATUS ) begin
						ff_serial_mode	<= MODE_STD_READ;	//	通常の SPI モード
					end
					else begin
						ff_serial_mode	<= MODE_QUAD_READ;
					end
					ff_serial_wdata 	<= 8'd0;
					ff_serial_write 	<= 1'b0;
					ff_serial_valid 	<= 1'b1;
				end
				ST_RECEIVE_BYTE: begin
					if( w_serial_rdata_en ) begin
						if( ff_command_mode == CMD_READ_STATUS ) begin
							ff_bus_rdata	<= { 7'b0, w_serial_rdata[0] };
						end
						else begin
							ff_bus_rdata	<= w_serial_rdata;
							ff_rom_address	<= ff_rom_address + 24'd1;
						end
						ff_bus_rdata_en		<= 1'b1;
						ff_command_state	<= ST_FINISH;
					end
				end
				ST_WAIT: begin
					if( w_serial_idle ) begin
						ff_command_state		<= ff_next_command_state;
						ff_cs_n					<= 1'b1;
					end
				end
				ST_WRITE_MODE: begin
					if( ff_wait_count == 0 ) begin
						ff_command_state	<= ST_WRITE_ADDR_H;
						ff_serial_mode		<= MODE_STD_WRITE;	//	通常の SPI モード
						ff_serial_wdata 	<= SROM_PAGE_PROGRAM;
						ff_serial_write 	<= 1'b1;
						ff_serial_valid 	<= 1'b1;
						ff_cs_n				<= 1'b0;
					end
				end
				ST_WRITE_ADDR_H: begin
					ff_command_state	<= ST_WRITE_ADDR_M;
					ff_serial_mode		<= MODE_STD_WRITE;
					ff_serial_wdata		<= ff_rom_address[23:16];
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_WRITE_ADDR_M: begin
					ff_command_state	<= ST_WRITE_ADDR_L;
					ff_serial_mode		<= MODE_STD_WRITE;
					ff_serial_wdata		<= ff_rom_address[15:8];
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_WRITE_ADDR_L: begin
					ff_command_state	<= ST_WRITE_BYTE;
					ff_serial_mode		<= MODE_STD_WRITE;
					ff_serial_wdata		<= 8'h00;
					ff_serial_write		<= 1'b1;
					ff_serial_valid		<= 1'b1;
				end
				ST_WRITE_BYTE: begin
					ff_command_state	<= ST_FINISH;
					ff_serial_mode		<= MODE_STD_WRITE;	//	通常の SPI モード
					ff_serial_wdata 	<= ff_burst_wdata;
					ff_serial_write 	<= 1'b1;
					ff_serial_valid 	<= 1'b1;
				end
				ST_ERASE: begin
					if( ff_wait_count == 0 ) begin
						//	このモードでは、data port へのアクセスは行わない。
						ff_command_state	<= ST_FINISH;
						ff_serial_mode		<= MODE_STD_WRITE;	//	通常の SPI モード
						ff_serial_wdata 	<= SROM_CHIP_ERASE;
						ff_serial_write 	<= 1'b1;
						ff_serial_valid 	<= 1'b1;
						ff_cs_n				<= 1'b0;
					end
				end
				ST_FINISH: begin
					if( w_serial_idle ) begin
						ff_command_state	<= ST_IDLE;
						if( ff_command_mode == CMD_BURST_WRITE || ff_command_mode == CMD_BURST_READ || ff_command_mode == CMD_READ_STATUS ) begin
							//	これらのコマンドは、data port からのアクセスが続くので、ff_cs_n はアクティブのままにする。
						end
						else begin
							//	それ以外のコマンドは、ff_cs_n を非アクティブにする。
							ff_cs_n					<= 1'b1;
						end
					end
				end
				default: begin
					//	不正なコマンドの場合は IDLE へ戻す
					ff_command_state	<= ST_IDLE;
				end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	QSPI Controller
	// ---------------------------------------------------------
	qspi u_qspi (
		.reset				( reset					),
		.clk				( clk					),
		.clk_serial			( clk_serial			),
		.serial_mode		( ff_serial_mode		),
		.serial_wdata		( ff_serial_wdata		),
		.serial_write		( ff_serial_write		),
		.serial_valid		( ff_serial_valid		),
		.serial_ready		( w_serial_ready		),
		.serial_rdata		( w_serial_rdata		),
		.serial_rdata_en	( w_serial_rdata_en		),
		.serial_idle		( w_serial_idle			),
		.qspi_clk			( srom_clk				),
		.qspi_sio			( srom_sio				)
	);

	assign srom0_cs_n = ff_srom0_cs_n | ff_wait_count_active;
	assign srom1_cs_n = ff_srom1_cs_n | ff_wait_count_active;
endmodule
