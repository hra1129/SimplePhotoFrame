`timescale 1ns/1ps

module tb;
	localparam real CLK27M_HALF_PERIOD_NS	= 1000000000.0 / (27000000.0 * 2.0);   // 27MHz
	localparam real SCLK_HALF_NS			= 1000000000.0 / (50000000.0 * 2.0);   // 50MHz

	localparam [7:0] IO_DISPLAY		= (0 << 5);
	localparam [7:0] IO_GRAPHIC1	= (1 << 5);
	localparam [7:0] IO_GRAPHIC2	= (2 << 5);
	localparam [7:0] IO_VRAM		= (6 << 5);
	localparam [7:0] IO_CONFIG		= (7 << 5);

	localparam [7:0] IO_VRAM_ADDRESS_L	= 8'h00;
	localparam [7:0] IO_VRAM_ADDRESS_H	= 8'h01;
	localparam [7:0] IO_VRAM_DATA		= 8'h02;
	localparam [7:0] IO_VRAM_FLUSH		= 8'h03;

	localparam [15:0] C_ROP_PUT  = 16'h0000;
	localparam [15:0] C_ROP_OR   = 16'h0001;
	localparam [15:0] C_ROP_AND  = 16'h0002;
	localparam [15:0] C_ROP_XOR  = 16'h0003;
	localparam [15:0] C_ROP_ADD  = 16'h0004;
	localparam [15:0] C_ROP_SUB  = 16'h0005;
	localparam [15:0] C_ROP_MIX  = 16'h0006;
	localparam [15:0] C_ROP_MIN  = 16'h0007;
	localparam [15:0] C_ROP_MAX  = 16'h0008;

	integer		test_number = 0;
	reg			clk27m;
	reg			fpga_spi_cs_n;
	reg			fpga_spi_sck;
	reg			fpga_spi_mosi;
	reg	[1:0]	button;

	wire			lcd_ck;
	wire			lcd_hs;
	wire			lcd_vs;
	wire			lcd_de;
	wire	[4:0]	lcd_r;
	wire	[5:0]	lcd_g;
	wire	[4:0]	lcd_b;
	wire			lcd_bl;
	wire	[7:0]	led;
	wire			fpga_spi_miso;
	wire			fpga_spi_intr;
	wire			i2s_bclk;
	wire			i2s_dout;
	wire			i2s_en;
	wire			i2s_lrck;
	wire			ws2812;
	wire			O_sdram_clk;
	wire			O_sdram_cke;
	wire			O_sdram_cs_n;
	wire			O_sdram_ras_n;
	wire			O_sdram_cas_n;
	wire			O_sdram_wen_n;
	wire	[31:0]	IO_sdram_dq;
	wire	[10:0]	O_sdram_addr;
	wire	[1:0]	O_sdram_ba;
	wire	[3:0]	O_sdram_dqm;
	int				i;
	reg		[15:0]	vram_expected;
	reg		[15:0]	vram_readback;
	logic	[4:0]	d;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	simple_photo_frame u_dut (
		.clk27m				( clk27m			),
		.lcd_ck				( lcd_ck			),
		.lcd_hs				( lcd_hs			),
		.lcd_vs				( lcd_vs			),
		.lcd_de				( lcd_de			),
		.lcd_r				( lcd_r				),
		.lcd_g				( lcd_g				),
		.lcd_b				( lcd_b				),
		.lcd_bl				( lcd_bl			),
		.led				( led				),
		.fpga_spi_cs_n		( fpga_spi_cs_n		),
		.fpga_spi_sck		( fpga_spi_sck		),
		.fpga_spi_mosi		( fpga_spi_mosi		),
		.fpga_spi_miso		( fpga_spi_miso		),
		.fpga_spi_intr		( fpga_spi_intr		),
		.i2s_bclk			( i2s_bclk			),
		.i2s_dout			( i2s_dout			),
		.i2s_en				( i2s_en			),
		.i2s_lrck			( i2s_lrck			),
		.ws2812				( ws2812			),
		.button				( button			),
		.O_sdram_clk		( O_sdram_clk		),
		.O_sdram_cke		( O_sdram_cke		),
		.O_sdram_cs_n		( O_sdram_cs_n		),
		.O_sdram_ras_n		( O_sdram_ras_n		),
		.O_sdram_cas_n		( O_sdram_cas_n		),
		.O_sdram_wen_n		( O_sdram_wen_n		),
		.IO_sdram_dq		( IO_sdram_dq		),
		.O_sdram_addr		( O_sdram_addr		),
		.O_sdram_ba			( O_sdram_ba		),
		.O_sdram_dqm		( O_sdram_dqm		)
	);

	// --------------------------------------------------------------------
	//	SDRAM model
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

	// ---------------------------------------------------------
	always #(CLK27M_HALF_PERIOD_NS) begin
		clk27m <= ~clk27m;
	end

	// ---------------------------------------------------------
	task automatic spi_send_byte;
		input [7:0] data;
		integer i;
		begin
			for( i = 7; i >= 0; i = i - 1 ) begin
				fpga_spi_mosi = data[i];
				#(SCLK_HALF_NS);
				fpga_spi_sck = 1'b1;
				#(SCLK_HALF_NS);
				fpga_spi_sck = 1'b0;
			end
			#80;
		end
	endtask

	// ---------------------------------------------------------
	task automatic spi_transfer_byte;
		input [7:0] tx_data;
		output [7:0] rx_data;
		input bit wait_for_intr;
		integer i;
		begin
			rx_data = 8'h00;
			if( wait_for_intr ) begin
				// fpga_spi_intr is not guaranteed to align with clk27m,
				// so wait on the interrupt edge directly.
				if( fpga_spi_intr !== 1'b1 ) begin
					fork
						begin : wait_intr_edge
							@( posedge fpga_spi_intr );
						end
						begin : wait_intr_timeout
							#50000;
							$display("[TB][ERROR] fpga_spi_intr wait timeout");
							$stop;
						end
					join_any
					disable fork;
				end
			end
			for( i = 7; i >= 0; i = i - 1 ) begin
				fpga_spi_mosi = tx_data[i];
				#(SCLK_HALF_NS);
				fpga_spi_sck	= 1'b1;
				rx_data[i]		= fpga_spi_miso;
				#(SCLK_HALF_NS);
				fpga_spi_sck	= 1'b0;
			end
			#80;
		end
	endtask

	// ---------------------------------------------------------
	task automatic spi_wait_ready;
		input [7:0] address;
		reg [7:0] status;
		reg [7:0] dummy_rx;
		integer busy_retry;
		begin
			busy_retry = 0;
			while( 1 ) begin
				fpga_spi_cs_n = 1'b0;
				#100;
				spi_transfer_byte(8'h03, dummy_rx, 1'b0);
				spi_transfer_byte(address, dummy_rx, 1'b0);
				spi_transfer_byte(8'h00, status, 1'b1);
				fpga_spi_cs_n = 1'b1;
				#100;
				if( status[0] ) begin
					break;
				end
				busy_retry = busy_retry + 1;
				if( busy_retry > 1000 ) begin
					$display("[TB][ERROR] busy wait timeout");
					$stop;
				end
			end
		end
	endtask

	// ---------------------------------------------------------
	task automatic spi_write16;
		input [7:0] address;
		input [15:0] data;
		begin
			fpga_spi_cs_n = 1'b1;
			fpga_spi_sck = 1'b0;
			#100;

			spi_wait_ready(address);

			fpga_spi_cs_n = 1'b0;
			#100;
			spi_send_byte(8'h01);
			spi_send_byte(address);
			spi_send_byte(data[7:0]);
			spi_send_byte(data[15:8]);
			#100;
			fpga_spi_cs_n = 1'b1;
			#100;
		end
	endtask

	// ---------------------------------------------------------
	task automatic spi_read16;
		input [7:0] address;
		output [15:0] data;
		reg [7:0] data_l;
		reg [7:0] data_h;
		reg [7:0] dummy_rx;
		begin
			data = 16'h0000;
			fpga_spi_cs_n = 1'b1;
			fpga_spi_sck = 1'b0;
			#100;

			spi_wait_ready(address);

			fpga_spi_cs_n = 1'b0;
			#100;
			spi_transfer_byte(8'h02, dummy_rx, 1'b0);
			spi_transfer_byte(address, dummy_rx, 1'b0);
			spi_transfer_byte(8'h00, data_l, 1'b1);
			spi_transfer_byte(8'h00, data_h, 1'b1);
			#100;
			fpga_spi_cs_n = 1'b1;
			#100;

			data = {data_h, data_l};
		end
	endtask

	// ---------------------------------------------------------
	task automatic display_enable(
		input bit enable
	);
		spi_write16(IO_DISPLAY | 8'h02, enable ? 16'h0001 : 16'h0000);
	endtask

	// ---------------------------------------------------------
	task automatic display_set_frame_address(
		input [31:0] address
	);
		spi_write16( IO_DISPLAY | 8'h00, address[15:0] );
		spi_write16( IO_DISPLAY | 8'h01, address[21:16] );
	endtask

	// ---------------------------------------------------------
	task automatic vram_write(
		input [31:0] address,
		input [15:0] data
	);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_L, address[15:0]);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_H, {9'h000, address[22:16]});
		spi_write16(IO_VRAM | IO_VRAM_DATA, data);
	endtask

	// ---------------------------------------------------------
	task automatic vram_read(
		input [31:0] address,
		output [15:0] data
	);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_L, address[15:0]);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_H, {9'h000, address[22:16]});
		spi_read16(IO_VRAM | IO_VRAM_DATA, data);
	endtask

	// ---------------------------------------------------------
	task automatic vram_flush(
	);
		spi_write16(IO_VRAM | IO_VRAM_FLUSH, 16'h0001);
	endtask

	// ---------------------------------------------------------
	task automatic graphic1_set_frame_address(
		input [31:0] address
	);

		spi_write16( IO_GRAPHIC1 | 8'h07, address[15:0] );
		spi_write16( IO_GRAPHIC1 | 8'h08, address[21:16] );
	endtask

	// -----------------------------------------------------------------------------
	task automatic wait_busy_clear(
		input	[7:0]	io_address,
		input	string	s_name
	);
		logic [15:0]	status;

		$display( "[TB] wait_busy_clear(%s)", s_name );
		forever begin
			spi_read16( io_address, status );
			if( status[0] == 1'b0 ) begin
				break;
			end
		end
	endtask

	// -----------------------------------------------------------------------------
	task automatic graphic_wait_complete();

		wait_busy_clear( IO_GRAPHIC1 | 8'h06, "graphic1" );
		wait_busy_clear( IO_GRAPHIC2 | 8'h09, "graphic2" );
	endtask

	// -----------------------------------------------------------------------------
	task automatic graphic1_fill_rectangle(
		input [15:0] sx,
		input [15:0] sy,
		input [15:0] width,
		input [15:0] height,
		input [15:0] color,
		input [15:0] rop
	);
		logic [15:0] status;

		wait_busy_clear( IO_GRAPHIC1 | 8'h06, "graphic1" );
		spi_write16( IO_GRAPHIC1 | 8'h00, sx );
		spi_write16( IO_GRAPHIC1 | 8'h01, sy );
		spi_write16( IO_GRAPHIC1 | 8'h02, width );
		spi_write16( IO_GRAPHIC1 | 8'h03, height );
		spi_write16( IO_GRAPHIC1 | 8'h04, color );
		spi_write16( IO_GRAPHIC1 | 8'h05, rop );
		spi_write16( IO_GRAPHIC1 | 8'h06, 1 );			// start operation
	endtask

	// ---------------------------------------------------------
	task automatic graphic2_set_source_frame_address(
		input	[31:0] address
	);
		spi_write16( IO_GRAPHIC2 | 8'h0A, address[15:0] );
		spi_write16( IO_GRAPHIC2 | 8'h0B, address[21:16] );
	endtask

	// ---------------------------------------------------------
	task automatic graphic2_set_destination_frame_address(
		input	[31:0] address
	);
		spi_write16( IO_GRAPHIC2 | 8'h0C, address[15:0] );
		spi_write16( IO_GRAPHIC2 | 8'h0D, address[21:16] );
	endtask

	// ---------------------------------------------------------
	task automatic graphic2_block_copy(
		input [15:0] sx,
		input [15:0] sy,
		input [15:0] swidth,
		input [15:0] sheight,
		input [15:0] dx,
		input [15:0] dy,
		input [15:0] dwidth,
		input [15:0] dheight,
		input [15:0] rop
	);
		wait_busy_clear( IO_GRAPHIC2 | 8'h09, "graphic2" );
		spi_write16( IO_GRAPHIC2 | 8'h00, sx );
		spi_write16( IO_GRAPHIC2 | 8'h01, sy );
		spi_write16( IO_GRAPHIC2 | 8'h02, swidth );
		spi_write16( IO_GRAPHIC2 | 8'h03, sheight );
		spi_write16( IO_GRAPHIC2 | 8'h04, dx );
		spi_write16( IO_GRAPHIC2 | 8'h05, dy );
		spi_write16( IO_GRAPHIC2 | 8'h06, dwidth );
		spi_write16( IO_GRAPHIC2 | 8'h07, dheight );
		spi_write16( IO_GRAPHIC2 | 8'h08, rop );
		spi_write16( IO_GRAPHIC2 | 8'h09, 1 );			// start operation
	endtask

	initial begin
		clk27m = 1'b0;
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		fpga_spi_mosi = 1'b0;
		button = 2'b11;

		#2000;

		// ---------------------------------------------------------
		test_number = 1;
		$display( "[TB] Set address." );
		display_set_frame_address( 1024 * 480 * 0 );
		graphic2_set_source_frame_address( 1024 * 480 * 1 );
		graphic2_set_destination_frame_address( 1024 * 480 * 2 );

		// ---------------------------------------------------------
		test_number = 2;
		$display( "[TB] Fill rectangle for frame#0." );
		graphic1_set_frame_address( 1024 * 480 * 0 );
		for( i = 0; i < 800; i+=16 ) begin
			graphic1_fill_rectangle( i, 0, 16, 480, {5'h00, 6'h00, i[8:4] }, C_ROP_PUT );	// blue
			wait_busy_clear( IO_GRAPHIC1 | 8'h06, "graphic1" );
		end

		$display( "[TB] Display enable." );
		display_enable( 1'b1 );

		// ---------------------------------------------------------
		test_number = 3;
		$display( "[TB] Fill rectangle for frame#1." );
		graphic1_set_frame_address( 1024 * 480 * 1 );
		graphic1_fill_rectangle( 0, 0, 1024, 480, {5'h00, 6'h3F, 5'h00}, C_ROP_PUT );	// green
		wait_busy_clear( IO_GRAPHIC1 | 8'h06, "graphic1" );

		// ---------------------------------------------------------
		test_number = 4;
		$display( "[TB] Copy frame#1 to frame#0." );
		for( i = 0; i < 4; i++ ) begin
			graphic2_block_copy( 0, 0, 800, 480, 0, 0, 790, 480 * 790 / 800, C_ROP_PUT );
			wait_busy_clear( IO_GRAPHIC2 | 8'h09, "graphic2" );
		end

		// ---------------------------------------------------------
		test_number = 5;
		$display( "[TB] Wait for a few clock cycles." );
		repeat( 10 ) begin
			@( posedge clk27m );
		end
		$display( "[TB] Finish." );
		$finish;
	end
endmodule
