// ---------------------------------------------------------
//	SimplePhotoFrame
//	Copyright 2026 Takayuki Hara
// ---------------------------------------------------------

module simple_photo_frame (
	input			clk27m,			//	PIN04
	//	LCD
	output			lcd_ck,			//	PIN77
	output			lcd_hs,			//	PIN25
	output			lcd_vs,			//	PIN26
	output			lcd_de,			//	PIN48
	output	[4:0]	lcd_r,			//	PIN38, PIN39, PIN40, PIN41, PIN42
	output	[5:0]	lcd_g,			//	PIN32, PIN33, PIN34, PIN35, PIN36, PIN37
	output	[4:0]	lcd_b,			//	PIN27, PIN28, PIN29, PIN30, PIN31
	output			lcd_bl,			//	PIN49
	//	LED
	output	[7:0]	led,			//	PIN72, PIN71, PIN20, PIN19, PIN18, PIN17, PIN16, PIN15
	//	SPI
	input			fpga_spi_cs_n,	//	PIN73
	input			fpga_spi_sck,	//	PIN74
	input			fpga_spi_mosi,	//	PIN75
	output			fpga_spi_miso,	//	PIN85
	output			fpga_spi_intr,	//	PIN80
	//	Audio
	output			i2s_bclk,		//	PIN56
	output			i2s_dout,		//	PIN54
	output			i2s_en,			//	PIN51
	output			i2s_lrck,		//	PIN49
	//	FullColorLED
	output			ws2812,			//	PIN79
	//	Button
	input	[1:0]	button,			//	PIN87, PIN88
	//	SDRAM
	output			O_sdram_clk,	//	GOWIN FPGA Internal
	output			O_sdram_cke,	//	GOWIN FPGA Internal
	output			O_sdram_cs_n,	//	GOWIN FPGA Internal
	output			O_sdram_ras_n,	//	GOWIN FPGA Internal
	output			O_sdram_cas_n,	//	GOWIN FPGA Internal
	output			O_sdram_wen_n,	//	GOWIN FPGA Internal
	inout	[31:0]	IO_sdram_dq,	//	GOWIN FPGA Internal
	output	[10:0]	O_sdram_addr,	//	GOWIN FPGA Internal
	output	[ 1:0]	O_sdram_ba,		//	GOWIN FPGA Internal
	output	[ 3:0]	O_sdram_dqm		//	GOWIN FPGA Internal
);
	wire			clk132m;
	wire			clk132m_n;
	reg				ff_reset = 1'b1;
	wire			bus_io;
	wire	[7:0]	bus_address;
	wire			bus_valid;
	wire			bus_ready;
	wire			bus_write;
	wire	[15:0]	bus_wdata;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			sdram_init_busy;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	wire			sdram_address_ready;
	wire	[31:0]	sdram_rdata;
	wire			sdram_rdata_valid;
	wire	[31:0]	sdram_wdata;
	wire			sdram_write;
	wire			sdram_refresh;
	wire			sdram_wdata_valid;
	wire	[3:0]	sdram_wdata_mask;

	// ---------------------------------------------------------
	//	クロック生成
	// ---------------------------------------------------------
    Gowin_rPLL u_rpll (
        .clkout					( clk132m				),		//	132MHz
        .clkoutp				( clk132m_n				),		//	132MHz (inverted)
        .clkin					( clk27m				)		//	27MHz
    );

	// ---------------------------------------------------------
	//	リセット生成
	// ---------------------------------------------------------
	always @( posedge clk132m ) begin
		ff_reset <= 1'b0;
	end

	// ---------------------------------------------------------
	//	SPI Slave Interface
	// ---------------------------------------------------------
	ip_spi u_ip_spi (
		.reset					( ff_reset				),
		.clk					( clk132m				),
		.clk_serial				( clk132m				),
		.bus_io					( bus_io				),
		.bus_write				( bus_write				),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_wdata				( bus_wdata				),
		.bus_address			( bus_address			),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.spi_cs_n				( fpga_spi_cs_n			),
		.spi_clk				( fpga_spi_sck			),
		.spi_mosi				( fpga_spi_mosi			),
		.spi_miso				( fpga_spi_miso			),
		.spi_intr				( fpga_spi_intr			)
	);

	// ---------------------------------------------------------
	//	表示コントローラ
	// ---------------------------------------------------------
	display_controller u_display_controller (
		.clk					( clk132m				),
		.reset					( ff_reset				),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_address			( bus_address			),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_en			),
		.lcd_ck					( lcd_ck				),
		.lcd_hs					( lcd_hs				),
		.lcd_vs					( lcd_vs				),
		.lcd_de					( lcd_de				),
		.lcd_r					( lcd_r					),
		.lcd_g					( lcd_g					),
		.lcd_b					( lcd_b					),
		.lcd_bl					( lcd_bl				),
		.sdram_address			( sdram_address			),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	SDRAMコントローラ
	// ---------------------------------------------------------
	assign sdram_write	= 1'b0;	// 読み出し専用
	assign sdram_refresh = 1'b0;
	assign sdram_wdata = 32'd0;
	assign sdram_wdata_mask = 4'hF;
	assign sdram_wdata_valid = 1'b0;

	ip_sdram u_sdram_controller (
		.clk					( clk132m				),
		.clk_sdram				( clk132m_n				),
		.reset					( ff_reset				),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_address			( sdram_address			),
		.bus_write				( sdram_write			),
		.bus_refresh			( sdram_refresh			),
		.bus_valid				( sdram_address_valid	),
		.bus_ready				( sdram_address_ready	),
		.bus_wdata				( sdram_wdata			),
		.bus_wdata_mask			( sdram_wdata_mask		),
		.bus_wdata_valid		( sdram_wdata_valid		),
		.bus_rdata				( sdram_rdata			),
		.bus_rdata_valid		( sdram_rdata_valid		),
		.O_sdram_clk			( O_sdram_clk			),
		.O_sdram_cke			( O_sdram_cke			),
		.O_sdram_cs_n			( O_sdram_cs_n			),		// chip select
		.O_sdram_ras_n			( O_sdram_ras_n			),		// row address select
		.O_sdram_cas_n			( O_sdram_cas_n			),		// columns address select
		.O_sdram_wen_n			( O_sdram_wen_n			),		// write enable
		.IO_sdram_dq			( IO_sdram_dq			),		// 32 bit bidirectional data bus
		.O_sdram_addr			( O_sdram_addr			),		// 11 bit multiplexed address bus
		.O_sdram_ba				( O_sdram_ba			),		// two banks
		.O_sdram_dqm			( O_sdram_dqm			)		// data mask
	);

	assign i2s_bclk	= 1'b1;
	assign i2s_dout	= 1'b1;
	assign i2s_en	= 1'b0;
	assign i2s_lrck	= 1'b1;
	assign led		= 8'h00;
	assign ws2812	= 1'b0;
endmodule
