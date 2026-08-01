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
	wire			clk216m;
	reg				ff_reset_bus = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_spi = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_gp1 = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_gp2 = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_display = 1'b1;	/* synthesis syn_preserve = 1 */
	reg				ff_reset_vram = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_sdram = 1'b1;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_cache = 1'b1;		/* synthesis syn_preserve = 1 */
	wire	[7:0]	w_bus_io_cs;
	wire	[4:0]	w_bus_io_address;
	wire			w_bus_io_valid;
	wire			w_bus_io_ready;
	wire			w_bus_io_write;
	wire	[15:0]	w_bus_io_wdata;
	wire	[15:0]	w_bus_io_rdata;
	wire			w_bus_io_rdata_en;
	wire			w_bus_qspi_ready;
	wire	[7:0]	w_bus_qspi_rdata;
	wire			w_bus_qspi_rdata_en;
	wire			w_display_bus_ready;
	wire	[15:0]	w_display_bus_rdata;
	wire			w_display_bus_rdata_valid;
	wire			w_gp1_bus_ready;
	wire	[15:0]	w_gp1_bus_rdata;
	wire			w_gp1_bus_rdata_valid;
	wire			w_gp2_bus_ready;
	wire	[15:0]	w_gp2_bus_rdata;
	wire			w_gp2_bus_rdata_valid;
	wire			w_vram_bus_ready;
	wire	[15:0]	w_vram_bus_rdata;
	wire			w_vram_bus_rdata_valid;
	wire	[22:1]	w_sdram0_address;
	wire			w_sdram0_write;
	wire	[15:0]	w_sdram0_wdata;
	wire			w_sdram0_flush;
	wire			w_sdram0_valid;
	wire			w_sdram0_ready;
	wire	[15:0]	w_sdram0_rdata;
	wire			w_sdram0_rdata_valid;
	wire	[22:1]	w_sdram1_address;
	wire			w_sdram1_write;
	wire	[15:0]	w_sdram1_wdata;
	wire			w_sdram1_flush;
	wire			w_sdram1_valid;
	wire			w_sdram1_ready;
	wire	[15:0]	w_sdram1_rdata;
	wire			w_sdram1_rdata_valid;
	wire	[22:1]	w_sdram2_address;
	wire			w_sdram2_write;
	wire	[15:0]	w_sdram2_wdata;
	wire			w_sdram2_flush;
	wire			w_sdram2_valid;
	wire			w_sdram2_ready;
	wire	[15:0]	w_sdram2_rdata;
	wire			w_sdram2_rdata_valid;
	wire	[22:1]	w_sdram3_address;
	wire			w_sdram3_write;
	wire	[15:0]	w_sdram3_wdata;
	wire			w_sdram3_flush;
	wire			w_sdram3_valid;
	wire			w_sdram3_ready;
	wire	[15:0]	w_sdram3_rdata;
	wire			w_sdram3_rdata_valid;
	wire			w_sdram_init_busy;
	wire	[22:1]	w_cache_address;
	wire			w_cache_write;
	wire	[15:0]	w_cache_wdata;
	wire			w_cache_flush;
	wire			w_cache_valid;
	wire			w_cache_ready;
	wire	[15:0]	w_cache_rdata;
	wire			w_cache_rdata_valid;

	wire	[22:5]	w_sdram_display_address;
	wire			w_sdram_display_address_valid;
	wire			w_sdram_display_address_ready;
	wire	[31:0]	w_sdram_display_rdata;
	wire			w_sdram_display_rdata_valid;
	wire	[31:0]	w_sdram_display_wdata;
	wire			w_sdram_display_write;
	wire			w_sdram_display_refresh;
	wire			w_sdram_display_wdata_valid;
	wire	[3:0]	w_sdram_display_wdata_mask;

	wire	[22:5]	w_sdram_cache_address;
	wire			w_sdram_cache_address_valid;
	wire			w_sdram_cache_address_ready;
	wire	[31:0]	w_sdram_cache_rdata;
	wire			w_sdram_cache_rdata_valid;
	wire	[31:0]	w_sdram_cache_wdata;
	wire			w_sdram_cache_write;
	wire			w_sdram_cache_refresh;
	wire			w_sdram_cache_wdata_valid;
	wire	[3:0]	w_sdram_cache_wdata_mask;
	wire			w_sdram_write;
	wire			w_sdram_refresh;
	wire	[22:5]	w_sdram_address;
	wire			w_sdram_address_valid;
	wire			w_sdram_address_ready;
	wire			w_sdram_wdata_valid;
	wire	[3:0]	w_sdram_wdata_mask;
	wire	[31:0]	w_sdram_wdata;
	wire	[31:0]	w_sdram_rdata;
	wire			w_sdram_rdata_valid;
	wire			w_srom0_cs_n;
	wire			w_srom1_cs_n;
	wire			w_srom_clk;
	wire	[3:0]	w_srom_sio;

	// ---------------------------------------------------------
	//	クロック生成
	// ---------------------------------------------------------
	Gowin_rPLL u_rpll (
		.clkout							( clk108m						),		//	108MHz
		.clkoutp						( clk108m_n						),		//	108MHz (inverted)
		.clkin							( clk27m						)		//	27MHz
	);

	Gowin_rPLL2 your_instance_name(
		.clkout							( clk216m						),		//	216MHz
		.clkin							( clk27m						)		//	27MHz
	);

	// ---------------------------------------------------------
	//	リセット生成
	// ---------------------------------------------------------
	always @( posedge clk108m ) begin
		ff_reset_bus		<= 1'b0;
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
		.reset							( ff_reset_spi					),
		.clk							( clk108m						),
		.clk_serial						( clk216m						),
		.bus_cs							( w_bus_io_cs					),
		.bus_write						( w_bus_io_write				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_bus_io_ready				),
		.bus_wdata						( w_bus_io_wdata				),
		.bus_address					( w_bus_io_address				),
		.bus_rdata						( w_bus_io_rdata				),
		.bus_rdata_en					( w_bus_io_rdata_en				),
		.spi_cs_n						( fpga_spi_cs_n					),
		.spi_clk						( fpga_spi_sck					),
		.spi_mosi						( fpga_spi_mosi					),
		.spi_miso						( fpga_spi_miso					),
		.spi_intr						( fpga_spi_intr					)
	);

	// ---------------------------------------------------------
	//	Config ROM Controller (I/O E0h-FFh)
	// ---------------------------------------------------------
	ip_spi_rom u_ip_spi_rom (
		.reset							( ff_reset_spi					),
		.clk							( clk108m						),
		.clk_serial						( clk108m						),
		.bus_cs							( w_bus_io_cs[7]				),
		.bus_address					( w_bus_io_address[0]			),
		.bus_write						( w_bus_io_write				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_bus_qspi_ready				),
		.bus_wdata						( w_bus_io_wdata[7:0]			),
		.bus_rdata						( w_bus_qspi_rdata				),
		.bus_rdata_en					( w_bus_qspi_rdata_en			),
		.srom0_cs_n						( w_srom0_cs_n					),
		.srom1_cs_n						( w_srom1_cs_n					),
		.srom_clk						( w_srom_clk					),
		.srom_hold_n					( w_srom_sio[3]					),
		.srom_wp_n						( w_srom_sio[2]					),
		.srom_do						( w_srom_sio[1]					),
		.srom_di						( w_srom_sio[0]					)
	);

	// ---------------------------------------------------------
	//	表示コントローラ (I/O 00h-1Fh)
	// ---------------------------------------------------------
	display_controller u_display_controller (
		.clk							( clk108m						),
		.reset							( ff_reset_display				),
		.sdram_init_busy				( w_sdram_init_busy				),
		.bus_cs							( w_bus_io_cs[0]				),
		.bus_address					( w_bus_io_address				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_display_bus_ready			),
		.bus_write						( w_bus_io_write				),
		.bus_wdata						( w_bus_io_wdata				),
		.bus_rdata						( w_display_bus_rdata			),
		.bus_rdata_valid				( w_display_bus_rdata_valid		),
		.lcd_ck							( lcd_ck						),
		.lcd_hs							( lcd_hs						),
		.lcd_vs							( lcd_vs						),
		.lcd_de							( lcd_de						),
		.lcd_r							( lcd_r							),
		.lcd_g							( lcd_g							),
		.lcd_b							( lcd_b							),
		.lcd_bl							( lcd_bl						),
		.sdram_address					( w_sdram_display_address		),
		.sdram_address_valid			( w_sdram_display_address_valid	),
		.sdram_address_ready			( w_sdram_display_address_ready	),
		.sdram_rdata					( w_sdram_display_rdata			),
		.sdram_rdata_valid				( w_sdram_display_rdata_valid	)
	);
	assign w_sdram_display_flush = 1'b0;
	assign w_sdram_display_write = 1'b0;
	assign w_sdram_display_wdata = 16'd0;

	// ---------------------------------------------------------
	//	VRAM読み書き (I/O C0h-DFh)
	// ---------------------------------------------------------
	vram_accessor u_vram_accessor (
		.clk							( clk108m						),
		.reset							( ff_reset_vram					),
		.sdram_init_busy				( w_sdram_init_busy				),
		.bus_cs							( w_bus_io_cs[6]				),
		.bus_address					( w_bus_io_address				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_vram_bus_ready				),
		.bus_write						( w_bus_io_write				),
		.bus_wdata						( w_bus_io_wdata				),
		.bus_rdata						( w_vram_bus_rdata				),
		.bus_rdata_valid				( w_vram_bus_rdata_valid		),
		.sdram_address					( w_sdram0_address				),
		.sdram_write					( w_sdram0_write				),
		.sdram_wdata					( w_sdram0_wdata				),
		.sdram_valid					( w_sdram0_valid				),
		.sdram_flush					( w_sdram0_flush				),
		.sdram_ready					( w_sdram0_ready				),
		.sdram_rdata					( w_sdram0_rdata				),
		.sdram_rdata_valid				( w_sdram0_rdata_valid			)
	);

	// ---------------------------------------------------------
	//	描画コントローラ1 (I/O 20h-3Fh)
	// ---------------------------------------------------------
	graphic_processor1 u_graphic_processor1 (
		.clk							( clk108m						),
		.reset							( ff_reset_gp1					),
		.sdram_init_busy				( w_sdram_init_busy				),
		.bus_cs							( w_bus_io_cs[1]				),
		.bus_address					( w_bus_io_address				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_gp1_bus_ready				),
		.bus_write						( w_bus_io_write				),
		.bus_wdata						( w_bus_io_wdata				),
		.bus_rdata						( w_gp1_bus_rdata				),
		.bus_rdata_valid				( w_gp1_bus_rdata_valid			),
		.sdram_address					( w_sdram1_address				),
		.sdram_write					( w_sdram1_write				),
		.sdram_wdata					( w_sdram1_wdata				),
		.sdram_valid					( w_sdram1_valid				),
		.sdram_flush					( w_sdram1_flush				),
		.sdram_ready					( w_sdram1_ready				),
		.sdram_rdata					( w_sdram1_rdata				),
		.sdram_rdata_valid				( w_sdram1_rdata_valid			)
	);

	// ---------------------------------------------------------
	//	描画コントローラ2 (I/O 40h-5Fh)
	// ---------------------------------------------------------
	graphic_processor2 u_graphic_processor2 (
		.clk							( clk108m						),
		.reset							( ff_reset_gp2					),
		.sdram_init_busy				( w_sdram_init_busy				),
		.bus_cs							( w_bus_io_cs[2]				),
		.bus_address					( w_bus_io_address				),
		.bus_valid						( w_bus_io_valid				),
		.bus_ready						( w_gp2_bus_ready				),
		.bus_write						( w_bus_io_write				),
		.bus_wdata						( w_bus_io_wdata				),
		.bus_rdata						( w_gp2_bus_rdata				),
		.bus_rdata_valid				( w_gp2_bus_rdata_valid			),
		.sdram_address					( w_sdram2_address				),
		.sdram_write					( w_sdram2_write				),
		.sdram_wdata					( w_sdram2_wdata				),
		.sdram_valid					( w_sdram2_valid				),
		.sdram_flush					( w_sdram2_flush				),
		.sdram_ready					( w_sdram2_ready				),
		.sdram_rdata					( w_sdram2_rdata				),
		.sdram_rdata_valid				( w_sdram2_rdata_valid			)
	);

	// ---------------------------------------------------------
	//	バスアービター1
	// ---------------------------------------------------------
	bus_arbiter u_bus_arbiter (
		.reset							( ff_reset_bus					),
		.clk							( clk108m						),
		.sdram0_address					( w_sdram0_address				),
		.sdram0_write					( w_sdram0_write				),
		.sdram0_wdata					( w_sdram0_wdata				),
		.sdram0_flush					( w_sdram0_flush				),
		.sdram0_valid					( w_sdram0_valid				),
		.sdram0_ready					( w_sdram0_ready				),
		.sdram0_rdata					( w_sdram0_rdata				),
		.sdram0_rdata_valid				( w_sdram0_rdata_valid			),
		.sdram1_address					( w_sdram1_address				),
		.sdram1_write					( w_sdram1_write				),
		.sdram1_wdata					( w_sdram1_wdata				),
		.sdram1_flush					( w_sdram1_flush				),
		.sdram1_valid					( w_sdram1_valid				),
		.sdram1_ready					( w_sdram1_ready				),
		.sdram1_rdata					( w_sdram1_rdata				),
		.sdram1_rdata_valid				( w_sdram1_rdata_valid			),
		.sdram2_address					( w_sdram2_address				),
		.sdram2_write					( w_sdram2_write				),
		.sdram2_wdata					( w_sdram2_wdata				),
		.sdram2_flush					( w_sdram2_flush				),
		.sdram2_valid					( w_sdram2_valid				),
		.sdram2_ready					( w_sdram2_ready				),
		.sdram2_rdata					( w_sdram2_rdata				),
		.sdram2_rdata_valid				( w_sdram2_rdata_valid			),
		.sdram3_address					( w_sdram3_address				),
		.sdram3_write					( w_sdram3_write				),
		.sdram3_wdata					( w_sdram3_wdata				),
		.sdram3_flush					( w_sdram3_flush				),
		.sdram3_valid					( w_sdram3_valid				),
		.sdram3_ready					( w_sdram3_ready				),
		.sdram3_rdata					( w_sdram3_rdata				),
		.sdram3_rdata_valid				( w_sdram3_rdata_valid			),
		.sdram_address					( w_cache_address				),
		.sdram_write					( w_cache_write					),
		.sdram_wdata					( w_cache_wdata					),
		.sdram_flush					( w_cache_flush					),
		.sdram_valid					( w_cache_valid					),
		.sdram_ready					( w_cache_ready					),
		.sdram_rdata					( w_cache_rdata					),
		.sdram_rdata_valid				( w_cache_rdata_valid			)
	);

	assign w_sdram3_address		= 22'd0;
	assign w_sdram3_write		= 1'b0;
	assign w_sdram3_wdata		= 16'd0;
	assign w_sdram3_flush		= 1'b0;
	assign w_sdram3_valid		= 1'b0;

	// ---------------------------------------------------------
	//	キャッシュメモリ
	// ---------------------------------------------------------
	cache u_cache (
		.reset							( ff_reset_cache				),
		.clk							( clk108m						),
		.cache_address					( w_cache_address				),
		.cache_write					( w_cache_write					),
		.cache_wdata					( w_cache_wdata					),
		.cache_flush					( w_cache_flush					),
		.cache_valid					( w_cache_valid					),
		.cache_ready					( w_cache_ready					),
		.cache_rdata					( w_cache_rdata					),
		.cache_rdata_valid				( w_cache_rdata_valid			),
		.sdram_address					( w_sdram_cache_address			),
		.sdram_write					( w_sdram_cache_write			),
		.sdram_refresh					( w_sdram_cache_refresh			),
		.sdram_valid					( w_sdram_cache_address_valid	),
		.sdram_ready					( w_sdram_cache_address_ready	),
		.sdram_wdata					( w_sdram_cache_wdata			),
		.sdram_wdata_mask				( w_sdram_cache_wdata_mask		),
		.sdram_wdata_valid				( w_sdram_cache_wdata_valid		),
		.sdram_rdata					( w_sdram_cache_rdata			),
		.sdram_rdata_valid				( w_sdram_cache_rdata_valid		)
	);

	// ---------------------------------------------------------
	//	バスアービター2
	// ---------------------------------------------------------
	bus_selector u_bus_selector (
		.reset							( ff_reset_bus					),
		.clk							( clk108m						),
		.sdram_display_address			( w_sdram_display_address		),
		.sdram_display_address_valid	( w_sdram_display_address_valid	),
		.sdram_display_address_ready	( w_sdram_display_address_ready	),
		.sdram_display_rdata			( w_sdram_display_rdata			),
		.sdram_display_rdata_valid		( w_sdram_display_rdata_valid	),
		.sdram_cache_address			( w_sdram_cache_address			),
		.sdram_cache_write				( w_sdram_cache_write			),
		.sdram_cache_refresh			( w_sdram_cache_refresh			),
		.sdram_cache_address_valid		( w_sdram_cache_address_valid	),
		.sdram_cache_address_ready		( w_sdram_cache_address_ready	),
		.sdram_cache_wdata				( w_sdram_cache_wdata			),
		.sdram_cache_wdata_mask			( w_sdram_cache_wdata_mask		),
		.sdram_cache_wdata_valid		( w_sdram_cache_wdata_valid		),
		.sdram_cache_rdata				( w_sdram_cache_rdata			),
		.sdram_cache_rdata_valid		( w_sdram_cache_rdata_valid		),
		.sdram_address					( w_sdram_address				),
		.sdram_write					( w_sdram_write					),
		.sdram_refresh					( w_sdram_refresh				),
		.sdram_address_valid			( w_sdram_address_valid			),
		.sdram_address_ready			( w_sdram_address_ready			),
		.sdram_wdata					( w_sdram_wdata					),
		.sdram_wdata_mask				( w_sdram_wdata_mask			),
		.sdram_wdata_valid				( w_sdram_wdata_valid			),
		.sdram_rdata					( w_sdram_rdata					),
		.sdram_rdata_valid				( w_sdram_rdata_valid			)
	);

	// ---------------------------------------------------------
	//	SDRAMコントローラ
	// ---------------------------------------------------------
	ip_sdram u_sdram_controller (
		.clk							( clk108m						),
		.clk_sdram						( clk108m_n						),
		.reset							( ff_reset_sdram				),
		.sdram_init_busy				( w_sdram_init_busy				),
		.bus_address					( w_sdram_address				),
		.bus_write						( w_sdram_write					),
		.bus_refresh					( w_sdram_refresh				),
		.bus_valid						( w_sdram_address_valid			),
		.bus_ready						( w_sdram_address_ready			),
		.bus_wdata						( w_sdram_wdata					),
		.bus_wdata_mask					( w_sdram_wdata_mask			),
		.bus_wdata_valid				( w_sdram_wdata_valid			),
		.bus_rdata						( w_sdram_rdata					),
		.bus_rdata_valid				( w_sdram_rdata_valid			),
		.O_sdram_clk					( O_sdram_clk					),
		.O_sdram_cke					( O_sdram_cke					),
		.O_sdram_cs_n					( O_sdram_cs_n					),		// chip select
		.O_sdram_ras_n					( O_sdram_ras_n					),		// row address select
		.O_sdram_cas_n					( O_sdram_cas_n					),		// columns address select
		.O_sdram_wen_n					( O_sdram_wen_n					),		// write enable
		.IO_sdram_dq					( IO_sdram_dq					),		// 32 bit bidirectional data bus
		.O_sdram_addr					( O_sdram_addr					),		// 11 bit multiplexed address bus
		.O_sdram_ba						( O_sdram_ba					),		// two banks
		.O_sdram_dqm					( O_sdram_dqm					)		// data mask
	);

	assign w_bus_io_ready =
		(w_bus_io_cs[0] ? w_display_bus_ready : 1'b0) |
		(w_bus_io_cs[1] ? w_gp1_bus_ready : 1'b0) |
		(w_bus_io_cs[2] ? w_gp2_bus_ready : 1'b0) |
		(w_bus_io_cs[6] ? w_vram_bus_ready : 1'b0) |
		(w_bus_io_cs[7] ? w_bus_qspi_ready : 1'b0);

	assign w_bus_io_rdata =
		(w_bus_io_cs[0] ? w_display_bus_rdata : 16'd0) |
		(w_bus_io_cs[1] ? w_gp1_bus_rdata : 16'd0) |
		(w_bus_io_cs[2] ? w_gp2_bus_rdata : 16'd0) |
		(w_bus_io_cs[6] ? w_vram_bus_rdata : 16'd0) |
		(w_bus_io_cs[7] ? { 8'd0, w_bus_qspi_rdata } : 16'd0);

	assign w_bus_io_rdata_en =
		(w_bus_io_cs[0] ? w_display_bus_rdata_valid : 1'b0) |
		(w_bus_io_cs[1] ? w_gp1_bus_rdata_valid : 1'b0) |
		(w_bus_io_cs[2] ? w_gp2_bus_rdata_valid : 1'b0) |
		(w_bus_io_cs[6] ? w_vram_bus_rdata_valid : 1'b0) |
		(w_bus_io_cs[7] ? w_bus_qspi_rdata_en : 1'b0);

	assign i2s_bclk	= 1'b1;
	assign i2s_dout	= 1'b1;
	assign i2s_en	= 1'b0;
	assign i2s_lrck	= 1'b1;
	assign led		= 8'h00;
	assign ws2812	= 1'b0;
endmodule
