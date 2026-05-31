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
	wire			clk66m;

	// ---------------------------------------------------------
	//	クロック生成
	// ---------------------------------------------------------
    Gowin_rPLL your_instance_name(
        .clkout		( clk132m		),		//	132MHz
        .clkoutd	( clk66m		),		//	66MHz
        .clkin		( clk27m		)		//	27MHz
    );
endmodule
