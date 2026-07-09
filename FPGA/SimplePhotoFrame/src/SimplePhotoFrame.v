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
	wire			clk108m;
	wire			clk108m_n;
	reg				ff_reset_bus = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_spi = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_gp1 = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_gp2 = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_display = 1'b1;	/* synthesis syn_preserve = 1 */
	reg				ff_reset_vram = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_sdram = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_cache = 1'b1;		/* synthesis syn_preserve = 1 */
	wire	[7:0]	bus_io_cs;
	wire	[4:0]	bus_io_address;
	wire			bus_io_valid;
	wire			bus_io_ready;
	wire			bus_io_write;
	wire	[15:0]	bus_io_wdata;
	wire	[15:0]	bus_io_rdata;
	wire			bus_io_rdata_en;
	wire			bus_qspi_ready;
	wire	[7:0]	bus_qspi_rdata;
	wire			bus_qspi_rdata_en;
	wire			display_bus_ready;
	wire	[15:0]	display_bus_rdata;
	wire			display_bus_rdata_valid;
	wire			gp1_bus_ready;
	wire	[15:0]	gp1_bus_rdata;
	wire			gp1_bus_rdata_valid;
	wire			gp2_bus_ready;
	wire	[15:0]	gp2_bus_rdata;
	wire			gp2_bus_rdata_valid;
	wire			vram_bus_ready;
	wire	[15:0]	vram_bus_rdata;
	wire			vram_bus_rdata_valid;
	wire	[22:1]	bus0_address;
	wire			bus0_write;
	wire	[15:0]	bus0_wdata;
	wire			bus0_flash;
	wire			bus0_valid;
	wire			bus0_ready;
	wire	[15:0]	bus0_rdata;
	wire			bus0_rdata_valid;
	wire	[22:1]	bus1_address;
	wire			bus1_write;
	wire	[15:0]	bus1_wdata;
	wire			bus1_flash;
	wire			bus1_valid;
	wire			bus1_ready;
	wire	[15:0]	bus1_rdata;
	wire			bus1_rdata_valid;
	wire	[22:1]	bus2_address;
	wire			bus2_write;
	wire	[15:0]	bus2_wdata;
	wire			bus2_flash;
	wire			bus2_valid;
	wire			bus2_ready;
	wire	[15:0]	bus2_rdata;
	wire			bus2_rdata_valid;
	wire	[22:1]	bus3_address;
	wire			bus3_write;
	wire	[15:0]	bus3_wdata;
	wire			bus3_flash;
	wire			bus3_valid;
	wire			bus3_ready;
	wire	[15:0]	bus3_rdata;
	wire			bus3_rdata_valid;
	wire			sdram_init_busy;
	wire	[22:1]	bus_address;
	wire			bus_write;
	wire	[15:0]	bus_wdata;
	wire			bus_flash;
	wire			bus_valid;
	wire			bus_ready;
	wire	[15:0]	bus_rdata;
	wire			bus_rdata_valid;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	wire			sdram_address_ready;
	wire	[31:0]	sdram_rdata;
	wire			sdram_rdata_valid;
	wire	[22:5]	disp_sdram_address;
	wire			disp_sdram_address_valid;
	wire			disp_sdram_address_ready;
	wire	[31:0]	disp_sdram_rdata;
	wire			disp_sdram_rdata_valid;
	wire	[31:0]	sdram_wdata;
	wire			sdram_write;
	wire			sdram_refresh;
	wire			sdram_wdata_valid;
	wire	[3:0]	sdram_wdata_mask;
	wire			srom0_cs_n;
	wire			srom1_cs_n;
	wire			srom_clk;
	wire	[3:0]	srom_sio;

	// ---------------------------------------------------------
	//	クロック生成
	// ---------------------------------------------------------
	Gowin_rPLL u_rpll (
		.clkout					( clk108m				),		//	108MHz
		.clkoutp				( clk108m_n				),		//	108MHz (inverted)
		.clkin					( clk27m				)		//	27MHz
	);

	// ---------------------------------------------------------
	//	リセット生成
	// ---------------------------------------------------------
	always @( posedge clk108m ) begin
		ff_reset_spi		<= 1'b0;
		ff_reset_gp1		<= 1'b0;
		ff_reset_gp2		<= 1'b0;
		ff_reset_display	<= 1'b0;
		ff_reset_vram		<= 1'b0;
		ff_reset_sdram		<= 1'b0;
		ff_reset_cache		<= 1'b0;
	end

	// ---------------------------------------------------------
	//	SPI Slave Interface
	// ---------------------------------------------------------
	ip_spi u_ip_spi (
		.reset					( ff_reset_spi			),
		.clk					( clk108m				),
		.clk_serial				( clk108m				),
		.bus_cs					( bus_io_cs				),
		.bus_write				( bus_io_write			),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( bus_io_ready			),
		.bus_wdata				( bus_io_wdata			),
		.bus_address			( bus_io_address		),
		.bus_rdata				( bus_io_rdata			),
		.bus_rdata_en			( bus_io_rdata_en		),
		.spi_cs_n				( fpga_spi_cs_n			),
		.spi_clk				( fpga_spi_sck			),
		.spi_mosi				( fpga_spi_mosi			),
		.spi_miso				( fpga_spi_miso			),
		.spi_intr				( fpga_spi_intr			)
	);

	// ---------------------------------------------------------
	//	Config ROM Controller (I/O E0h-FFh)
	// ---------------------------------------------------------
	ip_qspi_rom u_ip_qspi_rom (
		.reset					( ff_reset_spi			),
		.clk					( clk108m				),
		.clk_serial				( clk108m				),
		.bus_cs					( bus_io_cs[7]			),
		.bus_address			( bus_io_address[0]		),
		.bus_write				( bus_io_write			),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( bus_qspi_ready		),
		.bus_wdata				( bus_io_wdata[7:0]		),
		.bus_rdata				( bus_qspi_rdata		),
		.bus_rdata_en			( bus_qspi_rdata_en		),
		.srom0_cs_n				( srom0_cs_n			),
		.srom1_cs_n				( srom1_cs_n			),
		.srom_clk				( srom_clk				),
		.srom_sio				( srom_sio				)
	);

	// ---------------------------------------------------------
	//	表示コントローラ (I/O 00h-1Fh)
	// ---------------------------------------------------------
	display_controller u_display_controller (
		.clk					( clk108m				),
		.reset					( ff_reset_display		),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_io_cs[0]			),
		.bus_address			( bus_io_address		),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( display_bus_ready		),
		.bus_write				( bus_io_write			),
		.bus_wdata				( bus_io_wdata			),
		.bus_rdata				( display_bus_rdata		),
		.bus_rdata_valid		( display_bus_rdata_valid	),
		.lcd_ck					( lcd_ck				),
		.lcd_hs					( lcd_hs				),
		.lcd_vs					( lcd_vs				),
		.lcd_de					( lcd_de				),
		.lcd_r					( lcd_r					),
		.lcd_g					( lcd_g					),
		.lcd_b					( lcd_b					),
		.lcd_bl					( lcd_bl				),
		.sdram_address			( disp_sdram_address		),
		.sdram_address_valid	( disp_sdram_address_valid	),
		.sdram_address_ready	( disp_sdram_address_ready	),
		.sdram_rdata			( disp_sdram_rdata		),
		.sdram_rdata_valid		( disp_sdram_rdata_valid	)
	);

	// ---------------------------------------------------------
	//	描画コントローラ1 (I/O 20h-3Fh)
	// ---------------------------------------------------------
	graphic_processor1 u_graphic_processor1 (
		.clk					( clk108m				),
		.reset					( ff_reset_gp1			),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_io_cs[1]			),
		.bus_address			( bus_io_address		),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( gp1_bus_ready			),
		.bus_write				( bus_io_write			),
		.bus_wdata				( bus_io_wdata			),
		.bus_rdata				( gp1_bus_rdata			),
		.bus_rdata_valid		( gp1_bus_rdata_valid	),
		.sdram_address			( bus0_address			),
		.sdram_write			( bus0_write			),
		.sdram_wdata			( bus0_wdata			),
		.sdram_valid			( bus0_valid			),
		.sdram_flush			( bus0_flush			),
		.sdram_ready			( bus0_ready			),
		.sdram_rdata			( bus0_rdata			),
		.sdram_rdata_valid		( bus0_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	描画コントローラ2 (I/O 40h-5Fh)
	// ---------------------------------------------------------
	graphic_processor2 u_graphic_processor2 (
		.clk					( clk108m				),
		.reset					( ff_reset_gp2			),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_io_cs[2]			),
		.bus_address			( bus_io_address		),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( gp2_bus_ready			),
		.bus_write				( bus_io_write			),
		.bus_wdata				( bus_io_wdata			),
		.bus_rdata				( gp2_bus_rdata			),
		.bus_rdata_valid		( gp2_bus_rdata_valid	),
		.sdram_address			( bus1_address			),
		.sdram_write			( bus1_write			),
		.sdram_wdata			( bus1_wdata			),
		.sdram_valid			( bus1_valid			),
		.sdram_flush			( bus1_flush			),
		.sdram_ready			( bus1_ready			),
		.sdram_rdata			( bus1_rdata			),
		.sdram_rdata_valid		( bus1_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	VRAM読み書き (I/O C0h-DFh)
	// ---------------------------------------------------------
	vram_accessor u_vram_accessor (
		.clk					( clk108m				),
		.reset					( ff_reset_vram			),
		.sdram_init_busy		( sdram_init_busy		),
		.bus_cs					( bus_io_cs[6]			),
		.bus_address			( bus_io_address		),
		.bus_valid				( bus_io_valid			),
		.bus_ready				( vram_bus_ready		),
		.bus_write				( bus_io_write			),
		.bus_wdata				( bus_io_wdata			),
		.bus_rdata				( vram_bus_rdata		),
		.bus_rdata_valid		( vram_bus_rdata_valid	),
		.sdram_address			( bus3_address			),
		.sdram_write			( bus3_write			),
		.sdram_wdata			( bus3_wdata			),
		.sdram_valid			( bus3_valid			),
		.sdram_flush			( bus3_flash			),
		.sdram_ready			( bus3_ready			),
		.sdram_rdata			( bus3_rdata			),
		.sdram_rdata_valid		( bus3_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	バスアービタ
	// ---------------------------------------------------------
	bus_arbiter u_bus_arbiter (
		.reset					( ff_reset_bus			),
		.clk					( clk108m				),
		.bus0_address			( bus0_address			),
		.bus0_write				( bus0_write			),
		.bus0_wdata				( bus0_wdata			),
		.bus0_flash				( bus0_flash			),
		.bus0_valid				( bus0_valid			),
		.bus0_ready				( bus0_ready			),
		.bus0_rdata				( bus0_rdata			),
		.bus0_rdata_valid		( bus0_rdata_valid		),
		.bus1_address			( bus1_address			),
		.bus1_write				( bus1_write			),
		.bus1_wdata				( bus1_wdata			),
		.bus1_flash				( bus1_flash			),
		.bus1_valid				( bus1_valid			),
		.bus1_ready				( bus1_ready			),
		.bus1_rdata				( bus1_rdata			),
		.bus1_rdata_valid		( bus1_rdata_valid		),
		.bus2_address			( bus2_address			),
		.bus2_write				( bus2_write			),
		.bus2_wdata				( bus2_wdata			),
		.bus2_flash				( bus2_flash			),
		.bus2_valid				( bus2_valid			),
		.bus2_ready				( bus2_ready			),
		.bus2_rdata				( bus2_rdata			),
		.bus2_rdata_valid		( bus2_rdata_valid		),
		.bus3_address			( bus3_address			),
		.bus3_write				( bus3_write			),
		.bus3_wdata				( bus3_wdata			),
		.bus3_flash				( bus3_flash			),
		.bus3_valid				( bus3_valid			),
		.bus3_ready				( bus3_ready			),
		.bus3_rdata				( bus3_rdata			),
		.bus3_rdata_valid		( bus3_rdata_valid		),
		.bus_address			( bus_address			),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_flash				( bus_flash				),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	キャッシュメモリ
	// ---------------------------------------------------------
	cache u_cache (
		.reset					( ff_reset_cache		),
		.clk					( clk108m				),
		.bus_address			( bus_address			),
		.bus_write				( bus_write				),
		.bus_wdata				( bus_wdata				),
		.bus_flash				( bus_flash				),
		.bus_valid				( bus_valid				),
		.bus_ready				( bus_ready				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_valid		( bus_rdata_valid		),
		.sdram_address			( sdram_address			),
		.sdram_write			( sdram_write			),
		.sdram_refresh			( sdram_refresh			),
		.sdram_valid			( sdram_address_valid	),
		.sdram_ready			( sdram_address_ready	),
		.sdram_wdata			( sdram_wdata			),
		.sdram_wdata_mask		( sdram_wdata_mask		),
		.sdram_wdata_valid		( sdram_wdata_valid		),
		.sdram_rdata			( sdram_rdata			),
		.sdram_rdata_valid		( sdram_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	SDRAMコントローラ
	// ---------------------------------------------------------
	ip_sdram u_sdram_controller (
		.clk					( clk108m				),
		.clk_sdram				( clk108m_n				),
		.reset					( ff_reset_sdram		),
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

	assign bus_io_ready =
		(bus_io_cs[0] ? display_bus_ready : 1'b0) |
		(bus_io_cs[1] ? gp1_bus_ready : 1'b0) |
		(bus_io_cs[2] ? gp2_bus_ready : 1'b0) |
		(bus_io_cs[6] ? vram_bus_ready : 1'b0) |
		(bus_io_cs[7] ? bus_qspi_ready : 1'b0);

	assign bus_io_rdata =
		(bus_io_cs[0] ? display_bus_rdata : 16'd0) |
		(bus_io_cs[1] ? gp1_bus_rdata : 16'd0) |
		(bus_io_cs[2] ? gp2_bus_rdata : 16'd0) |
		(bus_io_cs[6] ? vram_bus_rdata : 16'd0) |
		(bus_io_cs[7] ? { 8'd0, bus_qspi_rdata } : 16'd0);

	assign bus_io_rdata_en =
		(bus_io_cs[0] ? display_bus_rdata_valid : 1'b0) |
		(bus_io_cs[1] ? gp1_bus_rdata_valid : 1'b0) |
		(bus_io_cs[2] ? gp2_bus_rdata_valid : 1'b0) |
		(bus_io_cs[6] ? vram_bus_rdata_valid : 1'b0) |
		(bus_io_cs[7] ? bus_qspi_rdata_en : 1'b0);

	assign i2s_bclk	= 1'b1;
	assign i2s_dout	= 1'b1;
	assign i2s_en	= 1'b0;
	assign i2s_lrck	= 1'b1;
	assign led		= 8'h00;
	assign ws2812	= 1'b0;
endmodule
