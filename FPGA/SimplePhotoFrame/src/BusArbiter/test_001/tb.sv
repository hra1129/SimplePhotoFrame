`timescale 1ns/1ps

module tb;
	localparam integer CLK_HALF = 5;
	localparam integer TIMEOUT_CYCLES = 200;

	reg				reset;
	reg				clk;

	reg		[22:1]	bus0_address;
	reg				bus0_write;
	reg		[15:0]	bus0_wdata;
	reg				bus0_flash;
	reg				bus0_valid;
	wire			bus0_ready;
	wire	[15:0]	bus0_rdata;
	wire			bus0_rdata_valid;

	reg		[22:1]	bus1_address;
	reg				bus1_write;
	reg		[15:0]	bus1_wdata;
	reg				bus1_flash;
	reg				bus1_valid;
	wire			bus1_ready;
	wire	[15:0]	bus1_rdata;
	wire			bus1_rdata_valid;

	reg		[22:1]	bus2_address;
	reg				bus2_write;
	reg		[15:0]	bus2_wdata;
	reg				bus2_flash;
	reg				bus2_valid;
	wire			bus2_ready;
	wire	[15:0]	bus2_rdata;
	wire			bus2_rdata_valid;

	reg		[22:1]	bus3_address;
	reg				bus3_write;
	reg		[15:0]	bus3_wdata;
	reg				bus3_flash;
	reg				bus3_valid;
	wire			bus3_ready;
	wire	[15:0]	bus3_rdata;
	wire			bus3_rdata_valid;

	wire	[22:1]	bus_address;
	wire			bus_write;
	wire	[15:0]	bus_wdata;
	wire			bus_flash;
	wire			bus_valid;
	reg				bus_ready;
	reg		[15:0]	bus_rdata;
	reg				bus_rdata_valid;

	integer			error_count;
	integer			timeout;
	integer			test_number;
	integer				rr_cycle;
	reg		[1:0]	rr_start_bus;

	bus_arbiter u_dut (
		.reset				( reset				),
		.clk				( clk				),
		.bus0_address		( bus0_address		),
		.bus0_write			( bus0_write		),
		.bus0_wdata			( bus0_wdata		),
		.bus0_flash			( bus0_flash		),
		.bus0_valid			( bus0_valid		),
		.bus0_ready			( bus0_ready		),
		.bus0_rdata			( bus0_rdata		),
		.bus0_rdata_valid	( bus0_rdata_valid	),
		.bus1_address		( bus1_address		),
		.bus1_write			( bus1_write		),
		.bus1_wdata			( bus1_wdata		),
		.bus1_flash			( bus1_flash		),
		.bus1_valid			( bus1_valid		),
		.bus1_ready			( bus1_ready		),
		.bus1_rdata			( bus1_rdata		),
		.bus1_rdata_valid	( bus1_rdata_valid	),
		.bus2_address		( bus2_address		),
		.bus2_write			( bus2_write		),
		.bus2_wdata			( bus2_wdata		),
		.bus2_flash			( bus2_flash		),
		.bus2_valid			( bus2_valid		),
		.bus2_ready			( bus2_ready		),
		.bus2_rdata			( bus2_rdata		),
		.bus2_rdata_valid	( bus2_rdata_valid	),
		.bus3_address		( bus3_address		),
		.bus3_write			( bus3_write		),
		.bus3_wdata			( bus3_wdata		),
		.bus3_flash			( bus3_flash		),
		.bus3_valid			( bus3_valid		),
		.bus3_ready			( bus3_ready		),
		.bus3_rdata			( bus3_rdata		),
		.bus3_rdata_valid	( bus3_rdata_valid	),
		.bus_address			( bus_address		),
		.bus_write			( bus_write			),
		.bus_wdata			( bus_wdata			),
		.bus_flash			( bus_flash			),
		.bus_valid			( bus_valid			),
		.bus_ready			( bus_ready			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_valid	( bus_rdata_valid	)
	);

	always #(CLK_HALF) clk = ~clk;

	task clear_inputs;
	begin
		bus0_address = 22'd0;
		bus0_write = 1'b0;
		bus0_wdata = 16'd0;
		bus0_flash = 1'b0;
		bus0_valid = 1'b0;
		bus1_address = 22'd0;
		bus1_write = 1'b0;
		bus1_wdata = 16'd0;
		bus1_flash = 1'b0;
		bus1_valid = 1'b0;
		bus2_address = 22'd0;
		bus2_write = 1'b0;
		bus2_wdata = 16'd0;
		bus2_flash = 1'b0;
		bus2_valid = 1'b0;
		bus3_address = 22'd0;
		bus3_write = 1'b0;
		bus3_wdata = 16'd0;
		bus3_flash = 1'b0;
		bus3_valid = 1'b0;
	end
	endtask

	task check_cond;
		input cond;
		input string msg;
	begin
		if( !cond ) begin
			$display("[TB][ERROR] %0s", msg);
			error_count = error_count + 1;
		end
	end
	endtask

	task wait_ready_bus0;
	begin
		timeout = 0;
		while( !bus0_ready && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			#1;
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus0_ready");
			error_count = error_count + 1;
		end
	end
	endtask

	task wait_ready_bus1;
	begin
		timeout = 0;
		while( !bus1_ready && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			#1;
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus1_ready");
			error_count = error_count + 1;
		end
	end
	endtask

	task wait_ready_bus3;
	begin
		timeout = 0;
		while( !bus3_ready && timeout < TIMEOUT_CYCLES ) begin
			@(posedge clk);
			#1;
			timeout = timeout + 1;
		end
		if( timeout >= TIMEOUT_CYCLES ) begin
			$display("[TB][ERROR] timeout waiting bus3_ready");
			error_count = error_count + 1;
		end
	end
	endtask

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		bus_ready = 1'b0;
		bus_rdata = 16'd0;
		bus_rdata_valid = 1'b0;
		error_count = 0;
		test_number = 0;
		clear_inputs();

		repeat(4) @(posedge clk);
		bus_ready = 1'b1;
		reset = 1'b0;
		repeat(2) @(posedge clk);

		test_number = 1;
		$display("[TB][TEST%0d] single write handshake and forwarding", test_number);
		@(posedge clk);
		bus2_address <= 22'h12345;
		bus2_write <= 1'b1;
		bus2_wdata <= 16'h55AA;
		bus2_flash <= 1'b0;
		bus2_valid <= 1'b1;
		@(posedge clk);
		#1;
		check_cond(bus2_ready, "bus2_ready should assert for single request");
		check_cond(bus_valid, "bus_valid should assert when request exists");
		check_cond(bus_address == 22'h12345, "bus_address forward mismatch");
		check_cond(bus_write == 1'b1, "bus_write forward mismatch");
		check_cond(bus_wdata == 16'h55AA, "bus_wdata forward mismatch");
		@(posedge clk);
		bus2_valid <= 1'b0;
		bus2_flash <= 1'b0;

		test_number = 2;
		$display("[TB][TEST%0d] single flash write handshake and forwarding", test_number);
		@(posedge clk);
		bus3_address <= 22'h14321;
		bus3_write <= 1'b1;
		bus3_wdata <= 16'hA5A5;
		bus3_flash <= 1'b1;
		bus3_valid <= 1'b1;
		@(posedge clk);
		#1;
		check_cond(bus3_ready, "bus3_ready should assert for single flash request");
		check_cond(bus_valid, "bus_valid should assert when flash request exists");
		check_cond(bus_address == 22'h14321, "flash bus_address forward mismatch");
		check_cond(bus_write == 1'b1, "flash bus_write forward mismatch");
		check_cond(bus_wdata == 16'hA5A5, "flash bus_wdata forward mismatch");
		check_cond(bus_flash == 1'b1, "flash bus_flash forward mismatch");
		@(posedge clk);
		bus3_valid <= 1'b0;
		bus3_flash <= 1'b0;

		test_number = 3;
		$display("[TB][TEST%0d] round robin among bus0,bus1,bus3", test_number);
		@(posedge clk);
		bus0_address <= 22'h10001;
		bus1_address <= 22'h10002;
		bus3_address <= 22'h10004;
		bus0_write <= 1'b1;
		bus1_write <= 1'b1;
		bus3_write <= 1'b1;
		bus0_wdata <= 16'h0001;
		bus1_wdata <= 16'h0002;
		bus3_wdata <= 16'h0004;
		bus0_valid <= 1'b1;
		bus1_valid <= 1'b1;
		bus3_valid <= 1'b1;

		wait_ready_bus0();
		@(posedge clk);
		bus0_valid <= 1'b0;
		wait_ready_bus1();
		@(posedge clk);
		bus1_valid <= 1'b0;
		wait_ready_bus3();
		@(posedge clk);
		bus3_valid <= 1'b0;

		test_number = 4;
		$display("[TB][TEST%0d] four-bus write round robin for 8 cycles", test_number);
		@(posedge clk);
		bus0_address <= 22'h20000;
		bus1_address <= 22'h21000;
		bus2_address <= 22'h22000;
		bus3_address <= 22'h23000;
		bus0_write <= 1'b1;
		bus1_write <= 1'b1;
		bus2_write <= 1'b1;
		bus3_write <= 1'b1;
		bus0_wdata <= 16'h1000;
		bus1_wdata <= 16'h2000;
		bus2_wdata <= 16'h3000;
		bus3_wdata <= 16'h4000;
		bus0_valid <= 1'b1;
		bus1_valid <= 1'b1;
		bus2_valid <= 1'b1;
		bus3_valid <= 1'b1;
		@(negedge clk);
		if( bus0_ready )
			rr_start_bus = 2'd0;
		else if( bus1_ready )
			rr_start_bus = 2'd1;
		else if( bus2_ready )
			rr_start_bus = 2'd2;
		else
			rr_start_bus = 2'd3;

		for( rr_cycle = 0; rr_cycle < 8; rr_cycle = rr_cycle + 1 ) begin
			case( rr_start_bus + rr_cycle[1:0] )
			2'd0: begin
				check_cond(bus0_ready, "bus0_ready should assert in round robin sequence");
				check_cond(!bus1_ready && !bus2_ready && !bus3_ready, "only bus0_ready should assert");
				check_cond(bus_address == bus0_address, "round robin bus0 address mismatch");
				check_cond(bus_wdata == bus0_wdata, "round robin bus0 data mismatch");
			end
			2'd1: begin
				check_cond(bus1_ready, "bus1_ready should assert in round robin sequence");
				check_cond(!bus0_ready && !bus2_ready && !bus3_ready, "only bus1_ready should assert");
				check_cond(bus_address == bus1_address, "round robin bus1 address mismatch");
				check_cond(bus_wdata == bus1_wdata, "round robin bus1 data mismatch");
			end
			2'd2: begin
				check_cond(bus2_ready, "bus2_ready should assert in round robin sequence");
				check_cond(!bus0_ready && !bus1_ready && !bus3_ready, "only bus2_ready should assert");
				check_cond(bus_address == bus2_address, "round robin bus2 address mismatch");
				check_cond(bus_wdata == bus2_wdata, "round robin bus2 data mismatch");
			end
			default: begin
				check_cond(bus3_ready, "bus3_ready should assert in round robin sequence");
				check_cond(!bus0_ready && !bus1_ready && !bus2_ready, "only bus3_ready should assert");
				check_cond(bus_address == bus3_address, "round robin bus3 address mismatch");
				check_cond(bus_wdata == bus3_wdata, "round robin bus3 data mismatch");
			end
			endcase

			@(posedge clk);
			case( rr_start_bus + rr_cycle[1:0] )
			2'd0: begin
				bus0_address <= bus0_address + 22'd1;
				bus0_wdata <= bus0_wdata + 16'd1;
			end
			2'd1: begin
				bus1_address <= bus1_address + 22'd1;
				bus1_wdata <= bus1_wdata + 16'd1;
			end
			2'd2: begin
				bus2_address <= bus2_address + 22'd1;
				bus2_wdata <= bus2_wdata + 16'd1;
			end
			default: begin
				bus3_address <= bus3_address + 22'd1;
				bus3_wdata <= bus3_wdata + 16'd1;
			end
			endcase
			@(negedge clk);
		end

		@(posedge clk);
		bus0_valid <= 1'b0;
		bus1_valid <= 1'b0;
		bus2_valid <= 1'b0;
		bus3_valid <= 1'b0;

		test_number = 5;
		$display("[TB][TEST%0d] four-bus flash write round robin for 4 cycles", test_number);
		@(posedge clk);
		bus0_address <= 22'h24000;
		bus1_address <= 22'h25000;
		bus2_address <= 22'h26000;
		bus3_address <= 22'h27000;
		bus0_write <= 1'b1;
		bus1_write <= 1'b1;
		bus2_write <= 1'b1;
		bus3_write <= 1'b1;
		bus0_wdata <= 16'h5000;
		bus1_wdata <= 16'h6000;
		bus2_wdata <= 16'h7000;
		bus3_wdata <= 16'h8000;
		bus0_flash <= 1'b1;
		bus1_flash <= 1'b1;
		bus2_flash <= 1'b1;
		bus3_flash <= 1'b1;
		bus0_valid <= 1'b1;
		bus1_valid <= 1'b1;
		bus2_valid <= 1'b1;
		bus3_valid <= 1'b1;
		@(negedge clk);
		if( bus0_ready )
			rr_start_bus = 2'd0;
		else if( bus1_ready )
			rr_start_bus = 2'd1;
		else if( bus2_ready )
			rr_start_bus = 2'd2;
		else
			rr_start_bus = 2'd3;

		for( rr_cycle = 0; rr_cycle < 4; rr_cycle = rr_cycle + 1 ) begin
			check_cond(bus_flash == 1'b1, "bus_flash should stay asserted for flash requests");
			case( rr_start_bus + rr_cycle[1:0] )
			2'd0: begin
				check_cond(bus0_ready, "bus0_ready should assert in flash round robin sequence");
				check_cond(!bus1_ready && !bus2_ready && !bus3_ready, "only bus0_ready should assert in flash sequence");
				check_cond(bus_address == bus0_address, "flash round robin bus0 address mismatch");
				check_cond(bus_wdata == bus0_wdata, "flash round robin bus0 data mismatch");
			end
			2'd1: begin
				check_cond(bus1_ready, "bus1_ready should assert in flash round robin sequence");
				check_cond(!bus0_ready && !bus2_ready && !bus3_ready, "only bus1_ready should assert in flash sequence");
				check_cond(bus_address == bus1_address, "flash round robin bus1 address mismatch");
				check_cond(bus_wdata == bus1_wdata, "flash round robin bus1 data mismatch");
			end
			2'd2: begin
				check_cond(bus2_ready, "bus2_ready should assert in flash round robin sequence");
				check_cond(!bus0_ready && !bus1_ready && !bus3_ready, "only bus2_ready should assert in flash sequence");
				check_cond(bus_address == bus2_address, "flash round robin bus2 address mismatch");
				check_cond(bus_wdata == bus2_wdata, "flash round robin bus2 data mismatch");
			end
			default: begin
				check_cond(bus3_ready, "bus3_ready should assert in flash round robin sequence");
				check_cond(!bus0_ready && !bus1_ready && !bus2_ready, "only bus3_ready should assert in flash sequence");
				check_cond(bus_address == bus3_address, "flash round robin bus3 address mismatch");
				check_cond(bus_wdata == bus3_wdata, "flash round robin bus3 data mismatch");
			end
			endcase

			@(posedge clk);
			case( rr_cycle[1:0] )
			2'd0: begin
				bus0_address <= bus0_address + 22'd1;
				bus0_wdata <= bus0_wdata + 16'd1;
			end
			2'd1: begin
				bus1_address <= bus1_address + 22'd1;
				bus1_wdata <= bus1_wdata + 16'd1;
			end
			2'd2: begin
				bus2_address <= bus2_address + 22'd1;
				bus2_wdata <= bus2_wdata + 16'd1;
			end
			default: begin
				bus3_address <= bus3_address + 22'd1;
				bus3_wdata <= bus3_wdata + 16'd1;
			end
			endcase
			@(negedge clk);
		end

		@(posedge clk);
		bus0_valid <= 1'b0;
		bus1_valid <= 1'b0;
		bus2_valid <= 1'b0;
		bus3_valid <= 1'b0;
		bus0_flash <= 1'b0;
		bus1_flash <= 1'b0;
		bus2_flash <= 1'b0;
		bus3_flash <= 1'b0;

		test_number = 6;
		$display("[TB][TEST%0d] read request stalls until rdata_valid", test_number);
		@(posedge clk);
		bus1_address <= 22'h22222;
		bus1_write <= 1'b0;
		bus1_wdata <= 16'hBEEF;
		bus1_valid <= 1'b1;
		wait_ready_bus1();
		@(posedge clk);
		bus1_valid <= 1'b0;

		// During read wait, another write request should not be accepted.
		@(posedge clk);
		bus0_address <= 22'h33333;
		bus0_write <= 1'b1;
		bus0_wdata <= 16'hABCD;
		bus0_valid <= 1'b1;
		repeat(6) begin
			@(posedge clk);
			#1;
			check_cond(!bus0_ready, "bus0_ready should stay low while read response pending");
		end

		// Return read data from downstream.
		@(posedge clk);
		bus_rdata <= 16'hCAFE;
		bus_rdata_valid <= 1'b1;
		@(posedge clk);
		#1;
		check_cond(bus1_rdata_valid, "bus1_rdata_valid should assert on read response");
		check_cond(bus1_rdata == 16'hCAFE, "bus1_rdata mismatch");
		check_cond(!bus0_rdata_valid, "bus0_rdata_valid should not assert for bus1 read");
		@(posedge clk);
		bus_rdata_valid <= 1'b0;

		// After response, bus0 request should be accepted.
		wait_ready_bus0();
		@(posedge clk);
		bus0_valid <= 1'b0;

		repeat(5) @(posedge clk);
		if( error_count == 0 ) begin
			$display("[TB] ALL TESTS PASSED");
		end
		else begin
			$display("[TB] FAILED with %0d errors", error_count);
		end

		$finish;
	end

	initial begin
		repeat(TIMEOUT_CYCLES * 10) @(posedge clk);
		$display("[TB][TIMEOUT]");
		$finish;
	end
endmodule
