`timescale 1ns/1ps

module tb;
	localparam integer CLK_HALF_NS = 5;
	localparam integer TIMEOUT_CYCLES = 200;

	reg				clk;
	reg				reset;
	reg				sdram_init_busy;

	reg				bus_cs;
	reg		[4:0]	bus_address;
	reg				bus_valid;
	wire			bus_ready;
	reg				bus_write;
	reg		[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;

	wire	[22:1]	sdram_address;
	wire			sdram_write;
	wire	[15:0]	sdram_wdata;
	wire			sdram_valid;
	wire			sdram_flush;
	reg				sdram_ready;
	reg		[15:0]	sdram_rdata;
	reg				sdram_rdata_valid;

	integer			error_count;
	integer			timeout;
	reg		[15:0]	read_data;

	vram_accessor u_dut (
		.clk					( clk					),
		.reset					( reset				),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.sdram_address			( sdram_address			),
		.sdram_write			( sdram_write			),
		.sdram_wdata			( sdram_wdata			),
		.sdram_valid			( sdram_valid			),
		.sdram_flush			( sdram_flush			),
		.sdram_ready			( sdram_ready			),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
	);

	always #(CLK_HALF_NS) clk = ~clk;

	task automatic clear_bus;
	begin
		bus_cs = 1'b0;
		bus_address = 5'd0;
		bus_valid = 1'b0;
		bus_write = 1'b0;
		bus_wdata = 16'd0;
	end
	endtask

	task automatic wait_bus_ready;
	begin
		timeout = 0;
		while( !bus_ready && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus_ready");
			error_count = error_count + 1;
		end
	end
	endtask

	task automatic bus_write_reg;
		input [4:0] addr;
		input [15:0] data;
	begin
		wait_bus_ready();
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b1;
		bus_address = addr;
		bus_wdata = data;
		@(posedge clk);
		#1;
		clear_bus();
	end
	endtask

	task automatic bus_read_reg;
		input [4:0] addr;
		output [15:0] data;
	begin
		wait_bus_ready();
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b0;
		bus_address = addr;
		@(posedge clk);
		#1;
		clear_bus();

		timeout = 0;
		while( !bus_rdata_valid && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus_rdata_valid at addr=%0d", addr);
			error_count = error_count + 1;
			data = 16'h0000;
		end
		else begin
			data = bus_rdata;
		end
	end
	endtask

	task automatic check_eq16;
		input [15:0] act;
		input [15:0] exp;
		input [255:0] msg;
	begin
		if( act !== exp ) begin
			$display("[TB][ERROR] %0s act=%04h exp=%04h", msg, act, exp);
			error_count = error_count + 1;
		end
	end
	endtask

	task automatic req_02_write_check;
		input [15:0] wdata;
		input [22:1] exp_addr;
		input [255:0] msg;
	begin
		wait_bus_ready();
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b1;
		bus_address = 5'h02;
		bus_wdata = wdata;
		@(posedge clk);
		#1;
		if( sdram_valid !== 1'b1 ) begin
			$display("[TB][ERROR] %0s sdram_valid must be 1", msg);
			error_count = error_count + 1;
		end
		if( sdram_address !== exp_addr ) begin
			$display("[TB][ERROR] %0s sdram_address act=%h exp=%h", msg, sdram_address, exp_addr);
			error_count = error_count + 1;
		end
		if( sdram_write !== 1'b1 ) begin
			$display("[TB][ERROR] %0s sdram_write must be 1", msg);
			error_count = error_count + 1;
		end
		if( sdram_wdata !== wdata ) begin
			$display("[TB][ERROR] %0s sdram_wdata act=%h exp=%h", msg, sdram_wdata, wdata);
			error_count = error_count + 1;
		end
		clear_bus();
	end
	endtask

	task automatic req_03_flush_check;
		input [22:1] exp_addr;
		input [255:0] msg;
	begin
		wait_bus_ready();
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b1;
		bus_address = 5'h03;
		bus_wdata = 16'h0001;
		@(posedge clk);
		#1;
		if( sdram_valid !== 1'b1 ) begin
			$display("[TB][ERROR] %0s sdram_valid must be 1", msg);
			error_count = error_count + 1;
		end
		if( sdram_flush !== 1'b1 ) begin
			$display("[TB][ERROR] %0s sdram_flush must be 1", msg);
			error_count = error_count + 1;
		end
		if( sdram_write !== 1'b0 ) begin
			$display("[TB][ERROR] %0s sdram_write must be 0", msg);
			error_count = error_count + 1;
		end
		if( sdram_address !== exp_addr ) begin
			$display("[TB][ERROR] %0s sdram_address act=%h exp=%h", msg, sdram_address, exp_addr);
			error_count = error_count + 1;
		end
		clear_bus();
	end
	endtask

	task automatic req_02_read_check;
		input [15:0] rdata;
		input [22:1] exp_addr;
		input [255:0] msg;
		output [15:0] out_data;
	begin
		wait_bus_ready();
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b0;
		bus_address = 5'h02;
		@(posedge clk);
		#1;
		if( sdram_valid !== 1'b1 ) begin
			$display("[TB][ERROR] %0s sdram_valid must be 1", msg);
			error_count = error_count + 1;
		end
		if( sdram_address !== exp_addr ) begin
			$display("[TB][ERROR] %0s sdram_address act=%h exp=%h", msg, sdram_address, exp_addr);
			error_count = error_count + 1;
		end
		if( sdram_write !== 1'b0 ) begin
			$display("[TB][ERROR] %0s sdram_write must be 0", msg);
			error_count = error_count + 1;
		end
		clear_bus();

		sdram_rdata = rdata;
		@(posedge clk);
		sdram_rdata_valid = 1'b1;
		@(posedge clk);
		sdram_rdata_valid = 1'b0;

		timeout = 0;
		while( !bus_rdata_valid && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus_rdata_valid: %0s", msg);
			error_count = error_count + 1;
			out_data = 16'h0000;
		end
		else begin
			out_data = bus_rdata;
		end
	end
	endtask

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		sdram_init_busy = 1'b1;
		sdram_ready = 1'b1;
		sdram_rdata = 16'h0000;
		sdram_rdata_valid = 1'b0;
		error_count = 0;
		read_data = 16'h0000;
		clear_bus();

		repeat(4) @(posedge clk);
		reset = 1'b0;

		// init busy中は受理しない
		repeat(3) @(posedge clk);
		if( bus_ready !== 1'b0 ) begin
			$display("[TB][ERROR] bus_ready must be 0 during sdram_init_busy");
			error_count = error_count + 1;
		end

		sdram_init_busy = 1'b0;
		wait_bus_ready();

		$display("[TB] TEST1: write VRAM address and verify readback");
		bus_write_reg(5'h00, 16'h0008);
		bus_write_reg(5'h01, 16'h0000);
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0008, "VRAM_ADDRESS_L readback");
		bus_read_reg(5'h01, read_data);
		check_eq16(read_data, 16'h0000, "VRAM_ADDRESS_H readback");

		$display("[TB] TEST2: VRAM_DATA write issues SDRAM write");
		req_02_write_check(16'hABCD, 22'h00008, "TEST2 write #1");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0009, "VRAM_ADDRESS_L after data write (+1)");

		$display("[TB] TEST3: VRAM_DATA read request increments address and returns 16bit data");
		req_02_read_check(16'hBEEF, 22'h00009, "TEST3 read #1", read_data);
		check_eq16(read_data, 16'hBEEF, "VRAM_DATA read #1");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h000A, "VRAM_ADDRESS_L after data read #1 (+1)");

		$display("[TB] TEST4: VRAM_DATA read #2 returns 16bit data");
		req_02_read_check(16'h5678, 22'h0000A, "TEST4 read #2", read_data);
		check_eq16(read_data, 16'h5678, "VRAM_DATA read #2");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h000B, "VRAM_ADDRESS_L after data read #2 (+1)");

		$display("[TB] TEST5: hold sdram_valid while sdram_ready=0 after previous accept");
		bus_write_reg(5'h00, 16'h0010);
		bus_write_reg(5'h01, 16'h0000);
		bus_write_reg(5'h02, 16'h1111);
		repeat(2) @(posedge clk);
		sdram_ready = 1'b0;
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b1;
		bus_address = 5'h02;
		bus_wdata = 16'h2222;
		@(posedge clk);
		#1;
		clear_bus();
		if( sdram_valid !== 1'b1 ) begin
			$display("[TB][ERROR] sdram_valid must assert for stalled write request");
			error_count = error_count + 1;
		end
		if( sdram_address !== 22'h00011 ) begin
			$display("[TB][ERROR] sdram_address mismatch (stall write) act=%h exp=%h", sdram_address, 22'h00011);
			error_count = error_count + 1;
		end
		if( sdram_write !== 1'b1 ) begin
			$display("[TB][ERROR] sdram_write must be 1 during stalled write request");
			error_count = error_count + 1;
		end
		if( sdram_wdata !== 16'h2222 ) begin
			$display("[TB][ERROR] sdram_wdata mismatch (stall write) act=%h exp=%h", sdram_wdata, 16'h2222);
			error_count = error_count + 1;
		end
		repeat(3) begin
			@(posedge clk);
			if( sdram_valid !== 1'b1 ) begin
				$display("[TB][ERROR] sdram_valid dropped before sdram_ready became 1");
				error_count = error_count + 1;
			end
		end
		sdram_ready = 1'b1;
		timeout = 0;
		while( sdram_valid === 1'b1 && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting stalled request acceptance");
			error_count = error_count + 1;
		end
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0012, "VRAM_ADDRESS_L after stalled write sequence (+2 writes)");

		$display("[TB] TEST6: consecutive 0x02 access patterns (W-W, R-W, R-R, W-R)");
		sdram_ready = 1'b1;
		bus_write_reg(5'h00, 16'h0020);
		bus_write_reg(5'h01, 16'h0000);

		// W-W
		req_02_write_check(16'hAAAA, 22'h00020, "TEST6 W-W #1");
		req_02_write_check(16'hBBBB, 22'h00021, "TEST6 W-W #2");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0022, "TEST6 W-W address increment twice");

		// R-W
		req_02_read_check(16'h1357, 22'h00022, "TEST6 R-W #1", read_data);
		check_eq16(read_data, 16'h1357, "TEST6 R-W read data");
		req_02_write_check(16'hCCCC, 22'h00023, "TEST6 R-W #2");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0024, "TEST6 R-W address increment twice");

		// R-R
		req_02_read_check(16'h2468, 22'h00024, "TEST6 R-R #1", read_data);
		check_eq16(read_data, 16'h2468, "TEST6 R-R read #1 data");
		req_02_read_check(16'h369C, 22'h00025, "TEST6 R-R #2", read_data);
		check_eq16(read_data, 16'h369C, "TEST6 R-R read #2 data");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0026, "TEST6 R-R address increment twice");

		// W-R
		req_02_write_check(16'hDDDD, 22'h00026, "TEST6 W-R #1");
		req_02_read_check(16'h55AA, 22'h00027, "TEST6 W-R #2", read_data);
		check_eq16(read_data, 16'h55AA, "TEST6 W-R read data");
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0028, "TEST6 W-R address increment twice");

		$display("[TB] TEST6.5: FLUSH command does not increment VRAM address");
		req_03_flush_check(22'h00028, "TEST6.5 FLUSH request");
		timeout = 0;
		while( sdram_valid === 1'b1 && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] TEST6.5 timeout waiting FLUSH acceptance");
			error_count = error_count + 1;
		end
		if( sdram_flush !== 1'b0 ) begin
			$display("[TB][ERROR] TEST6.5 sdram_flush must deassert after acceptance");
			error_count = error_count + 1;
		end
		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0028, "TEST6.5 address unchanged after FLUSH");

		$display("[TB] TEST7: two consecutive writes with sdram_ready low for 5 clocks");
		sdram_ready = 1'b1;
		bus_write_reg(5'h00, 16'h0030);
		bus_write_reg(5'h01, 16'h0000);

		// 1st write is accepted normally.
		req_02_write_check(16'h1111, 22'h00030, "TEST7 write #1");
		timeout = 0;
		while( sdram_valid === 1'b1 && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] TEST7 timeout waiting first write acceptance");
			error_count = error_count + 1;
		end

		// Immediately after first acceptance, force downstream not-ready for 5 cycles.
		@(posedge clk);
		sdram_ready = 1'b0;

		// Issue 2nd write while sdram_ready is low.
		bus_cs = 1'b1;
		bus_valid = 1'b1;
		bus_write = 1'b1;
		bus_address = 5'h02;
		bus_wdata = 16'h2222;
		@(posedge clk);
		#1;
		clear_bus();

		if( sdram_valid !== 1'b1 ) begin
			$display("[TB][ERROR] TEST7 2nd write: sdram_valid must be 1 during stall");
			error_count = error_count + 1;
		end
		if( sdram_address !== 22'h00031 ) begin
			$display("[TB][ERROR] TEST7 2nd write: sdram_address act=%h exp=%h", sdram_address, 22'h00031);
			error_count = error_count + 1;
		end
		if( sdram_write !== 1'b1 ) begin
			$display("[TB][ERROR] TEST7 2nd write: sdram_write must be 1");
			error_count = error_count + 1;
		end
		if( sdram_wdata !== 16'h2222 ) begin
			$display("[TB][ERROR] TEST7 2nd write: sdram_wdata act=%h exp=%h", sdram_wdata, 16'h2222);
			error_count = error_count + 1;
		end

		repeat(5) begin
			@(posedge clk);
			if( sdram_valid !== 1'b1 ) begin
				$display("[TB][ERROR] TEST7 sdram_valid dropped while sdram_ready=0");
				error_count = error_count + 1;
			end
		end

		sdram_ready = 1'b1;
		timeout = 0;
		while( sdram_valid === 1'b1 && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] TEST7 timeout waiting 2nd write acceptance");
			error_count = error_count + 1;
		end

		bus_read_reg(5'h00, read_data);
		check_eq16(read_data, 16'h0032, "TEST7 address after two writes (+2)");

		repeat(10) @(posedge clk);
		if( error_count == 0 ) begin
			$display("[TB] PASS");
			$finish;
		end
		else begin
			$display("[TB] FAIL error_count=%0d", error_count);
			$stop;
		end
	end

	initial begin
		repeat(5000) @(posedge clk);
		$display("[TB][TIMEOUT] simulation timeout");
		$stop;
	end
endmodule
