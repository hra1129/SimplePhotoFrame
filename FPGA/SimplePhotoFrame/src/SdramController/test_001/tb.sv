// -----------------------------------------------------------------------------
//	Test of ip_sdram.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
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

module tb ();
	localparam		TIMEOUT_COUNT	= 20000;
	localparam		BURST_LEN		= 8;
	longint			clk_base		= 64'd1_000_000_000_000 / 64'd108_000_000;	//	ps
	reg				reset;
	reg				clk;				//	108MHz
	reg				clk_sdram;			//	108MHz
	wire			sdram_init_busy;
	reg		[22:5]	bus_address;
	reg				bus_valid;
	wire			bus_ready;
	reg				bus_write;
	reg				bus_refresh;
	reg		[31:0]	bus_wdata;
	reg		[ 3:0]	bus_wdata_mask;
	reg				bus_wdata_valid;
	wire	[31:0]	bus_rdata;
	wire			bus_rdata_valid;
	wire			O_sdram_clk;
	wire			O_sdram_cke;
	wire			O_sdram_cs_n;		// chip select
	wire			O_sdram_cas_n;		// columns address select
	wire			O_sdram_ras_n;		// row address select
	wire			O_sdram_wen_n;		// write enable
	wire	[31:0]	IO_sdram_dq;		// 32 bit bidirectional data bus
	wire	[10:0]	O_sdram_addr;		// 11 bit multiplexed address bus
	wire	[ 1:0]	O_sdram_ba;			// two banks
	wire	[ 3:0]	O_sdram_dqm;		// data mask
	int				error_count;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	ip_sdram u_sdram_controller (
		.reset				( reset				),
		.clk				( clk				),
		.clk_sdram			( clk				),
		.sdram_init_busy	( sdram_init_busy	),
		.bus_address		( bus_address		),
		.bus_write			( bus_write			),
		.bus_refresh		( bus_refresh		),
		.bus_valid			( bus_valid			),
		.bus_ready			( bus_ready			),
		.bus_wdata			( bus_wdata			),
		.bus_wdata_mask		( bus_wdata_mask	),
		.bus_wdata_valid	( bus_wdata_valid	),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_valid	( bus_rdata_valid	),
		.O_sdram_clk		( O_sdram_clk		),
		.O_sdram_cke		( O_sdram_cke		),
		.O_sdram_cs_n		( O_sdram_cs_n		),
		.O_sdram_cas_n		( O_sdram_cas_n		),
		.O_sdram_ras_n		( O_sdram_ras_n		),
		.O_sdram_wen_n		( O_sdram_wen_n		),
		.IO_sdram_dq		( IO_sdram_dq		),
		.O_sdram_addr		( O_sdram_addr		),
		.O_sdram_ba			( O_sdram_ba		),
		.O_sdram_dqm		( O_sdram_dqm		)
	);

	// --------------------------------------------------------------------
	mt48lc2m32b2 u_sdram (
		.Dq					( IO_sdram_dq		), 
		.Addr				( O_sdram_addr		), 
		.Ba					( O_sdram_ba		), 
		.Clk				( O_sdram_clk		), 
		.Cke				( O_sdram_cke		), 
		.Cs_n				( O_sdram_cs_n		), 
		.Ras_n				( O_sdram_ras_n		), 
		.Cas_n				( O_sdram_cas_n		), 
		.We_n				( O_sdram_wen_n		), 
		.Dqm				( O_sdram_dqm		)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
		clk_sdram <= ~clk_sdram;
	end

	function automatic [31:0] make_test_word(
		input [7:0] burst_id,
		input [2:0] beat_idx
	);
		make_test_word = { 8'hA5, burst_id, 8'h5A, {5'd0, beat_idx} };
	endfunction

	// --------------------------------------------------------------------
	//	Tasks
	// --------------------------------------------------------------------
	task automatic issue_request(
		input	[22:5]	p_address,
		input				p_write,
		input				p_refresh
	);
		int timeout;
		begin
			timeout = 0;
			@( negedge clk );
			bus_address	<= p_address;
			bus_write	<= p_write;
			bus_refresh	<= p_refresh;
			bus_valid	<= 1'b1;

			while( timeout < TIMEOUT_COUNT ) begin
				@( posedge clk );
				if( bus_ready ) begin
					break;
				end
				timeout++;
			end

			if( timeout >= TIMEOUT_COUNT ) begin
				$display("[FAIL] request timeout write=%0d refresh=%0d addr=0x%05X", p_write, p_refresh, p_address);
				error_count++;
			end

			@( negedge clk );
			bus_valid	<= 1'b0;
			bus_write	<= 1'b0;
			bus_refresh	<= 1'b0;
			bus_address	<= 'd0;
		end
	endtask: issue_request

	// --------------------------------------------------------------------
	task automatic write_burst(
		input	[22:5]	p_address,
		input	[7:0]	p_burst_id
	);
		int i;
		begin
			$display("[%t] write_burst req addr=0x%05X id=%0d", $realtime, p_address, p_burst_id);
			issue_request( p_address, 1'b1, 1'b0 );

			for( i = 0; i < BURST_LEN; i++ ) begin
				@( negedge clk );
				bus_wdata		<= make_test_word( p_burst_id, i[2:0] );
				bus_wdata_mask	<= 4'b0000;
				bus_wdata_valid	<= 1'b1;
				@( posedge clk );
			end

			@( negedge clk );
			bus_wdata_valid	<= 1'b0;
			bus_wdata		<= 32'd0;
			bus_wdata_mask	<= 4'hF;
			$display("-- write_burst done");
		end
	endtask: write_burst

	// --------------------------------------------------------------------
	task automatic read_burst_and_check(
		input	[22:5]	p_address,
		input	[7:0]	p_burst_id
	);
		int timeout;
		int beat;
		reg [31:0] expected;
		begin
			$display("[%t] read_burst req addr=0x%05X id=%0d", $realtime, p_address, p_burst_id);
			issue_request( p_address, 1'b0, 1'b0 );

			timeout = 0;
			beat = 0;
			while( (beat < BURST_LEN) && (timeout < TIMEOUT_COUNT) ) begin
				@( posedge clk );
				timeout++;
				if( bus_rdata_valid ) begin
					expected = make_test_word( p_burst_id, beat[2:0] );
					if( bus_rdata !== expected ) begin
						$display("[FAIL] read mismatch beat=%0d got=0x%08X expected=0x%08X", beat, bus_rdata, expected);
						error_count++;
					end
					beat++;
				end
			end

			if( beat != BURST_LEN ) begin
				$display("[FAIL] read timeout beat=%0d/%0d", beat, BURST_LEN);
				error_count++;
			end
			else begin
				$display("-- read_burst done");
			end
		end
	endtask: read_burst_and_check

	// --------------------------------------------------------------------
	task automatic exec_refresh();
		begin
			$display("[%t] refresh request", $realtime);
			issue_request( 18'd0, 1'b0, 1'b1 );
			$display("-- refresh done");
		end
	endtask: exec_refresh

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		error_count = 0;
		reset = 1;
		clk = 0;
		clk_sdram = 1;
		bus_address = 'd0;
		bus_write = 1'b0;
		bus_refresh = 1'b0;
		bus_valid = 1'b0;
		bus_wdata = 32'd0;
		bus_wdata_mask = 4'hF;
		bus_wdata_valid = 1'b0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset			= 0;
		@( posedge clk );

		$display( "Wait initialization of SDRAM" );
		while( sdram_init_busy ) begin
			@( posedge clk );
		end
		$display( "Finished initialization" );

		repeat( 16 ) @( posedge clk );

		// TEST 1: write burst -> read burst
		$display("[TEST 1] write/read burst #0");
		write_burst( 18'h00000, 8'h10 );
		read_burst_and_check( 18'h00000, 8'h10 );

		// TEST 2: second burst at different address
		$display("[TEST 2] write/read burst #1");
		write_burst( 18'h00001, 8'h22 );
		read_burst_and_check( 18'h00001, 8'h22 );

		// TEST 3: refresh interleaved, then re-read both bursts
		$display("[TEST 3] refresh and retention");
		exec_refresh();
		exec_refresh();
		exec_refresh();
		read_burst_and_check( 18'h00000, 8'h10 );
		read_burst_and_check( 18'h00001, 8'h22 );

		$display("--------------------------------------------");
		if( error_count == 0 ) begin
			$display("ALL TESTS PASSED");
		end
		else begin
			$display("FAILED: %0d error(s)", error_count);
		end
		$display("--------------------------------------------");

		repeat( 20 ) @( posedge clk );
		$finish;
	end
endmodule
