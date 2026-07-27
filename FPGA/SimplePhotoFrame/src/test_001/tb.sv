`timescale 1ns/1ps

module tb;
	localparam integer CLK27M_HALF_PERIOD_NS = 19;
	localparam [7:0] IO_DISPLAY = (0 << 5);
	localparam [7:0] IO_VRAM = (6 << 5);
	localparam [7:0] IO_VRAM_ADDRESS_L = 8'h00;
	localparam [7:0] IO_VRAM_ADDRESS_H = 8'h01;
	localparam [7:0] IO_VRAM_DATA = 8'h02;

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
		.Dq				( IO_sdram_dq		),
		.Addr			( O_sdram_addr		),
		.Ba				( O_sdram_ba		),
		.Clk			( O_sdram_clk		),
		.Cke			( O_sdram_cke		),
		.Cs_n			( O_sdram_cs_n		),
		.Ras_n			( O_sdram_ras_n		),
		.Cas_n			( O_sdram_cas_n		),
		.We_n			( O_sdram_wen_n		),
		.Dqm			( O_sdram_dqm		)
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
				#20;
				fpga_spi_sck = 1'b1;
				#20;
				fpga_spi_sck = 1'b0;
			end
		end
	endtask

	task automatic spi_write8;
		input [7:0] address;
		input [7:0] data;
		begin
			fpga_spi_cs_n = 1'b1;
			fpga_spi_sck = 1'b0;
			#100;
			fpga_spi_cs_n = 1'b0;
			#100;
			spi_send_byte(8'h01);
			spi_send_byte(address);
			spi_send_byte(data);
			#100;
			fpga_spi_cs_n = 1'b1;
			#100;
		end
	endtask

	task automatic spi_write16;
		input [7:0] address;
		input [15:0] data;
		begin
			fpga_spi_cs_n = 1'b1;
			fpga_spi_sck = 1'b0;
			#100;
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

	initial begin
		clk27m = 1'b0;
		fpga_spi_cs_n = 1'b1;
		fpga_spi_sck = 1'b0;
		fpga_spi_mosi = 1'b0;
		button = 2'b11;

		#2000;

		// SPIの最低限トラフィックを流して、DUT内部のバス経路を動作させる
		spi_write8(8'h00, 8'h00);
		spi_write8(8'h01, 8'h01);
		spi_write8(8'h02, 8'h02);

		repeat( 1000 * 525 * 3 ) @( posedge clk27m );

		if( i2s_bclk !== 1'b1 ) begin
			$display("[TB][ERROR] i2s_bclk expected 1 but got %b", i2s_bclk);
			$stop;
		end
		if( i2s_dout !== 1'b1 ) begin
			$display("[TB][ERROR] i2s_dout expected 1 but got %b", i2s_dout);
			$stop;
		end
		if( i2s_en !== 1'b0 ) begin
			$display("[TB][ERROR] i2s_en expected 0 but got %b", i2s_en);
			$stop;
		end
		if( i2s_lrck !== 1'b1 ) begin
			$display("[TB][ERROR] i2s_lrck expected 1 but got %b", i2s_lrck);
			$stop;
		end
		if( led !== 8'h00 ) begin
			$display("[TB][ERROR] led expected 00h but got %02h", led);
			$stop;
		end
		if( ws2812 !== 1'b0 ) begin
			$display("[TB][ERROR] ws2812 expected 0 but got %b", ws2812);
			$stop;
		end

		$display("[TB] PASS");
		$finish;
	end

	initial begin
		repeat( 100 ) @( posedge clk27m );

		//	Display Controller enable
		display_enable( 1'b1 );

		//	random write
		vram_write( 0, 16'hABCD );
		vram_write( 1, 16'hBCDE );
		vram_write( 2, 16'hDEF0 );
		vram_write( 3, 16'hEF01 );

		$display("[TB][TIMEOUT] Simulation timeout");
		$stop;
	end
endmodule
