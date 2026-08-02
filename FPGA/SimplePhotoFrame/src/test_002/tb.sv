`timescale 1ns/1ps

module tb;
	localparam integer CLK27M_HALF_PERIOD_NS = 19;
	localparam real SCLK_HALF_NS = 15.625;   // 32MHz
	localparam [7:0] IO_DISPLAY = (0 << 5);
	localparam [7:0] IO_VRAM = (6 << 5);
	localparam [7:0] IO_VRAM_ADDRESS_L	= 8'h00;
	localparam [7:0] IO_VRAM_ADDRESS_H	= 8'h01;
	localparam [7:0] IO_VRAM_DATA		= 8'h02;
	localparam [7:0] IO_VRAM_FLASH		= 8'h03;

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
	reg	[15:0]	vram_expected;
	reg	[15:0]	vram_readback;

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

	always #(CLK27M_HALF_PERIOD_NS) begin
		clk27m <= ~clk27m;
	end

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

	task automatic display_enable(
		input bit enable
	);
		spi_write16(IO_DISPLAY | 8'h02, enable ? 16'h0001 : 16'h0000);
	endtask

	task automatic vram_write(
		input [31:0] address,
		input [15:0] data
	);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_L, address[15:0]);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_H, {9'h000, address[22:16]});
		spi_write16(IO_VRAM | IO_VRAM_DATA, data);
	endtask

	task automatic vram_read(
		input [31:0] address,
		output [15:0] data
	);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_L, address[15:0]);
		spi_write16(IO_VRAM | IO_VRAM_ADDRESS_H, {9'h000, address[22:16]});
		spi_read16(IO_VRAM | IO_VRAM_DATA, data);
	endtask

	task vram_flash(
	);
		spi_write16(IO_VRAM | IO_VRAM_FLASH, 16'h0001);
	endtask

	initial begin
		clk27m = 1'b0;
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		fpga_spi_mosi = 1'b0;
		button = 2'b11;

		#2000;

		//	random write
		for( i = 0; i < 384000; i++ ) begin
			if( i[7:0] == 0 ) begin
				$display("[TB] VRAM write and read %d / 384000", i);
			end
			// Address[0] is unused in vram_accessor ([22:1]), so use half-word aligned addresses.
			vram_expected = i[15:0];
			vram_write( i, vram_expected );
			vram_read( i, vram_readback );
			assert( vram_readback === vram_expected ) else begin
				$display("[TB][ERROR] VRAM mismatch index=%0d addr=%0d expected=%04h got=%04h", i, i, vram_expected, vram_readback);
				$stop;
			end
		end

		vram_flash();
		$display("[TB] VRAM flash done.");

		repeat( 10 ) begin
			$display("[TB] waiting.");
			repeat( 100 ) begin
				@( posedge clk27m );
			end
		end

		$display("[TB] Finsh.");
		$finish;
	end
endmodule
