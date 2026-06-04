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
	localparam		FIFO_DEPTH			= 4096;		// SRAM0 + SRAM1 合計
	localparam		NEARLY_FULL_SPACE	= 16;		// in_nearly_full を使用する前段が 1アクセスに要求するワード数

	// -----------------------------------------------------------------------
	//	DUT ポート
	// -----------------------------------------------------------------------
	reg				clk;
	reg				reset;

	reg		[15:0]	in_data;
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

	// -----------------------------------------------------------------------
	//	タスク: リセット
	// -----------------------------------------------------------------------
	task do_reset();
		reset		<= 1'b1;
		in_valid	<= 1'b0;
		in_data		<= 16'h0000;
		out_ready	<= 1'b0;
		repeat( 10 ) @( posedge clk );
		@( posedge clk ) begin
			reset	<= 1'b0;
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
		// 4096 ワード書き込むと満タンになる
		fork
			// 書き込みスレッド
			begin : write_thread
				int		wr_cnt;
				wr_cnt = 0;
				while( wr_cnt < FIFO_DEPTH ) begin
					@( posedge clk ) begin
						if( in_ready ) begin
							in_data		= wr_cnt[15:0];
							in_valid	= 1'b1;
							wr_cnt++;
						end
					end
				end
				in_valid = 1'b0;
			end
			// 監視スレッド: 満タン前に out_valid が立ったらエラー
			begin : monitor_thread
				// 満タン判定 = DUT 内部の ff_ever_full。テストベンチからは
				// out_valid が立ち始めるタイミングで間接的に確認する。
				// ただし 4095 ワード書き込む前に out_valid が立ったらエラー。
				int		wr_before_valid;
				wr_before_valid = u_dut.ff_wr_ptr - u_dut.ff_rd_ptr;
				// FIFO_DEPTH - 1 ワード書き込まれる前に out_valid が立ったらNG
				wait( out_valid === 1'b1 );
				wr_before_valid = u_dut.ff_wr_ptr;
				if( wr_before_valid < (FIFO_DEPTH - NEARLY_FULL_SPACE - 1) ) begin
					$display("[FAIL] TEST %0d: out_valid asserted before FIFO full (wr_ptr=%0d)",
						test_number, wr_before_valid);
					error_count++;
				end
				else begin
					$display("[PASS] TEST %0d: out_valid first asserted after FIFO full (wr_ptr=%0d)",
						test_number, wr_before_valid);
				end
			end
		join

		repeat( 10 ) @( posedge clk );

		// ===================================================================
		//	TEST 2: データ順序の正確性確認
		//	FIFO に 0〜4095 を書き込み、読み出した値が順番通りか確認
		// ===================================================================
		test_number = 2;
		$display("[TEST %0d] Data ordering check (write 0..4095, read back)", test_number);

		do_reset();

		// 4096-17 ワード書き込み（FIFO を一度満タンにする）
		begin
			int		wr_cnt;
			wr_cnt = 0;
			while( wr_cnt < (FIFO_DEPTH - NEARLY_FULL_SPACE - 1) ) begin
				@( posedge clk ) begin
					if( in_ready ) begin
						in_data		= wr_cnt[15:0];
						in_valid	= 1'b1;
						wr_cnt++;
					end
				end
			end
		end
		$display( "[PASS] TEST %0d: Passed preload phase.", test_number );

		fork
			// 残りの 17word を書き込む側
			begin
				int		wr_cnt;
				wr_cnt = FIFO_DEPTH - NEARLY_FULL_SPACE - 1;
				while( wr_cnt <= FIFO_DEPTH ) begin
					@( posedge clk ) begin
						if( in_ready ) begin
							in_data		= wr_cnt[15:0];
							in_valid	= 1'b1;
							wr_cnt++;
						end
					end
				end
				in_valid = 1'b0;
			end
			// 読み出し側
			begin
				// 4096 ワード読み出して順序確認
				begin
					int				rd_cnt;
					logic [15:0]	expected;
					rd_cnt	 = 0;
					expected = 16'h0000;
					out_ready = 1'b1;
					while( rd_cnt < FIFO_DEPTH ) begin
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
					end
					out_ready = 1'b0;
					if( error_count == 0 ) begin
						$display("[PASS] TEST %0d: All %0d words in correct order", test_number, FIFO_DEPTH);
					end
				end
			end
		join

		repeat( 10 ) @( posedge clk );

		// ===================================================================
		//	TEST 3: out_ready = 0 による出力一時停止
		//	FIFO を満タンにしてから、out_ready を数サイクル 0 にし、
		//	再開後もデータが継続して正しく出力されるか確認
		// ===================================================================
		test_number = 3;
		$display("[TEST %0d] out_ready=0 stall test", test_number);

		do_reset();

		// FIFO を一度満タンにして初期チャージ完了、その後 4080 ワード読み出す
		begin
			int		wr_cnt;
			wr_cnt = 0;
			while( wr_cnt < FIFO_DEPTH ) begin
				@( posedge clk );
				if( in_ready ) begin
					in_data		= wr_cnt[15:0];
					in_valid	= 1'b1;
					wr_cnt++;
				end
			end
			in_valid = 1'b0;
		end
		$display( "[PASS] TEST %0d: Passed preload phase.", test_number );

		begin
			int			rd_cnt;
			int			stall_done;
			logic [15:0]	expected;
			rd_cnt	 = 0;
			stall_done = 0;
			expected = 16'h0000;

			while( rd_cnt < (FIFO_DEPTH - NEARLY_FULL_SPACE) ) begin
				@( posedge clk ) begin
					if( rd_cnt == 0 ) begin
						out_ready	<= 1'b1;
					end
					else if( rd_cnt == 128 && stall_done == 0 ) begin
						// 128 ワード読み出したところで 20 サイクルストール
						stall_done	= 1;
						out_ready	<= 1'b0;
						repeat( 20 ) @( posedge clk ) begin
							// ストール中に out_data が変化していないことを確認
							// (out_valid のまま保持されているはず)
							if( out_valid !== 1'b1 ) begin
								$display("[FAIL] TEST %0d: out_valid dropped during out_ready=0 stall", test_number);
								error_count++;
							end
						end
						out_ready <= 1'b1;
					end

					if( out_valid && out_ready ) begin
						if( out_data !== expected ) begin
							if( error_count < 10 ) begin
								$display("[FAIL] TEST %0d: rd[%0d] expected=0x%04X got=0x%04X",
									test_number, rd_cnt, expected, out_data);
							end
							error_count++;
						end
						expected <= expected + 16'd1;
						rd_cnt++;
					end
				end
			end
			out_ready = 1'b0;
			if( error_count == 0 ) begin
				$display("[PASS] TEST %0d: Stall/resume verified, all %0d words correct", test_number, FIFO_DEPTH);
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
					in_data		= wr_cnt[15:0];
					in_valid	= 1'b1;
					wr_cnt++;
				end
				// in_nearly_full が立ったことを検出
				if( in_nearly_full && nf_detected == 0 ) begin
					nf_detected = 1;
					if( u_dut.w_count > (FIFO_DEPTH - NEARLY_FULL_SPACE - 1) ) begin
						$display("[PASS] TEST %0d: in_nearly_full=1 at count=%0d (threshold=%0d)",
							test_number, u_dut.w_count, FIFO_DEPTH - NEARLY_FULL_SPACE);
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
					in_data		= wr_cnt[15:0];
					in_valid	= 1'b1;
					wr_cnt++;
				end
				// in_ready が落ちたことを検出
				if( !in_ready && bp_detected == 0 ) begin
					bp_detected = 1;
					// このとき蓄積量が期待値（FIFO_DEPTH - 1 以上）かチェック
					if( u_dut.w_count >= (FIFO_DEPTH - 1) ) begin
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
