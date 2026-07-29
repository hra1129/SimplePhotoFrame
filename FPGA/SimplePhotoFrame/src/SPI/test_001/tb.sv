`timescale 1ns/1ps

module tb;
	localparam real CLK_HALF_NS = 4.62963;   // 108MHz
	localparam real SCLK_HALF_NS = 15.625;   // 32MHz
	localparam integer BYTE_GAP_NS = 80;
	localparam integer CS_SETUP_NS = 240;
	localparam integer CS_HOLD_NS = 20;
	localparam integer CS_IDLE_NS = 50;

	reg				reset;
	reg				clk;
	reg				clk_serial;

	wire	[7:0]	bus_cs;
	wire			bus_write;
	wire			bus_valid;
	reg				bus_ready;
	reg				bus_ready_override;
	wire	[15:0]	bus_wdata;
	wire	[4:0]	bus_address;
	reg		[15:0]	bus_rdata;
	reg				bus_rdata_en;

	reg				spi_cs_n;
	reg				spi_clk;
	reg				spi_mosi;
	wire			spi_miso;
	wire			spi_intr;

	reg			obs_write_seen;
	reg			obs_read_seen;
	reg	[7:0]	obs_bus_cs;
	reg	[4:0]	obs_bus_address;
	reg			obs_bus_write;
	reg	[15:0]	obs_bus_wdata;

	reg		[15:0]	regfile [0:255];
	integer			index;

	// --------------------------------------------------------------------
	// DUT
	// --------------------------------------------------------------------
	ip_spi u_dut (
		.reset			( reset			),
		.clk			( clk			),
		.clk_serial		( clk_serial	),
		.bus_cs			( bus_cs		),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_address	( bus_address	),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.spi_cs_n		( spi_cs_n		),
		.spi_clk		( spi_clk		),
		.spi_mosi		( spi_mosi		),
		.spi_miso		( spi_miso		),
		.spi_intr		( spi_intr		)
	);

	always #(CLK_HALF_NS) begin
		clk <= ~clk;
	end

	always #(CLK_HALF_NS) begin
		clk_serial <= ~clk_serial;
	end

	function [2:0] onehot_to_triple;
		input [7:0] onehot;
		begin
			case (onehot)
			8'h01: onehot_to_triple = 3'd0;
			8'h02: onehot_to_triple = 3'd1;
			8'h04: onehot_to_triple = 3'd2;
			8'h08: onehot_to_triple = 3'd3;
			8'h10: onehot_to_triple = 3'd4;
			8'h20: onehot_to_triple = 3'd5;
			8'h40: onehot_to_triple = 3'd6;
			8'h80: onehot_to_triple = 3'd7;
			default: onehot_to_triple = 3'd0;
			endcase
		end
	endfunction

	// Simple bus model
	always @(posedge clk) begin
		if (reset) begin
			bus_ready <= 1'b0;
			bus_ready_override <= 1'b0;
			bus_rdata <= 16'h0000;
			bus_rdata_en <= 1'b0;
			obs_write_seen <= 1'b0;
			obs_read_seen <= 1'b0;
			obs_bus_cs <= 8'h00;
			obs_bus_address <= 5'h00;
			obs_bus_write <= 1'b0;
			obs_bus_wdata <= 16'h0000;
		end
		else begin
			bus_ready <= bus_valid ? 1'b1 : bus_ready_override;
			bus_rdata_en <= bus_valid & ~bus_write;

			if (bus_valid && bus_write) begin
				obs_write_seen <= 1'b1;
				obs_bus_cs <= bus_cs;
				obs_bus_address <= bus_address;
				obs_bus_write <= bus_write;
				obs_bus_wdata <= bus_wdata;
			end

			if (bus_valid && !bus_write) begin
				obs_read_seen <= 1'b1;
				obs_bus_cs <= bus_cs;
				obs_bus_address <= bus_address;
				obs_bus_write <= bus_write;
			end

			if (bus_valid) begin
				index = {onehot_to_triple(bus_cs), bus_address};
				if (bus_write) begin
					regfile[index] <= bus_wdata;
				end
				else begin
					bus_rdata <= regfile[index];
				end
			end
		end
	end

	task automatic spi_transfer_byte;
		input [7:0] tx_data;
		output [7:0] rx_data;
		input bit wait_for_intr;
		integer bit_i;
		integer wait_count;
		begin
			rx_data = 8'h00;
			if (wait_for_intr) begin
				wait_count = 0;
				while (spi_intr !== 1'b1) begin
					if (wait_count > 10000) begin
						$display("[TB][ERROR] spi_intr wait timeout");
						$stop;
					end
					@(posedge clk);
					wait_count = wait_count + 1;
				end
			end
			for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
				spi_mosi = tx_data[bit_i];
				#(SCLK_HALF_NS);
				spi_clk = 1'b1;
				#(SCLK_HALF_NS * 0.5);  // Wait for DUT response
				rx_data[bit_i] = spi_miso;
				#(SCLK_HALF_NS * 0.5);
				spi_clk = 1'b0;
			end
			#(BYTE_GAP_NS);
		end
	endtask

	task automatic spi_io_write;
		input [7:0] io_addr;
		input [15:0] wr_data;
		reg [7:0] dummy;
		begin
			spi_cs_n = 1'b0;
			#(CS_SETUP_NS);
			spi_transfer_byte(8'h01, dummy, 1'b0);
			spi_transfer_byte(io_addr, dummy, 1'b0);
			spi_transfer_byte(wr_data[7:0], dummy, 1'b0);
			spi_transfer_byte(wr_data[15:8], dummy, 1'b0);
			#(CS_HOLD_NS);
			spi_cs_n = 1'b1;
			#(CS_IDLE_NS);
		end
	endtask

	task automatic spi_io_read;
		input [7:0] io_addr;
		output [15:0] rd_data;
		reg [7:0] rx0;
		reg [7:0] rx1;
		reg [7:0] rx2;
		reg [7:0] rx3;
		begin
			spi_cs_n = 1'b0;
			#(CS_SETUP_NS);
			spi_transfer_byte(8'h02, rx0, 1'b0);
			spi_transfer_byte(io_addr, rx1, 1'b0);
			spi_transfer_byte(8'h00, rx2, 1'b1);
			spi_transfer_byte(8'h00, rx3, 1'b1);
			rd_data = {rx3, rx2};
			#(CS_HOLD_NS);
			spi_cs_n = 1'b1;
			#(CS_IDLE_NS);
		end
	endtask

	task automatic spi_status_read;
		output [7:0] response;
		reg [7:0] rx0;
		reg [7:0] rx1;
		reg [7:0] rx2;
		begin
			spi_cs_n = 1'b0;
			#(CS_SETUP_NS);
			spi_transfer_byte(8'h03, rx0, 1'b0);
			spi_transfer_byte(8'h00, rx1, 1'b0);
			spi_transfer_byte(8'h00, rx2, 1'b1);
			response = rx2;
			#(CS_HOLD_NS);
			spi_cs_n = 1'b1;
			#(CS_IDLE_NS);
		end
	endtask

	reg [15:0] rd_data;
	reg [7:0] busy_resp;
	integer k;
	integer addr_i;
	integer wait_i;
	integer test_number;
	reg [15:0] rand_wdata;
	reg [7:0] exp_bus_cs;
	initial begin
		clk = 1'b0;
		clk_serial = 1'b0;
		reset = 1'b1;
		spi_cs_n = 1'b1;
		spi_clk = 1'b0;
		spi_mosi = 1'b0;
		bus_ready = 1'b0;
		bus_rdata = 16'h0000;
		bus_rdata_en = 1'b0;
		rd_data = 16'h0000;
		test_number = 0;

		for (k = 0; k < 256; k = k + 1) begin
			regfile[k] = 16'h1000 + k[15:0];
		end

		repeat (20) @(posedge clk);
		reset = 1'b0;
		repeat (10) @(posedge clk);

		// I/O Write test: 00h-FFh all addresses with random 16bit data.
		test_number = 1;
		$display("[TB][TEST %0d] I/O Write 00h-FFh all addresses with random 16bit data", test_number);
		for (addr_i = 0; addr_i < 256; addr_i = addr_i + 1) begin
			rand_wdata = $urandom;
			exp_bus_cs = 8'h01 << addr_i[7:5];

			obs_write_seen = 1'b0;
			spi_io_write(addr_i[7:0], rand_wdata);
			wait_i = 0;
			while (!obs_write_seen && (wait_i < 2000)) begin
				@(posedge clk);
				wait_i = wait_i + 1;
			end

			if (!obs_write_seen) begin
				$display("[TB][ERROR] I/O Write not observed addr=%02h", addr_i[7:0]);
				$stop;
			end
			if (obs_bus_cs !== exp_bus_cs) begin
				$display("[TB][ERROR] bus_cs mismatch addr=%02h got=%02h exp=%02h", addr_i[7:0], obs_bus_cs, exp_bus_cs);
				$stop;
			end
			if (obs_bus_address !== addr_i[4:0]) begin
				$display("[TB][ERROR] bus_address mismatch addr=%02h got=%02h exp=%02h", addr_i[7:0], obs_bus_address, addr_i[4:0]);
				$stop;
			end
			if (obs_bus_write !== 1'b1) begin
				$display("[TB][ERROR] bus_write mismatch addr=%02h got=%b exp=1", addr_i[7:0], obs_bus_write);
				$stop;
			end
			if (obs_bus_wdata !== rand_wdata) begin
				$display("[TB][ERROR] bus_wdata mismatch addr=%02h got=%04h exp=%04h", addr_i[7:0], obs_bus_wdata, rand_wdata);
				$stop;
			end
		end
		$display("[TB] I/O Write 00h-FFh check passed");

		// I/O Read test: 00h-FFh all addresses and compare returned data.
		test_number = 2;
		$display("[TB][TEST %0d] I/O Read 00h-FFh all addresses and compare returned data", test_number);
		for (addr_i = 0; addr_i < 256; addr_i = addr_i + 1) begin
			exp_bus_cs = 8'h01 << addr_i[7:5];

			obs_read_seen = 1'b0;
			spi_io_read(addr_i[7:0], rd_data);
			wait_i = 0;
			while (!obs_read_seen && (wait_i < 5000)) begin
				@(posedge clk);
				wait_i = wait_i + 1;
			end

			if (!obs_read_seen) begin
				$display("[TB][ERROR] I/O Read not observed addr=%02h", addr_i[7:0]);
				$stop;
			end
			if (obs_bus_cs !== exp_bus_cs) begin
				$display("[TB][ERROR] bus_cs mismatch(read) addr=%02h got=%02h exp=%02h", addr_i[7:0], obs_bus_cs, exp_bus_cs);
				$stop;
			end
			if (obs_bus_address !== addr_i[4:0]) begin
				$display("[TB][ERROR] bus_address mismatch(read) addr=%02h got=%02h exp=%02h", addr_i[7:0], obs_bus_address, addr_i[4:0]);
				$stop;
			end
			if (obs_bus_write !== 1'b0) begin
				$display("[TB][ERROR] bus_write mismatch(read) addr=%02h got=%b exp=0", addr_i[7:0], obs_bus_write);
				$stop;
			end
			if (rd_data !== regfile[addr_i]) begin
				$display("[TB][ERROR] I/O Read data mismatch addr=%02h got=%04h exp=%04h", addr_i[7:0], rd_data, regfile[addr_i]);
				$stop;
			end
		end
		$display("[TB] I/O Read 00h-FFh check passed");

// Status read test: command 03h returns bit0 = bus_ready.
	test_number = 3;
	$display("[TB][TEST %0d] Status read command 03h returns bit0 of bus_ready", test_number);
	bus_ready_override = 1'b1;
	spi_status_read(busy_resp);
	if (busy_resp !== 8'h01) begin
		$display("[TB][ERROR] status read response mismatch got=%02h exp=%02h", busy_resp, 8'h01);
		$stop;
	end

	bus_ready_override = 1'b0;
	spi_status_read(busy_resp);
	if (busy_resp !== 8'h00) begin
		$display("[TB][ERROR] status read response mismatch got=%02h exp=%02h", busy_resp, 8'h00);
		$stop;
	end
	$display("[TB] Status read 03h passed");

		repeat (200) @(posedge clk);
		$display("[TB] finish");
		$finish;
	end

	initial begin
		repeat (100000) @(posedge clk);
		$display("[TB][TIMEOUT] finish by timeout");
		$stop;
	end
endmodule
