// -----------------------------------------------------------------------------
//	Test of display_preload_buffer.v
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

`timescale 1ns/1ps

module tb ();
	// 66 MHz clock: half period ≈ 7.576 ns
	localparam		CLK_HALF_NS			= 8;		// 62.5 MHz (十分速い)
	localparam		FIFO_DEPTH			= 2048;		// SRAM0 + SRAM1 合計 (1024 + 1024)
	localparam		FIFO_USABLE_DEPTH	= FIFO_DEPTH - 1;	// リングFIFOの都合で1word未使用
	localparam		OUT_DEPTH			= FIFO_USABLE_DEPTH * 2;	// 32bit -> 16bit x2 出力
	localparam		NEARLY_FULL_SPACE	= 16;		// in_nearly_full を使用する前段が 1アクセスに要求するワード数

	// -----------------------------------------------------------------------
	//	DUT ポート
	// -----------------------------------------------------------------------
	reg				clk;
	reg				reset;

	reg		[31:0]	in_data;
	reg				in_valid;
	wire			in_ready;
	wire			in_nearly_full;

	wire	[15:0]	out_data;
	wire			out_valid;
	reg				out_ready;

	// -----------------------------------------------------------------------
	//	DUT インスタンス
	// -----------------------------------------------------------------------
	display_preload_buffer u_dut (
		.clk			( clk				),
		.reset			( reset				),
		.in_data		( in_data			),
		.in_valid		( in_valid			),
		.in_ready		( in_ready			),
		.in_nearly_full	( in_nearly_full	),
		.out_data		( out_data			),
		.out_valid		( out_valid			),
		.out_ready		( out_ready			)
	);

	// -----------------------------------------------------------------------
	//	クロック生成
	// -----------------------------------------------------------------------
	initial		clk = 1'b0;
	always		#(CLK_HALF_NS) clk = ~clk;

	// -----------------------------------------------------------------------
	//	エラーカウンタ / テスト管理
	// -----------------------------------------------------------------------
	int				error_count;
	int				test_number;

	function automatic [31:0] pack_word( input int word_index );
		logic [15:0] low16;
		logic [15:0] high16;
		// 32bit入力の下位16bitが先、上位16bitが後の順で出力される前提のデータ生成
		low16  = word_index * 2;
		high16 = word_index * 2 + 1;
		pack_word = { high16, low16 };
	endfunction

	// -----------------------------------------------------------------------
	//	タスク: FIFO への書き込み
	//	negedge で入力を安定化し、posedge でハンドシェイク成立を確認する
	// -----------------------------------------------------------------------
	task automatic write_words_to_fifo( input int word_count );
		int wr_cnt;
		begin
			wr_cnt = 0;
			in_valid <= 1'b0;
			while( wr_cnt < word_count ) begin
				@( negedge clk );
				in_data	 <= pack_word( wr_cnt );
				in_valid <= 1'b1;
				@( posedge clk );
				if( in_ready ) begin
					wr_cnt++;
				end
			end
			@( negedge clk );
			in_valid <= 1'b0;
		end
	endtask

	// -----------------------------------------------------------------------
	//	タスク: リセット
	// -----------------------------------------------------------------------
	task do_reset();
		reset		<= 1'b1;
		in_valid	<= 1'b0;
		in_data		<= 32'h0000_0000;
		out_ready	<= 1'b0;
		repeat( 10 ) @( posedge clk );
		@( posedge clk ) begin
			reset	<= 1'b0;
		end
	endtask

	// -----------------------------------------------------------------------
	//	タスク: ランダムフロー試験
	//	random_in_valid0=1: 入力 valid=0 をランダム挿入
	//	random_out_ready0=1: 出力 ready=0 をランダム挿入
	// -----------------------------------------------------------------------
	task automatic run_randomized_flow_test(
		input int tnum,
		input bit random_in_valid0,
		input bit random_out_ready0
	);
		int			wr_cnt;
		int			rd_cnt;
		int			timeout;
		int			max_timeout;
		logic [15:0]	expected;
		bit			preload_reported;
		begin
			test_number = tnum;
			$display("[TEST %0d] Random flow test (random_in_valid0=%0d, random_out_ready0=%0d)",
				test_number, random_in_valid0, random_out_ready0);

			do_reset();
			wr_cnt = 0;
			rd_cnt = 0;
			timeout = 0;
			max_timeout = OUT_DEPTH * 80;
			expected = 16'h0000;
			preload_reported = 1'b0;

			while( (rd_cnt < OUT_DEPTH) && (timeout < max_timeout) ) begin
				@( negedge clk );

				if( wr_cnt < FIFO_USABLE_DEPTH ) begin
					in_data <= pack_word( wr_cnt );
					if( random_in_valid0 && ($urandom_range(0, 3) == 0) ) begin
						in_valid <= 1'b0;
					end
					else begin
						in_valid <= 1'b1;
					end
				end
				else begin
					in_valid <= 1'b0;
				end

				if( random_out_ready0 && ($urandom_range(0, 4) == 0) ) begin
					out_ready <= 1'b0;
				end
				else begin
					out_ready <= 1'b1;
				end

				@( posedge clk );
				timeout++;

				if( in_valid && in_ready ) begin
					wr_cnt++;
					if( (wr_cnt == FIFO_USABLE_DEPTH) && !preload_reported ) begin
						$display("[PASS] TEST %0d: Passed preload phase.", test_number);
						preload_reported = 1'b1;
					end
				end

				if( out_valid && out_ready ) begin
					if( out_data !== expected ) begin
						if( error_count < 10 ) begin
							$display("[FAIL] TEST %0d: rd[%0d] expected=0x%04X got=0x%04X",
								test_number, rd_cnt, expected, out_data);
						end
						error_count++;
					end
					expected = expected + 16'd1;
					rd_cnt++;
				end
			end

			in_valid = 1'b0;
			out_ready = 1'b0;

			if( wr_cnt != FIFO_USABLE_DEPTH ) begin
				$display("[FAIL] TEST %0d: write timeout wr_cnt=%0d/%0d",
					test_number, wr_cnt, FIFO_USABLE_DEPTH);
				error_count++;
			end
			if( rd_cnt != OUT_DEPTH ) begin
				$display("[FAIL] TEST %0d: read timeout rd_cnt=%0d/%0d",
					test_number, rd_cnt, OUT_DEPTH);
				error_count++;
			end
			if( (wr_cnt == FIFO_USABLE_DEPTH) && (rd_cnt == OUT_DEPTH) && (error_count == 0) ) begin
				$display("[PASS] TEST %0d: Random flow verified (%0d/%0d transferred)",
					test_number, rd_cnt, OUT_DEPTH);
			end
		end
	endtask

	// -----------------------------------------------------------------------
	//	タスク: TEST9 専用
	//	0x0000〜0xFFFF を順次生成して 32bit (low16->high16) に詰める。
	//	書き込み側はランダムに in_valid=0 を挿入し、その間はインクリメント停止。
	//	読み出し側はランダムに out_ready=0 を挿入して停止させる。
	// -----------------------------------------------------------------------
	task automatic run_full_range_random_test( input int tnum );
		int			wr_word_cnt;
		int			rd_half_cnt;
		int			timeout;
		int			max_timeout;
		logic [15:0]	next_half;
		logic [15:0]	expected;
		logic [15:0]	wr_low;
		logic [15:0]	wr_high;
		begin
			test_number = tnum;
			$display("[TEST %0d] Full-range random flow test (0000h..FFFFh)", test_number);

			do_reset();
			wr_word_cnt = 0;
			rd_half_cnt = 0;
			timeout = 0;
			// ランダム停止を入れるため余裕を持ったタイムアウト
			max_timeout = 65536 * 64;
			next_half = 16'h0000;
			expected = 16'h0000;

			while( (rd_half_cnt < 65536) && (timeout < max_timeout) ) begin
				@( negedge clk );

				if( wr_word_cnt < 32768 ) begin
					wr_low = next_half;
					wr_high = next_half + 16'd1;
					in_data <= { wr_high, wr_low };
					if( $urandom_range(0, 3) == 0 ) begin
						in_valid <= 1'b0;
					end
					else begin
						in_valid <= 1'b1;
					end
				end
				else begin
					in_valid <= 1'b0;
				end

				if( $urandom_range(0, 4) == 0 ) begin
					out_ready <= 1'b0;
				end
				else begin
					out_ready <= 1'b1;
				end

				@( posedge clk );
				timeout++;

				if( in_valid && in_ready ) begin
					wr_word_cnt++;
					next_half = next_half + 16'd2;
				end

				if( out_valid && out_ready ) begin
					if( out_data !== expected ) begin
						if( error_count < 10 ) begin
							$display("[FAIL] TEST %0d: rd[%0d] expected=0x%04X got=0x%04X",
								test_number, rd_half_cnt, expected, out_data);
						end
						error_count++;
					end
					expected = expected + 16'd1;
					rd_half_cnt++;
				end
			end

			in_valid = 1'b0;
			out_ready = 1'b0;

			if( wr_word_cnt != 32768 ) begin
				$display("[FAIL] TEST %0d: write timeout wr_word_cnt=%0d/32768", test_number, wr_word_cnt);
				error_count++;
			end
			if( rd_half_cnt != 65536 ) begin
				$display("[FAIL] TEST %0d: read timeout rd_half_cnt=%0d/65536", test_number, rd_half_cnt);
				error_count++;
			end
			if( (wr_word_cnt == 32768) && (rd_half_cnt == 65536) ) begin
				$display("[PASS] TEST %0d: Full-range randomized transfer verified", test_number);
			end
		end
	endtask

	// -----------------------------------------------------------------------
	//	メインテスト
	// -----------------------------------------------------------------------
	initial begin
		error_count = 0;
		test_number = 0;

		// ===================================================================
		//	TEST 1: リセット後、FIFO 満タンになるまで out_valid = 0
		// ===================================================================
		test_number = 1;
		$display("[TEST %0d] Reset -> out_valid stays 0 until FIFO full", test_number);

		do_reset();
		out_ready = 1'b1;

		// FIFO が満タンになる前に out_valid が立つことがないかを確認しながら書き込む
		// FIFO_USABLE_DEPTH ワード受理で満タンになる
		fork
			// 書き込みスレッド
			begin : write_thread
				write_words_to_fifo( FIFO_USABLE_DEPTH );
			end
			// 監視スレッド: 満タン前に out_valid が立ったらエラー
			begin : monitor_thread
				int timeout;
				timeout = 0;
				while( (out_valid !== 1'b1) && (timeout < (FIFO_DEPTH * 8)) ) begin
					@( posedge clk );
					timeout++;
				end
				if( out_valid !== 1'b1 ) begin
					$display("[FAIL] TEST %0d: out_valid timeout before assertion", test_number);
					error_count++;
				end
				else if( u_dut.ff_initial_charge ) begin
					$display("[FAIL] TEST %0d: out_valid asserted before initial charge completed",
						test_number);
					error_count++;
				end
				else begin
					$display("[PASS] TEST %0d: out_valid asserted after initial charge completed",
						test_number);
				end
			end
		join

		repeat( 10 ) @( posedge clk );

		// ===================================================================
		//	TEST 2: データ順序の正確性確認
		//	FIFO に 32bit ワードを連番で書き込み、16bit 出力が
		//	low16 -> high16 の順で連番になるか確認
		// ===================================================================
		test_number = 2;
		$display("[TEST %0d] Data ordering check (32bit write, 16bit low/high read back)", test_number);

		do_reset();

		// FIFO を一度満タンにする
		write_words_to_fifo( FIFO_USABLE_DEPTH );
		$display( "[PASS] TEST %0d: Passed preload phase.", test_number );

		// 16bit 出力を順序確認
		begin
			int				rd_cnt;
			int				timeout;
			logic [15:0]	expected;
			rd_cnt	 = 0;
			timeout	 = 0;
			expected = 16'h0000;
			out_ready = 1'b1;
			while( (rd_cnt < OUT_DEPTH) && (timeout < (OUT_DEPTH * 8)) ) begin
				@( posedge clk );
				timeout++;
				if( out_valid && out_ready ) begin
					if( out_data !== expected ) begin
						if( error_count < 10 ) begin
							$display("[FAIL] TEST %0d: rd[%0d] expected=0x%04X got=0x%04X",
								test_number, rd_cnt, expected, out_data);
						end
						error_count++;
					end
					expected = expected + 16'd1;
					rd_cnt++;
				end
			end
			out_ready = 1'b0;
			if( rd_cnt != OUT_DEPTH ) begin
				$display("[FAIL] TEST %0d: read timeout rd_cnt=%0d/%0d", test_number, rd_cnt, OUT_DEPTH);
				error_count++;
			end
			if( error_count == 0 ) begin
				$display("[PASS] TEST %0d: All %0d halfwords in correct order", test_number, OUT_DEPTH);
			end
		end

		repeat( 10 ) @( posedge clk );

		// ===================================================================
		//	TEST 3: out_ready = 0 による出力一時停止
		//	FIFO を満タンにしてから、out_ready を数サイクル 0 にし、
		//	再開後もデータが継続して正しく出力されるか確認
		// ===================================================================
		test_number = 3;
		$display("[TEST %0d] out_ready=0 stall test", test_number);

		do_reset();

		// FIFO を一度満タンにして初期チャージ完了、その後読み出し
		write_words_to_fifo( FIFO_USABLE_DEPTH );
		$display( "[PASS] TEST %0d: Passed preload phase.", test_number );

		begin
			int			rd_cnt;
			int			stall_done;
			int			stall_count;
			logic [15:0]	expected;
			rd_cnt	 = 0;
			stall_done = 0;
			stall_count = 0;
			expected = 16'h0000;
			out_ready = 1'b1;

			while( rd_cnt < (OUT_DEPTH - (NEARLY_FULL_SPACE * 2)) ) begin
				@( posedge clk );

				if( out_valid && out_ready ) begin
					if( out_data !== expected ) begin
						if( error_count < 10 ) begin
							$display("[FAIL] TEST %0d: rd[%0d] expected=0x%04X got=0x%04X",
								test_number, rd_cnt, expected, out_data);
						end
						error_count++;
					end
					expected = expected + 16'd1;
					rd_cnt++;
				end

				if( (rd_cnt == 129) && (stall_done == 0) ) begin
					// 0x0080 受理後に 20 サイクルだけストールし、0x0081 が保持されることを確認
					stall_done = 1;
					stall_count = 20;
					out_ready = 1'b0;
				end

				if( stall_count > 0 ) begin
					if( out_valid !== 1'b1 ) begin
						$display("[FAIL] TEST %0d: out_valid dropped during out_ready=0 stall", test_number);
						error_count++;
					end
					stall_count--;
					if( stall_count == 1 ) begin
						out_ready = 1'b1;
					end
				end
			end
			out_ready = 1'b0;
			if( error_count == 0 ) begin
				$display("[PASS] TEST %0d: Stall/resume verified, read %0d halfwords correctly", test_number, OUT_DEPTH - (NEARLY_FULL_SPACE * 2));
			end
		end

		repeat( 10 ) @( posedge clk );

		// ===================================================================
		//	TEST 4: in_nearly_full 確認
		//	FIFO を 16word 未満の空きにすると in_nearly_full = 1 になるか確認
		// ===================================================================
		test_number = 4;
		$display("[TEST %0d] in_nearly_full assertion test", test_number);

		do_reset();
		out_ready = 1'b0;	// 読み出し停止してFIFOを溜める

		begin
			int		wr_cnt;
			int		nf_detected;
			nf_detected = 0;
			wr_cnt = 0;
			while( 1 ) begin
				@( posedge clk );
				if( in_ready ) begin
					in_data		= pack_word( wr_cnt );
					in_valid	= 1'b1;
					wr_cnt++;
				end
				// in_nearly_full が立ったことを検出
				if( in_nearly_full && nf_detected == 0 ) begin
					nf_detected = 1;
					if( u_dut.w_count > (FIFO_USABLE_DEPTH - NEARLY_FULL_SPACE) ) begin
						$display("[PASS] TEST %0d: in_nearly_full=1 at count=%0d (threshold=%0d)",
							test_number, u_dut.w_count, FIFO_USABLE_DEPTH - NEARLY_FULL_SPACE + 1);
					end
					else begin
						$display("[FAIL] TEST %0d: in_nearly_full=1 too early at count=%0d",
							test_number, u_dut.w_count);
						error_count++;
					end
					break;
				end
				// タイムアウト
				if( wr_cnt > FIFO_DEPTH + 10 ) begin
					$display("[FAIL] TEST %0d: in_nearly_full never asserted", test_number);
					error_count++;
					break;
				end
			end
			in_valid = 1'b0;
		end

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	TEST 5: in_ready バックプレッシャー確認
		//	FIFO が完全に満タン (w_full) になったとき in_ready = 0 になるか確認
		// ===================================================================
		test_number = 5;
		$display("[TEST %0d] in_ready backpressure test", test_number);

		do_reset();
		out_ready = 1'b0;	// 読み出し停止してFIFOを溜める

		begin
			int		wr_cnt;
			int		bp_detected;
			bp_detected = 0;
			wr_cnt = 0;
			while( 1 ) begin
				@( posedge clk );
				if( in_ready ) begin
					in_data		= pack_word( wr_cnt );
					in_valid	= 1'b1;
					wr_cnt++;
				end
				// in_ready が落ちたことを検出
				if( !in_ready && bp_detected == 0 ) begin
					bp_detected = 1;
					// このとき蓄積量が期待値（FIFO_DEPTH - 1 以上）かチェック
					if( u_dut.w_count >= FIFO_USABLE_DEPTH ) begin
						$display("[PASS] TEST %0d: in_ready=0 at count=%0d (FIFO full)",
							test_number, u_dut.w_count);
					end
					else begin
						$display("[FAIL] TEST %0d: in_ready=0 too early at count=%0d",
							test_number, u_dut.w_count);
						error_count++;
					end
					break;
				end
				// タイムアウト: 書き込みが FIFO_DEPTH を大幅に超えたら異常
				if( wr_cnt > FIFO_DEPTH + 10 ) begin
					$display("[FAIL] TEST %0d: in_ready never asserted 0", test_number);
					error_count++;
					break;
				end
			end
			in_valid = 1'b0;
		end

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	TEST 6: 入力 valid=0 ランダム挿入
		// ===================================================================
		run_randomized_flow_test( 6, 1'b1, 1'b0 );

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	TEST 7: 出力 ready=0 ランダム挿入
		// ===================================================================
		run_randomized_flow_test( 7, 1'b0, 1'b1 );

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	TEST 8: 入力 valid=0 / 出力 ready=0 ランダム挿入 (組み合わせ)
		// ===================================================================
		run_randomized_flow_test( 8, 1'b1, 1'b1 );

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	TEST 9: 0000h〜FFFFh フルレンジ + ランダム invalid / ready=0
		// ===================================================================
		run_full_range_random_test( 9 );

		repeat( 20 ) @( posedge clk );

		// ===================================================================
		//	テスト結果サマリ
		// ===================================================================
		$display("--------------------------------------------");
		if( error_count == 0 ) begin
			$display("ALL TESTS PASSED");
		end
		else begin
			$display("FAILED: %0d error(s)", error_count);
		end
		$display("--------------------------------------------");
		$finish;
	end

endmodule
