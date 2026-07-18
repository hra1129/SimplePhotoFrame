// -----------------------------------------------------------------------------
//	fpga_io.c
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------

#include "fpga_io.h"
#include "pico/stdlib.h"
#include "hardware/spi.h"

// SPI0 (FPGAモジュール)
#define SPI0_PORT	  spi0
#define SPI0_RX_PIN	  4
#define SPI0_CSN_PIN  5
#define SPI0_SCK_PIN  6
#define SPI0_TX_PIN	  7
#define SPI0_INTR_PIN 3
#define SPI0_BAUDRATE (70 * 1000 * 1000)	// 70 MHz

// ---------------------------------------------------------
void fpga_access_begin( void ) {
	gpio_put( SPI0_CSN_PIN, 0 );
}

// ---------------------------------------------------------
void fpga_access_end( void ) {
	gpio_put( SPI0_CSN_PIN, 1 );
}

// ---------------------------------------------------------
void fpga_io_init( void ) {
	spi_init( SPI0_PORT, SPI0_BAUDRATE );
	spi_set_format( SPI0_PORT, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST );
	gpio_set_function( SPI0_RX_PIN,	GPIO_FUNC_SPI );
	gpio_set_function( SPI0_SCK_PIN, GPIO_FUNC_SPI );
	gpio_set_function( SPI0_TX_PIN,	GPIO_FUNC_SPI );
	// CSn はソフトウェア制御
	gpio_init( SPI0_CSN_PIN );
	gpio_set_dir( SPI0_CSN_PIN, GPIO_OUT );
	gpio_put( SPI0_CSN_PIN, 1 );
	// INTR は入力
	gpio_init( SPI0_INTR_PIN );
	gpio_set_dir( SPI0_INTR_PIN, GPIO_IN );
}

// ---------------------------------------------------------
void fpga_outport( uint8_t io_address, uint16_t data ) {
	uint8_t buf;

	gpio_put( SPI0_CSN_PIN, 0 );
	buf = 0x01;
	spi_write_blocking( SPI0_PORT, &buf, 1 );
	buf = io_address;
	spi_write_blocking( SPI0_PORT, &buf, 1 );
	buf = data & 0xFF;
	spi_write_blocking( SPI0_PORT, &buf, 1 );
	buf = (data >> 8) & 0xFF;
	spi_write_blocking( SPI0_PORT, &buf, 1 );
	gpio_put( SPI0_CSN_PIN, 1 );
}

// ---------------------------------------------------------
uint16_t fpga_inport( uint8_t io_address ) {
	uint8_t cmd;
	uint8_t dummy;
	uint16_t data;
	absolute_time_t timeout_time;
	bool intr_ready;

	gpio_put( SPI0_CSN_PIN, 0 );

	cmd = 0x02;
	spi_write_blocking( SPI0_PORT, &cmd, 1 );
	cmd = io_address;
	spi_write_blocking( SPI0_PORT, &cmd, 1 );

	// INTR ピンが 1 になるまで待つ（50ms タイムアウト）
	timeout_time = make_timeout_time_ms( 50 );
	intr_ready = false;

	while( !time_reached( timeout_time ) ) {
		if( gpio_get( SPI0_INTR_PIN ) ) {
			intr_ready = true;
			break;
		}
	}

	// タイムアウトした場合は CSn = 1, 0xAA を返す
	if( !intr_ready ) {
		gpio_put( SPI0_CSN_PIN, 1 );
		return 0xAA;
	}

	dummy = 0x00;
	spi_write_read_blocking( SPI0_PORT, &dummy, (uint8_t *)&data + 0, 1 );
	spi_write_read_blocking( SPI0_PORT, &dummy, (uint8_t *)&data + 1, 1 );

	gpio_put( SPI0_CSN_PIN, 1 );
	return data;
}
