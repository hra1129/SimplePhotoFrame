`timescale 1ns/1ps

module tb;
	localparam integer CLK_HALF_NS = 5;
	localparam integer TIMEOUT_CYCLES = 20000;
	localparam [15:0] ROP_PUT = 16'h0000;
	localparam [15:0] ROP_XOR = 16'h0003;

	logic			clk;
	logic			reset;
	logic			sdram_init_busy;

	logic			bus_cs;
	logic	[4:0]	bus_address;
	logic			bus_valid;
	wire			bus_ready;
	logic			bus_write;
	logic	[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;

	wire	[22:1]	sdram_address;
	wire			sdram_write;
	wire	[15:0]	sdram_wdata;
	wire			sdram_valid;
	wire			sdram_flush;
	logic			sdram_ready;
	logic	[15:0]	sdram_rdata;
	logic			sdram_rdata_valid;

	int error_count;
	int timeout;
	logic [15:0] read_data;
	logic [15:0] status_data;
	logic saw_busy;
	logic [22:1] base_addr;
	int unsigned wait_count;
	int flush_accept_count;

	bit [15:0] mem [int unsigned];
	logic pending_read;
	logic [22:1] pending_read_addr;

	graphic_processor1 u_dut (
		.clk					( clk					),
		.reset					( reset					),
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

	always @(posedge clk) begin
		sdram_rdata_valid <= 1'b0;

		if( pending_read ) begin
			pending_read <= 1'b0;
			if( mem.exists(pending_read_addr) ) begin
				sdram_rdata <= mem[pending_read_addr];
			end
			else begin
				sdram_rdata <= 16'h0000;
			end
			sdram_rdata_valid <= 1'b1;
		end

		if( sdram_flush && !sdram_valid ) begin
			$display("[TB][ERROR] sdram_flush asserted while sdram_valid=0");
			error_count = error_count + 1;
		end

		if( sdram_valid && sdram_ready ) begin
			if( sdram_flush ) begin
				flush_accept_count = flush_accept_count + 1;
			end
			else if( sdram_write ) begin
				mem[sdram_address] = sdram_wdata;
			end
			else begin
				pending_read <= 1'b1;
				pending_read_addr <= sdram_address;
			end
		end
	end

	function automatic [22:1] calc_addr;
		input [22:1] base;
		input [15:0] x;
		input [15:0] y;
	begin
		calc_addr = base + x + ({ 6'd0, y } << 10);
	end
	endfunction

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
		@(negedge clk);
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
		@(negedge clk);
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
			$display("[TB][ERROR] timeout waiting bus_rdata_valid addr=%0d", addr);
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

	task automatic wait_exec_done;
	begin
		saw_busy = 1'b0;
		for( wait_count = 0; wait_count < TIMEOUT_CYCLES; wait_count = wait_count + 1 ) begin
			bus_read_reg(5'h06, status_data);
			if( status_data[0] ) begin
				saw_busy = 1'b1;
			end
			else if( saw_busy ) begin
				disable wait_exec_done;
			end
		end
		$display("[TB][ERROR] timeout waiting EXEC complete");
		error_count = error_count + 1;
	end
	endtask

	task automatic wait_flush_accept;
		input int prev_count;
		int unsigned local_wait;
	begin
		for( local_wait = 0; local_wait < TIMEOUT_CYCLES; local_wait = local_wait + 1 ) begin
			if( flush_accept_count > prev_count ) begin
				disable wait_flush_accept;
			end
			@(posedge clk);
		end
		$display("[TB][ERROR] timeout waiting SDRAM flush accept");
		error_count = error_count + 1;
	end
	endtask

	task automatic prepare_rect_data;
		input [22:1] base;
		input [15:0] sx;
		input [15:0] sy;
		input [15:0] width;
		input [15:0] height;
		input [15:0] seed;
		int x;
		int y;
		reg [22:1] a;
	begin
		for( y = 0; y < height; y = y + 1 ) begin
			for( x = 0; x < width; x = x + 1 ) begin
				a = calc_addr(base, sx + x[15:0], sy + y[15:0]);
				mem[a] = seed + x[15:0] + (y[15:0] << 4);
			end
		end
	end
	endtask

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		sdram_init_busy = 1'b1;
		sdram_ready = 1'b1;
		error_count = 0;
		read_data = 16'h0000;
		status_data = 16'h0000;
		base_addr = 22'd1000;
		flush_accept_count = 0;
		clear_bus();

		repeat(4) @(posedge clk);
		reset = 1'b0;

		repeat(4) @(posedge clk);
		if( bus_ready !== 1'b0 ) begin
			$display("[TB][ERROR] bus_ready must be 0 while sdram_init_busy=1");
			error_count = error_count + 1;
		end

		sdram_init_busy = 1'b0;
		wait_bus_ready();

		$display("[TB] TEST1: register readback");
		bus_write_reg(5'h00, 16'd798);
		bus_write_reg(5'h01, 16'd478);
		bus_write_reg(5'h02, 16'd5);
		bus_write_reg(5'h03, 16'd5);
		bus_write_reg(5'h04, 16'hF800);
		bus_write_reg(5'h05, ROP_PUT);
		bus_write_reg(5'h07, {1'b0, base_addr[15:1]});
		bus_write_reg(5'h08, {9'd0, base_addr[22:16]});

		bus_read_reg(5'h00, read_data); check_eq16(read_data, 16'd798, "SX readback");
		bus_read_reg(5'h01, read_data); check_eq16(read_data, 16'd478, "SY readback");
		bus_read_reg(5'h02, read_data); check_eq16(read_data, 16'd5, "WIDTH readback");
		bus_read_reg(5'h03, read_data); check_eq16(read_data, 16'd5, "HEIGHT readback");
		bus_read_reg(5'h04, read_data); check_eq16(read_data, 16'hF800, "COLOR readback");
		bus_read_reg(5'h05, read_data); check_eq16(read_data, ROP_PUT, "ROP readback");

		prepare_rect_data(base_addr, 16'd796, 16'd476, 16'd6, 16'd6, 16'h0100);

		$display("[TB] TEST2: EXEC PUT with clipping at screen edge");
		timeout = flush_accept_count;
		bus_write_reg(5'h06, 16'h0001);
		wait_exec_done();
		wait_flush_accept(timeout);

		check_eq16(mem[calc_addr(base_addr, 16'd798, 16'd478)], 16'hF800, "PUT p0");
		check_eq16(mem[calc_addr(base_addr, 16'd799, 16'd478)], 16'hF800, "PUT p1");
		check_eq16(mem[calc_addr(base_addr, 16'd798, 16'd479)], 16'hF800, "PUT p2");
		check_eq16(mem[calc_addr(base_addr, 16'd799, 16'd479)], 16'hF800, "PUT p3");
		check_eq16(mem[calc_addr(base_addr, 16'd797, 16'd478)], 16'h0121, "left neighbor unchanged");
		check_eq16(mem[calc_addr(base_addr, 16'd798, 16'd477)], 16'h0112, "upper neighbor unchanged");

		$display("[TB] TEST3: EXEC XOR read-modify-write");
		bus_write_reg(5'h00, 16'd10);
		bus_write_reg(5'h01, 16'd20);
		bus_write_reg(5'h02, 16'd3);
		bus_write_reg(5'h03, 16'd2);
		bus_write_reg(5'h04, 16'h0F0F);
		bus_write_reg(5'h05, ROP_XOR);
		prepare_rect_data(base_addr, 16'd10, 16'd20, 16'd3, 16'd2, 16'h1200);

		timeout = flush_accept_count;
		bus_write_reg(5'h06, 16'h0001);
		wait_exec_done();
		wait_flush_accept(timeout);

		check_eq16(mem[calc_addr(base_addr, 16'd10, 16'd20)], (16'h1200 ^ 16'h0F0F), "XOR p0");
		check_eq16(mem[calc_addr(base_addr, 16'd11, 16'd20)], (16'h1201 ^ 16'h0F0F), "XOR p1");
		check_eq16(mem[calc_addr(base_addr, 16'd12, 16'd20)], (16'h1202 ^ 16'h0F0F), "XOR p2");
		check_eq16(mem[calc_addr(base_addr, 16'd10, 16'd21)], (16'h1210 ^ 16'h0F0F), "XOR p3");
		check_eq16(mem[calc_addr(base_addr, 16'd11, 16'd21)], (16'h1211 ^ 16'h0F0F), "XOR p4");
		check_eq16(mem[calc_addr(base_addr, 16'd12, 16'd21)], (16'h1212 ^ 16'h0F0F), "XOR p5");

		bus_read_reg(5'h06, status_data);
		check_eq16(status_data, 16'h0000, "STATUS idle after complete");

		if( error_count == 0 ) begin
			$display("[TB][PASS] all tests passed");
			$finish;
		end
		else begin
			$display("[TB][FAIL] error_count=%0d", error_count);
			$fatal(1);
		end
	end

	initial begin
		repeat(300000) @(posedge clk);
		$display("[TB][TIMEOUT] simulation timeout");
		$fatal(1);
	end
endmodule
