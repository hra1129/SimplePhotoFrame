//
// preload_buffer.v
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

module preload_buffer (
	input			clk,
	input			reset,
	//	DRAM からくるデータを受けるポート
	input	[15:0]	in_data,
	input			in_valid,
	output			in_ready,
	output			in_nearly_full,
	//	表示コントローラにデータを渡すポート
	output	[15:0]	out_data,
	output			out_valid,
	input			out_ready
);
	// -------------------------------------------------------------------------
	//	書き込みポインタ / 読み出しポインタ
	//	bit[11:1]: SRAM アドレス, bit[0]: SRAM0/1 選択
	// -------------------------------------------------------------------------
	reg		[11:0]	ff_wr_ptr;					// {wrap, addr[10:0]}　偶奇で SRAM0/1 を選択
	reg		[11:0]	ff_rd_ptr;					// 同上

	// wr_ptr は SRAM0/1 を交互にカウント → 合計インデックス
	// 偶数インデックス → SRAM0、奇数インデックス → SRAM1
	// addr[10:0] = インデックス >> 1
	wire	[11:0]	w_wr_ptr_next	= (ff_wr_ptr == 12'd4095) ? 12'd0 : ff_wr_ptr + 12'd1;
	wire	[11:0]	w_rd_ptr_next	= (ff_rd_ptr == 12'd4095) ? 12'd0 : ff_rd_ptr + 12'd1;

	// wr_ptr と rd_ptr の差分 = 蓄積ワード数
	// 差分計算は 12bit の符号なし減算（ラップアラウンド考慮）
	// wr_ptr の指すアドレスは次に書く場所であり、まだデータは存在していない。
	// rd_ptr の指すアドレスは次に読む場所であり、データが存在している。
	// 引き算した結果がそのまま蓄積されている数と一致する。
	// ただし、wr_ptr = 10, rd_ptr = 4000 の循環点をまたぐケースもあるため、
	// 符号なしの引き算で求めて桁借りビットを捨てる。
	// 0～4095 の値しか取り得ないため、SRAM の 1word は必ず未使用となる。
	wire	[11:0]	w_count			= ff_wr_ptr - ff_rd_ptr;	// 自動ラップ

	// DRAM に対する1アクセス分を確実に保持できる空きがなければ in_ready = 0 にして 
	// DRAM への要求を止める。4095個の値までしか蓄積できないため、１アクセス = 16word の
	// 空き容量チェックは、蓄積数が 4095 - 16 = 4079 より多いなら、
	// 空き容量が足りないことになる。
	// DRAM にリクエストを発行するモジュールにはこれを通知する。
	wire			w_nearly_full	= (w_count > 12'd4079);

	// 本来の FIFO FULL 信号。in_ready はこれを使って制御。
	wire			w_full			= (w_count == 12'd4095);

	// -------------------------------------------------------------------------
	// 初期チャージフラグ
	// 後段の timming_generator が「安定して一定速度の出力」を維持できるように、
	// 不安定な DRAM を先行して読み込んでおくのがこのモジュールの役割である。
	// 起動時は、真っ先に満タンまで蓄積しておき、空きができたら続きを読む動作とする。
	// 後段の方が遅いため、蓄積済みのデータを後段が少しずつ消費していくことで
	// 後段にとって「データがない状態」にならない状況を維持する。
	// そのための「起動時の満タンまで蓄積」の間だけ、後段には待ってもらう必要がある。
	// 待ってもらうステートであることを示すフラグが ff_initial_charge である。
	// -------------------------------------------------------------------------
	reg				ff_initial_charge;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_initial_charge <= 1'b1;
		end
		else if( w_full ) begin
			// 空き容量がなくなったら、初期チャージは完了
			ff_initial_charge <= 1'b0;
		end
	end

	// -------------------------------------------------------------------------
	//	in_ready
	// -------------------------------------------------------------------------
	wire	w_in_ready			= ~w_full;
	assign	in_ready 			= w_in_ready;
	assign	in_nearly_full		= w_nearly_full;

	// -------------------------------------------------------------------------
	//	SRAM 書き込み制御
	// -------------------------------------------------------------------------
	wire			w_wr_en			= in_valid & w_in_ready;
	wire			w_wr_sram_sel	= ff_wr_ptr[0];		// 0: SRAM0, 1: SRAM1
	wire	[10:0]	w_wr_addr		= ff_wr_ptr[11:1];

	wire			w_sram0_we		= w_wr_en & ~w_wr_sram_sel;
	wire			w_sram1_we		= w_wr_en &  w_wr_sram_sel;

	always @( posedge clk ) begin
		if( reset ) begin
			ff_wr_ptr <= 12'd0;
		end
		else if( w_wr_en ) begin
			ff_wr_ptr <= w_wr_ptr_next;
		end
	end

	// -------------------------------------------------------------------------
	//	SRAM 読み出し制御
	//	single_port_ram は同一サイクルで address を与えると次クロックに dout が出る。
	//	そのため、読み出しは「advance read」方式:
	//	  - out_ready または出力パイプラインが空のとき、rd_ptr を進めて先読みする
	// -------------------------------------------------------------------------

	// 読み出しパイプライン Stage1 (SRAM の1クロック遅延吸収)
	reg				ff_pipe_valid;		// Stage1: SRAM 読み出し発行済みフラグ
	reg				ff_pipe_sram_sel;	// Stage1: どちらの SRAM の dout を使うか

	// SRAM 受け FF: SRAM の dout を登録する段
	// out_ready = 0 のときはここでデータを保持する
	reg		[15:0]	ff_sram_data;
	reg				ff_sram_valid;

	// FIFO-FF: out_ready = 0 のストール中に Stage1 のデータが到着した場合の退避バッファ
	reg		[15:0]	ff_fifo_data;
	reg				ff_fifo_valid;

	wire			w_rd_sram_sel	= ff_rd_ptr[0];
	wire	[10:0]	w_rd_addr		= ff_rd_ptr[11:1];

	// 読み出し可能 = データが存在 & 初期チャージ完了
	wire			w_data_exist	= (w_count != 12'd0) & ~ff_initial_charge;

	// SRAM リードを発行できる条件（プリフェッチ方式）:
	//   ・データが存在する & 初期チャージ完了
	//   ・Stage1 が空き（前のリードが完了している）
	//   ・FIFO-FF が空き（FIFO-FF が埋まっていたらこれ以上読めない）
	//   ※ out_ready は条件に含めない。プリフェッチして出力パイプラインを常に満たす。
	wire			w_sram_consumed	= out_ready & ff_sram_valid & ~ff_fifo_valid;
	wire			w_do_read_req	= w_data_exist & ~ff_pipe_valid & ~ff_fifo_valid;

	// 書き込みと読み出しが同一 SRAM に対して同時に発生する場合はコンフリクト
	// 書き込みを優先し、読み出しを1サイクル待機させる
	wire			w_sram_conflict	= w_wr_en & w_do_read_req & (w_wr_sram_sel == w_rd_sram_sel);

	wire			w_do_read		= w_do_read_req & ~w_sram_conflict;

	// Stage1 制御
	always @( posedge clk ) begin
		if( reset ) begin
			ff_rd_ptr		<= 12'd0;
			ff_pipe_valid	<= 1'b0;
			ff_pipe_sram_sel<= 1'b0;
		end
		else begin
			if( w_do_read ) begin
				ff_rd_ptr		<= w_rd_ptr_next;
				ff_pipe_valid	<= 1'b1;
				ff_pipe_sram_sel<= w_rd_sram_sel;
			end
			else if( ff_pipe_valid ) begin
				// SRAM dout 到着 → SRAM 受け FF へ転送したので Stage1 をクリア
				// (w_sram_free が保証されているため上書き衝突なし)
				ff_pipe_valid	<= 1'b0;
			end
		end
	end

	// -------------------------------------------------------------------------
	//	SRAM インスタンス
	// -------------------------------------------------------------------------
	wire	[15:0]	w_sram0_dout;
	wire	[15:0]	w_sram1_dout;

	// 書き込みと読み出しで同時アクセスが起きる場合、書き込み側を優先 (we=1 で書き込み)
	// 読み出しアドレスは w_rd_addr を使用
	// SRAM0 のアドレス: 書き込み中は w_wr_addr、それ以外は w_rd_addr
	// ただし single_port_ram は1ポートのため、書き込みと読み出しを同時には行えない。
	// 本設計では SRAM0/1 が交互に書き込まれるため、書き込み時はもう一方のSRAMで読み出し可能。
	// 同一 SRAM に同一サイクルで書き込みと読み出しが重なるケースは稀だが、
	// 書き込み優先（we=1 のとき書き込みアドレスを使用）とする。

	wire	[10:0]	w_sram0_addr	= w_sram0_we ? w_wr_addr : w_rd_addr;
	wire	[10:0]	w_sram1_addr	= w_sram1_we ? w_wr_addr : w_rd_addr;

	single_port_ram u_sram0 (
		.clk		( clk			),
		.we			( w_sram0_we	),
		.address	( w_sram0_addr	),
		.din		( in_data		),
		.dout		( w_sram0_dout	)
	);

	single_port_ram u_sram1 (
		.clk		( clk			),
		.we			( w_sram1_we	),
		.address	( w_sram1_addr	),
		.din		( in_data		),
		.dout		( w_sram1_dout	)
	);

	// -------------------------------------------------------------------------
	//	SRAM 出力マルチプレクサ
	// -------------------------------------------------------------------------
	wire	[15:0]	w_sram_dout	= ff_pipe_sram_sel ? w_sram1_dout : w_sram0_dout;

	// -------------------------------------------------------------------------
	//	SRAM 受け FF / FIFO-FF 制御
	//
	//	【不変条件】
	//	  w_do_read を発行するのは ~ff_pipe_valid & ~ff_fifo_valid のときのみ。
	//	  ff_pipe_valid=1 のサイクルに ff_sram_valid=1 が残っている場合:
	//	    - out_ready=1 → w_sram_consumed=1、古いデータ消費と同時に新データ上書き (gap なし)
	//	    - out_ready=0 → FIFO-FF が空（発行条件より保証）なので ff_sram_data を FIFO-FF に退避、
	//	                     ff_sram_data に新データを格納
	//
	//	【FIFO-FF の役割】
	//	  out_ready=0 ストール中にプリフェッチデータが到着したとき、古い ff_sram_data を一時退避する。
	//	  FIFO-FF が埋まっている間はリードを発行しないため、オーバーフローは起きない。
	// -------------------------------------------------------------------------

	// SRAM 受け FF 更新
	always @( posedge clk ) begin
		if( reset ) begin
			ff_sram_data	<= 16'd0;
			ff_sram_valid	<= 1'b0;
		end
		else begin
			if( ff_pipe_valid ) begin
				// Stage1 のリード結果が到着 → SRAM 受け FF に登録
				// ff_sram_valid=1 かつ out_ready=0 の場合は FIFO-FF ブロックが先に ff_sram_data を退避済み
				ff_sram_data	<= w_sram_dout;
				ff_sram_valid	<= 1'b1;
			end
			else if( w_sram_consumed ) begin
				// 下流に消費された
				ff_sram_valid	<= 1'b0;
			end
		end
	end

	// FIFO-FF 更新
	// ff_pipe_valid=1 到着時に ff_sram_valid=1 かつ消費できない（out_ready=0）場合に
	// 古い ff_sram_data を退避する。発行条件（~ff_fifo_valid）により空きが保証されている。
	always @( posedge clk ) begin
		if( reset ) begin
			ff_fifo_data	<= 16'd0;
			ff_fifo_valid	<= 1'b0;
		end
		else begin
			if( ff_pipe_valid & ff_sram_valid & ~w_sram_consumed & ~ff_fifo_valid ) begin
				ff_fifo_data	<= ff_sram_data;
				ff_fifo_valid	<= 1'b1;
			end
			else if( ff_fifo_valid & out_ready ) begin
				ff_fifo_valid	<= 1'b0;
			end
		end
	end

	// -------------------------------------------------------------------------
	//	出力
	// -------------------------------------------------------------------------
	assign	out_valid	= ff_fifo_valid | ff_sram_valid;
	assign	out_data	= ff_fifo_valid ? ff_fifo_data : ff_sram_data;

endmodule