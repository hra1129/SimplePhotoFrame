// ============================================================================
//	tb.sv - Testbench for qspi.v
//	Test Quad SPI Controller
// ============================================================================

`timescale 1ns/1ps

module tb();
	// Clock and reset signals
	reg				reset;
	reg				clk;
	reg				clk_serial;

	// Serial interface signals
	reg	[2:0]		serial_mode;
	reg	[7:0]		serial_wdata;
	reg				serial_write;
	reg				serial_valid;
	wire			serial_ready;
	wire	[7:0]	serial_rdata;
	wire			serial_rdata_en;
	wire			serial_idle;

	// QSPI interface signals
	wire			qspi_clk;
	wire	[3:0]	qspi_sio;

	// Simulation signals
	reg	[3:0]	qspi_sio_slave;	// Slave device side
	reg			ff_write;		// Latched command direction (1: write, 0: read)
	reg	[7:0]	test_number;	// Current test number for waveform observation
	reg			std_read_drive_en;
	reg	[7:0]	std_read_expect_data;
	integer			total_checks;
	integer			error_count;

	// =====================================================================
	//	Module instantiation
	// =====================================================================
	qspi u_qspi (
		.reset				( reset				),
		.clk				( clk				),
		.clk_serial			( clk_serial		),
		.serial_mode		( serial_mode		),
		.serial_wdata		( serial_wdata		),
		.serial_write		( serial_write		),
		.serial_valid		( serial_valid		),
		.serial_ready		( serial_ready		),
		.serial_rdata		( serial_rdata		),
		.serial_rdata_en	( serial_rdata_en	),
		.serial_idle		( serial_idle		),
		.qspi_clk			( qspi_clk			),
		.qspi_sio			( qspi_sio			)
	);

	// Drive only during read. During write, slave side releases the bus.
	assign qspi_sio = ff_write ? 4'bzzzz : qspi_sio_slave;

	// =====================================================================
	//	Clock generation
	// =====================================================================
	localparam CLK_PERIOD = 100;			// 10 MHz system clock
	localparam CLK_SERIAL_PERIOD = 50;		// 20 MHz serial clock

	initial begin
		clk = 1'b0;
		forever #(CLK_PERIOD/2) clk = ~clk;
	end

	initial begin
		clk_serial = 1'b0;
		forever #(CLK_SERIAL_PERIOD/2) clk_serial = ~clk_serial;
	end

	// =====================================================================
	//	Task definitions
	// =====================================================================
	task initialize();
	begin
		reset = 1'b0;
		serial_mode = 3'd0;
		serial_wdata = 8'd0;
		serial_write = 1'b0;
		serial_valid = 1'b0;
		qspi_sio_slave = 4'd0;
		std_read_drive_en = 1'b0;
		std_read_expect_data = 8'd0;
		ff_write = 1'b0;
		test_number = 8'd0;
		total_checks = 0;
		error_count = 0;
		#(CLK_PERIOD*10) reset = 1'b1;
		#(CLK_PERIOD*10) reset = 1'b0;
		$display( "[%0t] Initialize complete", $time );
	end
	endtask

	task wait_ready();
	begin
		while( !serial_ready ) begin
			@( posedge clk );
		end
	end
	endtask

	task wait_rdata_valid();
	begin
		while( !serial_rdata_en ) begin
			@( posedge clk );
		end
	end
	endtask

	task check_byte(
		input [127:0] check_name,
		input [7:0] expected,
		input [7:0] actual
	);
	begin
		total_checks = total_checks + 1;
		if( actual !== expected ) begin
			error_count = error_count + 1;
			$error( "[%0t] %0s FAILED: expected=0x%02x actual=0x%02x", $time, check_name, expected, actual );
		end
		else begin
			$display( "[%0t] %0s PASSED: expected=0x%02x actual=0x%02x", $time, check_name, expected, actual );
		end
	end
	endtask

	task check_int(
		input [127:0] check_name,
		input integer expected,
		input integer actual
	);
	begin
		total_checks = total_checks + 1;
		if( actual !== expected ) begin
			error_count = error_count + 1;
			$error( "[%0t] %0s FAILED: expected=%0d actual=%0d", $time, check_name, expected, actual );
		end
		else begin
			$display( "[%0t] %0s PASSED: expected=%0d actual=%0d", $time, check_name, expected, actual );
		end
	end
	endtask

	task capture_std_write_byte(
		output [7:0] captured,
		output timeout_hit
	);
		integer bit_idx;
		time wait_timeout;
	begin
		captured = 8'd0;
		timeout_hit = 1'b0;
		wait_timeout = CLK_SERIAL_PERIOD * 40;
		bit_idx = 7;

		while( bit_idx >= 0 && !timeout_hit ) begin
			fork
				begin
					@( posedge qspi_clk );
				end
				begin
					#(wait_timeout);
					timeout_hit = 1'b1;
				end
			join_any
			disable fork;

			if( !timeout_hit ) begin
				captured[bit_idx] = qspi_sio[0];
				bit_idx = bit_idx - 1;
			end
		end
	end
	endtask

	task capture_quad_write_byte(
		output [7:0] captured,
		output timeout_hit
	);
		time wait_timeout;
	begin
		captured = 8'd0;
		timeout_hit = 1'b0;
		wait_timeout = CLK_SERIAL_PERIOD * 40;

		fork
			begin
				@( posedge qspi_clk );
			end
			begin
				#(wait_timeout);
				timeout_hit = 1'b1;
			end
		join_any
		disable fork;
		if( timeout_hit ) begin
			return;
		end
		captured[7:4] = qspi_sio[3:0];

		fork
			begin
				@( posedge qspi_clk );
			end
			begin
				#(wait_timeout);
				timeout_hit = 1'b1;
			end
		join_any
		disable fork;
		if( timeout_hit ) begin
			return;
		end
		captured[3:0] = qspi_sio[3:0];
	end
	endtask

	task run_std_write_check(
		input [7:0] wdata,
		input [127:0] check_name
	);
		reg [7:0] captured;
		reg timeout_hit;
	begin
		timeout_hit = 1'b0;
		fork
			begin
				capture_std_write_byte( captured, timeout_hit );
			end
			begin
				serial_write_byte( 3'd0, wdata );
			end
		join
		if( timeout_hit ) begin
			total_checks = total_checks + 1;
			error_count = error_count + 1;
			$error( "[%0t] %0s FAILED: timeout while capturing STD write stream", $time, check_name );
		end
		else begin
			check_byte( check_name, wdata, captured );
		end
	end
	endtask

	task run_quad_write_check(
		input [7:0] wdata,
		input [127:0] check_name
	);
		reg [7:0] captured;
		reg timeout_hit;
	begin
		timeout_hit = 1'b0;
		fork
			begin
				capture_quad_write_byte( captured, timeout_hit );
			end
			begin
				serial_write_byte( 3'd2, wdata );
			end
		join
		if( timeout_hit ) begin
			total_checks = total_checks + 1;
			error_count = error_count + 1;
			$error( "[%0t] %0s FAILED: timeout while capturing QUAD write stream", $time, check_name );
		end
		else begin
			check_byte( check_name, wdata, captured );
		end
	end
	endtask

	task run_std_read_check(
		input [7:0] expected,
		input [127:0] check_name
	);
		reg [7:0] rdata;
	begin
		serial_read_byte( 3'd1, expected, rdata );
		check_byte( check_name, expected, rdata );
	end
	endtask

	task run_quad_read_check(
		input [7:0] expected,
		input [127:0] check_name
	);
		reg [7:0] rdata;
	begin
		serial_read_byte( 3'd3, expected, rdata );
		check_byte( check_name, expected, rdata );
	end
	endtask

	task run_dummy_clock_check(
		input integer expected_rise,
		input [127:0] check_name
	);
		integer rise_count;
	begin
		dummy_clock( 3'd4, rise_count );
		check_int( check_name, expected_rise, rise_count );
	end
	endtask

	task serial_write_byte(
		input [2:0] mode,
		input [7:0] wdata
	);
	begin
		wait_ready();
		@( posedge clk );
		serial_mode		<= mode;
		serial_wdata	<= wdata;
		serial_write	<= 1'b1;
		serial_valid	<= 1'b1;
		@( posedge clk );
		while( !serial_ready ) begin
			@( posedge clk );
		end
		serial_valid	<= 1'b0;
		@( posedge clk );
		$display( "[%0t] Write command: mode=%0d, data=0x%02x", $time, mode, wdata );
	end
	endtask

	task serial_read_byte(
		input [2:0] mode,
		input [7:0] expect_data,
		output [7:0] rdata
	);
	begin
		std_read_expect_data	<= expect_data;
		std_read_drive_en	<= (mode == 3'd1);
		wait_ready();
		@( posedge clk );
		serial_mode		<= mode;
		serial_write	<= 1'b0;
		serial_valid	<= 1'b1;
		@( posedge clk );
		while( !serial_ready ) begin
			@( posedge clk );
		end
		serial_valid	<= 1'b0;
		@( posedge clk );
		wait_rdata_valid();
		rdata = serial_rdata;
		std_read_drive_en	<= 1'b0;
		$display( "[%0t] Read command(STD): req_mode=%0d, received data=0x%02x", $time, mode, rdata );
	end
	endtask

	task dummy_clock(
		input [2:0] mode,
		output integer rise_count
	);
		time timeout;
	begin
		rise_count = 0;
		timeout = CLK_SERIAL_PERIOD * 120;
		wait_ready();
		@( posedge clk );
		serial_mode		<= mode;
		// Dummy時はff_write=1にして、波形上でDUTのHi-Z状態を観測しやすくする
		serial_write	<= 1'b1;
		serial_valid	<= 1'b1;
		@( posedge clk );
		serial_valid	<= 1'b0;
		fork
			begin
				forever begin
					@( posedge qspi_clk );
					rise_count = rise_count + 1;
				end
			end
			begin
				#(timeout);
			end
		join_any
		disable fork;
		wait_ready();
		$display( "[%0t] Dummy clock: mode=%0d", $time, mode );
	end
	endtask

	// =====================================================================
	//	Slave simulation: respond to read commands
	// =====================================================================
	reg	[7:0]	slave_tx_data;
	reg	[3:0]	slave_bit_count;
	reg	[3:0]	slave_quad_bit_count;
	reg	[7:0]	temp_rdata;	// Temporary storage for read data

	always @( posedge qspi_clk ) begin
		if( reset ) begin
			qspi_sio_slave <= 4'd0;
			slave_tx_data <= 8'd0;
			slave_bit_count <= 4'd0;
			slave_quad_bit_count <= 4'd0;
		end
		else begin
			// For standard SPI read (SIO[1] is MISO)
			if( std_read_drive_en ) begin
				if( slave_bit_count == 4'd0 ) begin
					qspi_sio_slave[1] <= std_read_expect_data[7];
					slave_tx_data <= {std_read_expect_data[6:0], 1'b0};
					slave_bit_count <= 4'd1;
				end
				else if( slave_bit_count == 4'd7 ) begin
					qspi_sio_slave[1] <= slave_tx_data[7];
					slave_tx_data <= {slave_tx_data[6:0], 1'b0};
					slave_bit_count <= 4'd0;
				end
				else begin
					qspi_sio_slave[1] <= slave_tx_data[7];
					slave_bit_count <= slave_bit_count + 4'd1;
					slave_tx_data <= {slave_tx_data[6:0], 1'b0};
				end
			end
			// For quad SPI read (SIO[3:0])
			else if( serial_mode == 3'd3 ) begin
				if( slave_quad_bit_count == 4'd0 ) begin
					slave_tx_data <= std_read_expect_data;
					qspi_sio_slave[3:0] <= std_read_expect_data[7:4];
					slave_quad_bit_count <= 4'd1;
				end
				else begin
					qspi_sio_slave[3:0] <= slave_tx_data[3:0];
					slave_quad_bit_count <= 4'd0;
				end
			end
			else begin
				qspi_sio_slave <= 4'd0;
				slave_bit_count <= 4'd0;
				slave_quad_bit_count <= 4'd0;
			end
		end
	end

	// =====================================================================
	//	Test procedures
	// =====================================================================
	initial begin
		initialize();

		test_number = 8'd1;
		$display( "\n========== Test %0d: Standard SPI Write (0x42) ==========" , test_number );
		run_std_write_check( 8'h42, "Test1 STD Write Data" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd2;
		$display( "\n========== Test %0d: Standard SPI Write 4-byte Sequence ==========" , test_number );
		run_std_write_check( 8'h12, "Test2 STD Write[0]" );
		run_std_write_check( 8'h34, "Test2 STD Write[1]" );
		run_std_write_check( 8'h56, "Test2 STD Write[2]" );
		run_std_write_check( 8'h78, "Test2 STD Write[3]" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd3;
		$display( "\n========== Test %0d: Standard SPI Read ==========" , test_number );
		run_std_read_check( 8'hA3, "Test3 STD Read Data" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd4;
		$display( "\n========== Test %0d: Quad SPI Write ==========" , test_number );
		run_quad_write_check( 8'h5C, "Test4 Quad Write Data" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd5;
		$display( "\n========== Test %0d: Quad SPI Read ==========" , test_number );
		run_quad_read_check( 8'h3A, "Test5 Quad Read Data" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd6;
		$display( "\n========== Test %0d: Quad SPI Dummy Clock ==========" , test_number );
		run_dummy_clock_check( 4, "Test6 Dummy Clock Rise Count" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd7;
		$display( "\n========== Test %0d: Sequential operations ==========" , test_number );
		run_std_write_check( 8'h12, "Test7 Seq STD Write Cmd" );
		run_std_write_check( 8'h34, "Test7 Seq STD Write Data" );
		run_std_read_check( 8'hA5, "Test7 Seq STD Read Data" );
		#(CLK_SERIAL_PERIOD*80);

		test_number = 8'd0;
		$display( "\n========== All tests completed ==========" );
		$display( "Total checks : %0d", total_checks );
		$display( "Total errors : %0d", error_count );
		if( error_count == 0 ) begin
			$display( "RESULT       : PASS" );
		end
		else begin
			$display( "RESULT       : FAIL" );
		end
		#(CLK_PERIOD*100) $finish;
	end

	// =====================================================================
	//	Monitoring
	// =====================================================================
	always @( posedge serial_rdata_en ) begin
		$display( "[%0t] Read data received: 0x%02x", $time, serial_rdata );
	end

	always @( serial_ready ) begin
		$display( "[%0t] serial_ready = %b", $time, serial_ready );
	end

	always @( posedge clk ) begin
		if( reset ) begin
			ff_write <= 1'b0;
		end
		else if( serial_valid && serial_ready ) begin
			ff_write <= serial_write;
		end

		if( serial_valid && serial_ready ) begin
			$display( "[%0t] [CLK] Command accepted: mode=%0d, write=%b, wdata=0x%02x", 
				$time, serial_mode, serial_write, serial_wdata );
		end
	end



endmodule
