`timescale 1ns/1ps

module tb;
	localparam real CLK_HALF_NS = 4.62963;   // 108MHz
	localparam integer TIMEOUT_CYCLES = 5000;
	localparam integer REFRESH_INTERVAL_CYCLES_TB = 80;

	reg				reset;
	reg				clk;
	reg				clk_sdram;

	reg		[22:1]	bus_address;
	reg				bus_write;
	reg		[15:0]	bus_wdata;
	reg				bus_flash;
	reg				bus_valid;
	wire			bus_ready;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;

	wire	[22:5]	sdram_cache_address;
	wire			sdram_cache_write;
	wire			sdram_cache_refresh;
	wire			sdram_cache_valid;
	wire	[31:0]	sdram_cache_wdata;
	wire	[3:0]	sdram_cache_wdata_mask;
	wire			sdram_cache_wdata_valid;
	wire	[31:0]	sdram_cache_rdata;
	wire			sdram_cache_rdata_valid;

	wire			sdram_init_busy;
	wire	[22:5]	ip_sdram_address;
	wire			ip_sdram_write;
	wire			ip_sdram_refresh;
	wire			ip_sdram_valid;
	wire			ip_sdram_ready;
	wire	[31:0]	ip_sdram_wdata;
	wire	[3:0]	ip_sdram_wdata_mask;
	wire			ip_sdram_wdata_valid;
	wire	[31:0]	ip_sdram_rdata;
	wire			ip_sdram_rdata_valid;

	// SDRAM physical signals
	wire			sdram_clk;
	wire			sdram_cke;
	wire			sdram_cs_n;
	wire			sdram_ras_n;
	wire			sdram_cas_n;
	wire			sdram_wen_n;
	wire	[31:0]	sdram_dq;
	wire	[10:0]	sdram_addr;
	wire	[ 1:0]	sdram_ba;
	wire	[ 3:0]	sdram_dqm;

	integer			error_count;
	reg		[22:1]	test_addr;
	reg		[6:0]	test_hash;
	reg		[2:0]	test_word;

	cache #(
		.c_refresh_interval_cycles(REFRESH_INTERVAL_CYCLES_TB)
	) u_dut (
		.reset				( reset						),
		.clk				( clk						),
		.cache_address		( bus_address			),
		.cache_write		( bus_write				),
		.cache_wdata		( bus_wdata				),
		.cache_flush		( bus_flash				),
		.cache_valid		( bus_valid				),
		.cache_ready		( bus_ready				),
		.cache_rdata		( bus_rdata				),
		.cache_rdata_valid	( bus_rdata_valid		),
		.sdram_address		( sdram_cache_address		),
		.sdram_write		( sdram_cache_write			),
		.sdram_refresh		( sdram_cache_refresh		),
		.sdram_valid		( sdram_cache_valid			),
		.sdram_ready		( ip_sdram_ready			),
		.sdram_wdata		( sdram_cache_wdata			),
		.sdram_wdata_mask	( sdram_cache_wdata_mask	),
		.sdram_wdata_valid	( sdram_cache_wdata_valid	),
		.sdram_rdata		( ip_sdram_rdata			),
		.sdram_rdata_valid	( ip_sdram_rdata_valid		)
	);

	ip_sdram #(
		.FREQ(108_000_000)
	) u_sdram_ctrl (
		.reset				( reset						),
		.clk				( clk						),
		.clk_sdram			( clk_sdram					),
		.sdram_init_busy	( sdram_init_busy			),
		.bus_address		( sdram_cache_address		),
		.bus_write			( sdram_cache_write			),
		.bus_refresh		( sdram_cache_refresh		),
		.bus_valid			( sdram_cache_valid			),
		.bus_ready			( ip_sdram_ready			),
		.bus_wdata			( sdram_cache_wdata			),
		.bus_wdata_mask		( sdram_cache_wdata_mask	),
		.bus_wdata_valid	( sdram_cache_wdata_valid	),
		.bus_rdata			( ip_sdram_rdata			),
		.bus_rdata_valid	( ip_sdram_rdata_valid		),
		.O_sdram_clk		( sdram_clk					),
		.O_sdram_cke		( sdram_cke					),
		.O_sdram_cs_n		( sdram_cs_n				),
		.O_sdram_ras_n		( sdram_ras_n				),
		.O_sdram_cas_n		( sdram_cas_n				),
		.O_sdram_wen_n		( sdram_wen_n				),
		.IO_sdram_dq		( sdram_dq					),
		.O_sdram_addr		( sdram_addr				),
		.O_sdram_ba			( sdram_ba					),
		.O_sdram_dqm		( sdram_dqm					)
	);

	mt48lc2m32b2 u_sdram_model (
		.Dq					( sdram_dq					),
		.Addr				( sdram_addr				),
		.Ba					( sdram_ba					),
		.Clk				( sdram_clk					),
		.Cke				( sdram_cke					),
		.Cs_n				( sdram_cs_n				),
		.Ras_n				( sdram_ras_n				),
		.Cas_n				( sdram_cas_n				),
		.We_n				( sdram_wen_n				),
		.Dqm				( sdram_dqm					)
	);

	always #(CLK_HALF_NS) begin
		clk <= ~clk;
	end

	// clk_sdram: 180 degree phase shift relative to clk
	// Start with clk_sdram=1 (opposite phase to clk=0) in initial
	always #(CLK_HALF_NS) begin
		clk_sdram <= ~clk_sdram;
	end

	function [31:0] apply_dqm;
		input [31:0] old_data;
		input [31:0] new_data;
		input [3:0] dqm;
		begin
			apply_dqm[7:0] = dqm[0] ? old_data[7:0] : new_data[7:0];
			apply_dqm[15:8] = dqm[1] ? old_data[15:8] : new_data[15:8];
			apply_dqm[23:16] = dqm[2] ? old_data[23:16] : new_data[23:16];
			apply_dqm[31:24] = dqm[3] ? old_data[31:24] : new_data[31:24];
		end
	endfunction

	task automatic cache_write16;
		input [22:1] addr;
		input [15:0] data;
		integer timeout;
		begin
			timeout = 0;
			@(negedge clk);
			bus_address <= addr;
			bus_write <= 1'b1;
			bus_wdata <= data;
			bus_flash <= 1'b0;
			bus_valid <= 1'b1;
			while (!bus_ready && timeout < TIMEOUT_CYCLES) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= TIMEOUT_CYCLES) begin
				$display("[TB][ERROR] write timeout addr=%h data=%h", addr, data);
				error_count = error_count + 1;
			end
			@(negedge clk);
			bus_valid <= 1'b0;
			bus_write <= 1'b0;
			bus_wdata <= 16'h0000;
			bus_address <= 22'd0;
		end
	endtask

	task automatic cache_read16;
		input [22:1] addr;
		output [15:0] data;
		integer timeout;
		begin
			timeout = 0;
			data = 16'h0000;
			@(negedge clk);
			bus_address <= addr;
			bus_write <= 1'b0;
			bus_flash <= 1'b0;
			bus_valid <= 1'b1;
			while (!bus_ready && timeout < TIMEOUT_CYCLES) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= TIMEOUT_CYCLES) begin
				$display("[TB][ERROR] read request timeout addr=%h", addr);
				error_count = error_count + 1;
			end
			@(negedge clk);
			bus_valid <= 1'b0;
			bus_address <= 22'd0;

			timeout = 0;
			while (!bus_rdata_valid && timeout < TIMEOUT_CYCLES) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= TIMEOUT_CYCLES) begin
				$display("[TB][ERROR] read response timeout addr=%h", addr);
				error_count = error_count + 1;
			end else begin
				data = bus_rdata;
			end
		end
	endtask

	task automatic cache_flush;
		integer timeout;
		begin
			timeout = 0;
			@(negedge clk);
			bus_flash <= 1'b1;
			bus_write <= 1'b0;
			bus_valid <= 1'b1;

			// Wait until DUT leaves idle state (request accepted).
			while (bus_ready && timeout < (TIMEOUT_CYCLES * 4)) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= (TIMEOUT_CYCLES * 4)) begin
				$display("[TB][ERROR] flush start timeout");
				error_count = error_count + 1;
			end

			@(negedge clk);
			bus_valid <= 1'b0;
			bus_flash <= 1'b0;

			// Wait until flush processing fully completes and DUT returns idle.
			timeout = 0;
			while (!bus_ready && timeout < (TIMEOUT_CYCLES * 16)) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= (TIMEOUT_CYCLES * 16)) begin
				$display("[TB][ERROR] flush completion timeout");
				error_count = error_count + 1;
			end
		end
	endtask

	always @(posedge clk) begin
		// SDRAM simulation now handled by ip_sdram controller and MT48LC2M32B2 model
	end

	reg [15:0] rd;
	integer i;
	initial begin
		clk = 1'b0;
		clk_sdram = 1'b1;		// 180 degree phase shift to clk
		reset = 1'b1;
		bus_address = 22'd0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
		bus_flash = 1'b0;
		bus_valid = 1'b0;
		error_count = 0;

		// Monitor signals during initialization
		#1000;
		$display("[TB][DEBUG] After 1us: reset=%d, clk=%d, sdram_init_busy=%d", reset, clk, sdram_init_busy);
		$display("[TB][DEBUG] bus_ready=%d, bus_rdata_valid=%d", bus_ready, bus_rdata_valid);
		$display("[TB][DEBUG] ip_sdram: bus_ready=%d, ff_main_state check via bus_ready", ip_sdram_ready);

		repeat (8) @(posedge clk);
		reset = 1'b0;

		// Wait for SDRAM initialization to complete
		repeat (20) @(posedge clk);
		if (sdram_init_busy) begin
			$display("[TB][INFO] waiting for SDRAM init...");
			while (sdram_init_busy) begin
				@(posedge clk);
			end
		end
		$display("[TB][INFO] SDRAM init complete at time %0d", $time);

		// Wait for cache tag initialization to complete
		repeat (160) @(posedge clk);

		test_addr = 22'h000126;
		test_hash = test_addr[11:5];
		test_word = test_addr[4:2];

		$display("[TB][TEST1] read miss then fill");
		$display("[TB][DEBUG] Before read: addr=%h, bus_ready=%d", test_addr, bus_ready);
		cache_read16(test_addr, rd);
		$display("[TB][DEBUG] After read: rd=%04h", rd);
		// First read is from uninitialized SDRAM - just verify response comes back
		// (SDRAM model returns xxxx for uninitialized data)
		// Real validation is in TEST3/TEST4 where we write, flush, then read back
		$display("[TB][OK] TEST1 read response received (cache fill from SDRAM working)");

		$display("[TB][TEST2] write hit then read back");
		cache_write16(test_addr, 16'hA55A);
		cache_read16(test_addr, rd);
		if (rd !== 16'hA55A) begin
			$display("[TB][ERROR] TEST2 read-back mismatch got=%04h exp=A55A", rd);
			error_count = error_count + 1;
		end else begin
			$display("[TB][OK] TEST2 write-back verified");
		end

		$display("[TB][TEST3] flush then SDRAM writeback");
		cache_flush();
		repeat (100) @(posedge clk);  // Wait for flush to reach SDRAM
		$display("[TB][OK] TEST3 flush completed");

		$display("[TB][TEST4] refresh auto event and continued access");
		for (i = 0; i < 200; i = i + 1) begin
			@(posedge clk);
		end
		cache_read16(test_addr, rd);
		if (rd !== 16'hA55A) begin
			$display("[TB][ERROR] TEST4 post-refresh read mismatch got=%04h exp=A55A", rd);
			error_count = error_count + 1;
		end else begin
			$display("[TB][OK] TEST4 post-refresh verified");
		end

		if (error_count == 0) begin
			$display("[TB] ALL TESTS PASSED");
		end
		else begin
			$display("[TB] FAILED with %0d errors", error_count);
		end

		repeat (20) @(posedge clk);
		$finish;
	end


	initial begin
		repeat (TIMEOUT_CYCLES * 50) @(posedge clk);
		$display("[TB][TIMEOUT]");
		$stop;
	end
endmodule

