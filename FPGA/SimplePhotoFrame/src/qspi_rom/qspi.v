// -----------------------------------------------------------------------------
//	qspi.v
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
//		Quad SPI controller (mode0 only)
// -----------------------------------------------------------------------------

module qspi (
	input			reset,
	input			clk,				//	System Clock
	input			clk_serial,			//	Serial Clock source (2x of qspi_clk)
	//	internal interface (clk domain)
	input	[2:0]	serial_mode,
	input	[7:0]	serial_wdata,
	input			serial_write,
	input			serial_valid,
	output			serial_ready,
	output	[7:0]	serial_rdata,
	output			serial_rdata_en,
	output			serial_idle,
	//	QSPI interface
	output			qspi_clk,
	inout	[3:0]	qspi_sio
);
	// ---------------------------------------------------------
	//	serial_mode
	//		0: Standard SPI write
	//		1: Standard SPI read
	//		2: Quad SPI write
	//		3: Quad SPI read
	//		4: Quad SPI dummy clock
	//		5-7: Reserved
	//	note:
	//		Don't support Dual SPI read/write.
	// ---------------------------------------------------------
	localparam [2:0]	MODE_STD_WRITE	= 3'd0;
	localparam [2:0]	MODE_STD_READ	= 3'd1;
	localparam [2:0]	MODE_QUAD_WRITE	= 3'd2;
	localparam [2:0]	MODE_QUAD_READ	= 3'd3;
	localparam [2:0]	MODE_QUAD_DUMMY	= 3'd4;
	localparam [2:0] 	MODE_QUAD_DUMMY2	= 3'd5;
	//	clk domain
	reg		[2:0]	ff_fifo_mode;
	reg		[7:0]	ff_fifo_wdata;
	reg				ff_fifo_write;
	reg				ff_fifo_valid;		//	要求が溜まっている場合に 1
	reg		[2:0]	ff_serial_mode;
	reg		[7:0]	ff_serial_wdata;
	reg				ff_serial_write;
	reg				ff_serial_valid;	//	すぐ通信する内容がある場合に 1
	reg				ff_serial_ready;	//	次に通信する内容を受けられる場合に 1
	reg		[7:0]	ff_serial_rdata;
	reg				ff_serial_rdata_en;	//	受信データが有効なタイミングで 1
	reg				ff_serial_processing;
	reg				ff_serial_qspi_accepted;
	//	clk_serial domain
	localparam	[4:0]	ST_IDLE				= 5'd0;
	localparam	[4:0]	ST_STD_WRITE		= 5'd1;
	localparam	[4:0]	ST_STD_WRITE_CLK	= 5'd2;		//	クロック立ち上がり
	localparam	[4:0]	ST_STD_READ			= 5'd3;
	localparam	[4:0]	ST_STD_READ_CLK		= 5'd4;		//	クロック立ち上がり
	localparam	[4:0]	ST_STD_READ_LOOP	= 5'd5;		//	クロック立ち下がりで取り込み
	localparam	[4:0]	ST_QUAD_WRITE		= 5'd6;		//	Quad SPI write (1クロックで4bit送信)
	localparam	[4:0]	ST_QUAD_WRITE_B74RE	= 5'd7;		//	bit7-4 rise edge
	localparam	[4:0]	ST_QUAD_WRITE_B74FE	= 5'd8;		//	bit7-4 fall edge
	localparam	[4:0]	ST_QUAD_WRITE_B30RE	= 5'd9;		//	bit3-0 rise edge
	localparam	[4:0]	ST_QUAD_WRITE_B30FE	= 5'd10;	//	bit3-0 fall edge
	localparam	[4:0]	ST_QUAD_READ		= 5'd11;	//	Quad SPI read (1クロックで4bit受信)
	localparam	[4:0]	ST_QUAD_READ_B74RE	= 5'd12;	//	bit7-4 rise edge
	localparam	[4:0]	ST_QUAD_READ_B74FE	= 5'd13;	//	bit7-4 fall edge
	localparam	[4:0]	ST_QUAD_READ_B30RE	= 5'd14;	//	bit3-0 rise edge
	localparam	[4:0]	ST_QUAD_READ_B30FE	= 5'd15;	//	bit3-0 fall edge
	localparam	[4:0]	ST_QUAD_DUMMY		= 5'd16;	//	Quad SPI dummy clock
	localparam	[4:0]	ST_QUAD_DUMMY_CLK	= 5'd17;	//	Dummy clock上昇エッジ
	localparam	[4:0]	ST_QUAD_DUMMY2		= 5'd18;	//	Quad SPI dummy clock (2 bytes)
	localparam	[4:0]	ST_QUAD_DUMMY2_CLK	= 5'd19;	//	Dummy clock上昇エッジ (2 bytes)
	localparam	[4:0]	ST_FINISH			= 5'd20;	//	通信処理完了
	reg					ff_qspi_serial_valid0;			//	ff_serial_valid を clk_serial ドメインに載せ替え用
	reg					ff_qspi_serial_valid1;			//	ff_serial_valid を clk_serial ドメインに載せ替え用
	reg					ff_qspi_processing;
	reg			[4:0]	ff_qspi_state;
	reg			[2:0]	ff_qspi_substate;				//	ビット選択カウンター (0～7)
	reg					ff_qspi_clk;
	reg			[7:0]	ff_qspi_data;
	reg			[3:0]	ff_qspi_hiz;					//	qspi_sio を Hi-Z にするか (1: Hi-Z, 0: ドライブ)
	reg			[3:0]	ff_qspi_sio;
	reg			[7:0]	ff_qspi_rdata;

	// ---------------------------------------------------------
	//	要求を受け付ける処理 (1要求分貯めておくバッファ)
	// ---------------------------------------------------------
	always @(posedge clk) begin
		if( reset ) begin
			ff_fifo_mode	<= 3'd0;
			ff_fifo_wdata	<= 8'd0;
			ff_fifo_write	<= 1'b0;
			ff_fifo_valid	<= 1'b0;
		end 
		else if( !ff_fifo_valid ) begin
			if( serial_valid ) begin
				//	要求された内容を記憶する
				ff_fifo_mode	<= serial_mode;
				ff_fifo_wdata	<= serial_wdata;
				ff_fifo_write	<= serial_write;
				ff_fifo_valid	<= 1'b1;
			end 
		end
		else begin
			if( !ff_serial_valid && ff_serial_ready ) begin
				//	要求がなくなったら、次の要求を受け付ける準備をする
				ff_fifo_valid <= 1'b0;
			end
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_serial_mode	<= 3'd0;
			ff_serial_wdata	<= 8'd0;
			ff_serial_write	<= 1'b0;
			ff_serial_valid	<= 1'b0;
		end 
		else if( !ff_serial_valid ) begin
			if( ff_fifo_valid && ff_serial_ready ) begin
				//	要求された内容を記憶する
				ff_serial_mode	<= ff_fifo_mode;
				ff_serial_wdata	<= ff_fifo_wdata;
				ff_serial_write	<= ff_fifo_write;
				ff_serial_valid	<= 1'b1;
			end 
		end
		else begin
			if( ff_serial_qspi_accepted ) begin
				//	通信要求が受理されたら、受理された要求を消去する
				ff_serial_valid <= 1'b0;
			end
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_serial_ready <= 1'b1;
		end
		else if( ff_serial_ready ) begin
			if( ff_fifo_valid ) begin
				//	要求があって、通信可能な状態であれば、通信要求を受け付ける
				ff_serial_ready <= 1'b0;
			end
		end
		else begin
			//	通信完了したタイミングで、ready に戻す
			if( !ff_serial_valid && !ff_serial_qspi_accepted ) begin
				ff_serial_ready <= 1'b1;
			end
		end
	end

	always @(posedge clk) begin
		if( reset ) begin
			ff_serial_processing		<= 1'b0;
			ff_serial_qspi_accepted		<= 1'b0;
		end
		else begin
			//	クロック載せ替え
			ff_serial_processing		<= ff_qspi_processing;
			ff_serial_qspi_accepted		<= ff_serial_processing;
		end
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_serial_rdata		<= 8'd0;
			ff_serial_rdata_en	<= 1'b0;
		end
		else if( !ff_serial_processing && ff_serial_qspi_accepted ) begin
			//	通信要求が受理されたタイミングで、受信データを出力する
			ff_serial_rdata		<= ff_qspi_rdata;
			ff_serial_rdata_en	<= ~ff_serial_write;
		end
		else begin
			ff_serial_rdata_en	<= 1'b0;
		end
	end

	assign serial_ready		= !ff_fifo_valid;
	assign serial_rdata		= ff_serial_rdata;
	assign serial_rdata_en	= ff_serial_rdata_en;

	// ---------------------------------------------------------
	//	QSPI 通信の要求受付（クロック載せ替え）
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_serial_valid0 <= 1'b0;
			ff_qspi_serial_valid1 <= 1'b0;
		end
		else begin
			ff_qspi_serial_valid0 <= ff_serial_valid;
			ff_qspi_serial_valid1 <= ff_qspi_serial_valid0;
		end
	end

	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_processing <= 1'b0;
		end
		else if( !ff_qspi_processing ) begin
			//	通信停止中であれば、要求があるか調べる
			if( ff_qspi_serial_valid1 ) begin
				//	要求があれば通信開始する
				ff_qspi_processing <= 1'b1;
			end
		end
		else begin
			//	通信中であれば、通信処理が完了したか調べる
			if( ff_qspi_state == ST_FINISH ) begin
				//	通信が完了したら、通信停止状態に戻る
				ff_qspi_processing <= 1'b0;
			end
		end
	end

	// ---------------------------------------------------------
	//	QSPI 通信の処理
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_state	<= ST_IDLE;
			ff_qspi_substate <= 3'd0;
			ff_qspi_clk		<= 1'b0;		//	SPI mode0 only
			ff_qspi_data	<= 8'd0;
			ff_qspi_hiz		<= 4'b1111;		//	全て Hi-Z
			ff_qspi_sio		<= 4'b0000;
		end
		else if( ff_qspi_processing ) begin
			case( ff_qspi_state )
				ST_IDLE: begin
					case( ff_serial_mode )
						MODE_STD_WRITE: begin
							//	Standard SPI write
							ff_qspi_state		<= ST_STD_WRITE;
							ff_qspi_clk			<= 1'b0;
							ff_qspi_data		<= ff_serial_wdata;
							ff_qspi_substate	<= 3'd7;
						end
						MODE_STD_READ: begin
							//	Standard SPI read
							ff_qspi_state		<= ST_STD_READ;
							ff_qspi_clk			<= 1'b0;
							ff_qspi_substate	<= 3'd7;
						end
						MODE_QUAD_WRITE: begin
							//	Quad SPI write
							ff_qspi_state	<= ST_QUAD_WRITE;
							ff_qspi_clk		<= 1'b0;
							ff_qspi_data	<= ff_serial_wdata;
						end
						MODE_QUAD_READ: begin
							//	Quad SPI read
							ff_qspi_state	<= ST_QUAD_READ;
							ff_qspi_clk		<= 1'b0;
						end
						MODE_QUAD_DUMMY: begin
							//	Quad SPI dummy clock
							ff_qspi_state		<= ST_QUAD_DUMMY;
							ff_qspi_clk			<= 1'b0;
							ff_qspi_substate	<= 3'd7;
						end
						MODE_QUAD_DUMMY2: begin
							//	Quad SPI dummy clock (2 bytes)
							ff_qspi_state		<= ST_QUAD_DUMMY2;
							ff_qspi_clk			<= 1'b0;
							ff_qspi_substate	<= 3'd4;
						end
						default: begin
							//	Reserved
							ff_qspi_state	<= ST_FINISH;
							ff_qspi_clk		<= 1'b0;
						end
					endcase
				end
				// ---------------------------------------------------------
				//	standard SPI write の処理 (ビット選択ループ版)
				// ---------------------------------------------------------
				ST_STD_WRITE: begin
					//	bit7からbit0を順に送信
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio[0]	<= ff_qspi_data[ff_qspi_substate];
					ff_qspi_hiz		<= 4'b1110;		//	ドライブ
					ff_qspi_state	<= ST_STD_WRITE_CLK;
				end
				ST_STD_WRITE_CLK: begin
					//	クロックパルス生成
					ff_qspi_clk		<= 1'b1;
					if( ff_qspi_substate != 3'd0 ) begin
						ff_qspi_state		<= ST_STD_WRITE;
						ff_qspi_substate	<= ff_qspi_substate - 3'd1;
					end
					else begin
						ff_qspi_state	<= ST_FINISH;
					end
				end
				// ---------------------------------------------------------
				//	standard SPI read の処理 (ビット選択ループ版)
				// ---------------------------------------------------------
				ST_STD_READ: begin
					//	bit7からbit0を順に受信
					ff_qspi_clk		<= 1'b0;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_STD_READ_CLK;
				end
				ST_STD_READ_CLK: begin
					//	クロック立ち上がり
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_STD_READ_LOOP;
				end
				ST_STD_READ_LOOP: begin
					//	クロック立ち下がりで受信したビットを保存
					ff_qspi_clk		<= 1'b0;
					ff_qspi_data[ff_qspi_substate] <= qspi_sio[1];
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					if( ff_qspi_substate != 3'd0 ) begin
						ff_qspi_substate	<= ff_qspi_substate - 3'd1;
						ff_qspi_state		<= ST_STD_READ_CLK;
					end
					else begin
						ff_qspi_state	<= ST_FINISH;
					end
				end
				// ---------------------------------------------------------
				//	Quad SPI write の処理
				// ---------------------------------------------------------
				ST_QUAD_WRITE: begin
					//	bit7-4
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio		<= ff_qspi_data[7:4];
					ff_qspi_hiz		<= 4'b0000;		//	ドライブ
					ff_qspi_state	<= ST_QUAD_WRITE_B74RE;
				end
				ST_QUAD_WRITE_B74RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_QUAD_WRITE_B74FE;
				end
				ST_QUAD_WRITE_B74FE: begin
					ff_qspi_sio		<= ff_qspi_data[3:0];
					ff_qspi_clk		<= 1'b0;
					ff_qspi_state	<= ST_QUAD_WRITE_B30RE;
				end
				ST_QUAD_WRITE_B30RE: begin
					ff_qspi_clk		<= 1'b1;
					ff_qspi_state	<= ST_QUAD_WRITE_B30FE;
				end
				ST_QUAD_WRITE_B30FE: begin
					ff_qspi_clk		<= 1'b0;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	Quad SPI read の処理
				// ---------------------------------------------------------
				ST_QUAD_READ: begin
					//	bit7-4
					ff_qspi_clk			<= 1'b0;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_state		<= ST_QUAD_READ_B74RE;
				end
				ST_QUAD_READ_B74RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_READ_B74FE;
				end
				ST_QUAD_READ_B74FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_data[7:4]	<= qspi_sio;
					ff_qspi_state		<= ST_QUAD_READ_B30RE;
				end
				ST_QUAD_READ_B30RE: begin
					ff_qspi_clk			<= 1'b1;
					ff_qspi_state		<= ST_QUAD_READ_B30FE;
				end
				ST_QUAD_READ_B30FE: begin
					ff_qspi_clk			<= 1'b0;
					ff_qspi_data[3:0]	<= qspi_sio;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_state		<= ST_FINISH;
				end
				// ---------------------------------------------------------
				//	Quad SPI dummy の処理 (ビット選択ループ版)
				// ---------------------------------------------------------
				ST_QUAD_DUMMY: begin
					//	6クロック分のダミーパルスを生成 (3byte分)
					ff_qspi_clk			<= 1'b0;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_sio			<= 4'b0000;
					ff_qspi_substate	<= 3'd6;
					ff_qspi_state		<= ST_QUAD_DUMMY_CLK;
				end
				ST_QUAD_DUMMY_CLK: begin
					//	Dummy中は常にHi-Z維持
					ff_qspi_hiz			<= 4'b1111;
					ff_qspi_sio			<= 4'b0000;
					if( ff_qspi_clk == 1'b0 ) begin
						//	立ち上がりエッジ
						ff_qspi_clk			<= 1'b1;
					end
					else begin
						//	立ち下がりエッジ
						ff_qspi_clk			<= 1'b0;
						if( ff_qspi_substate != 3'd1 ) begin
							ff_qspi_substate	<= ff_qspi_substate - 3'd1;
						end
						else begin
							ff_qspi_state		<= ST_FINISH;
						end
					end
				end
				ST_QUAD_DUMMY2: begin
					//	4クロック分のダミーパルスを生成 (2byte分)
					ff_qspi_clk			<= 1'b0;
					ff_qspi_hiz			<= 4'b1111;		//	Hi-Z
					ff_qspi_sio			<= 4'b0000;
					ff_qspi_substate	<= 3'd4;
					ff_qspi_state		<= ST_QUAD_DUMMY2_CLK;
				end
				ST_QUAD_DUMMY2_CLK: begin
					//	Dummy中は常にHi-Z維持
					ff_qspi_hiz			<= 4'b1111;
					ff_qspi_sio			<= 4'b0000;
					if( ff_qspi_clk == 1'b0 ) begin
						ff_qspi_clk			<= 1'b1;
					end
					else begin
						ff_qspi_clk			<= 1'b0;
						if( ff_qspi_substate != 3'd1 ) begin
							ff_qspi_substate	<= ff_qspi_substate - 3'd1;
						end
						else begin
							ff_qspi_state		<= ST_FINISH;
						end
					end
				end
				// ---------------------------------------------------------
				//	通信完了処理
				// ---------------------------------------------------------
				ST_FINISH: begin
					//	通信完了処理 (次の通信要求を受け付けるための状態に遷移するなど)
					ff_qspi_clk		<= 1'b0;
					ff_qspi_sio		<= 4'b0000;
					ff_qspi_hiz		<= 4'b1111;		//	Hi-Z
					ff_qspi_state	<= ST_IDLE;
				end
				default: begin
				end
			endcase
		end
		else begin
			ff_qspi_state		<= ST_IDLE;
			ff_qspi_substate	<= 3'd0;
			ff_qspi_clk			<= 1'b0;		//	SPI mode0 only
		end
	end

	always @( posedge clk_serial ) begin
		if( reset ) begin
			ff_qspi_rdata	<= 8'd0;
		end
		else if( ff_qspi_processing ) begin
			if( ff_qspi_state == ST_FINISH ) begin
				//	通信が完了したタイミングで、受信データを clk ドメインに渡す
				ff_qspi_rdata	<= ff_qspi_data;
			end
		end
	end

	assign qspi_clk		= ff_qspi_clk;
	assign qspi_sio[0]	= ff_qspi_hiz[0] ? 1'bz : ff_qspi_sio[0];
	assign qspi_sio[1]	= ff_qspi_hiz[1] ? 1'bz : ff_qspi_sio[1];
	assign qspi_sio[2]	= ff_qspi_hiz[2] ? 1'bz : ff_qspi_sio[2];
	assign qspi_sio[3]	= ff_qspi_hiz[3] ? 1'bz : ff_qspi_sio[3];
	assign serial_idle	= ff_serial_ready & !ff_fifo_valid;
endmodule
