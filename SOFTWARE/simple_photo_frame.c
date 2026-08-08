// -----------------------------------------------------------------------------
//	Simple Photo Frame
//	
//	Copyright (c) 2026 Takayuki Hara
//	
//	Permission is hereby granted, free of charge, to any person obtaining a copy of 
//	this software and associated documentation files (the "Software"), to deal in the 
//	Software without restriction, including without limitation the rights to use, 
//	copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the 
//	Software, and to permit persons to whom the Software is furnished to do so, 
//	subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in all 
//	copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//	INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
//	PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
//	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
//	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// -----------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "sdcard.h"
#include "display_controller.h"
#include "vram_accessor.h"
#include "button.h"
#include "usa_fpga.h"
#include "pico/cyw43_arch.h"

// ---------------------------------------------------------
void vram_test( void ) {
	int address;
	uint16_t data;

	//	テストパターンを描画
	printf( "VRAM test: writing test pattern...\n" );
	display_set_frame_address( 0 );
	vram_set_address( 0 );
	for( address = 0; address < (1024 * 480); address++ ) {
		vram_burst_write( address & 0xFFFF );
	}
	//	テストパターンを再度読み出してチェック
	printf( "VRAM test: verifying test pattern...\n" );
	vram_set_address( 0 );
	for( address = 0; address < (1024 * 480); address++ ) {
		data = vram_burst_read();
		if( data != (address & 0xFFFF) ) {
			printf( "VRAM test2 failed at address %d: expected %04X, got %04X\n", address, address & 0xFFFF, data );
		}
	}
	printf( "VRAM test completed.\n" );
}

// ---------------------------------------------------------
void usa_fpga_test( void ) {
	int x, y, i;

	i = 0;
	for( y = 0; y < 480; y++ ) {
		vram_set_address( 1024 * 480 * 2 + y * 1024 );
		for( x = 0; x < 800; x++ ) {
			vram_burst_write( usa_image[i] );
			i++;
		}
	}
	vram_flush();
	display_set_frame_address( 1024 * 480 * 2 );
}

// ---------------------------------------------------------
void boxfill_test( void ) {
	int i, x, y, w, h;
	uint16_t color;

	display_set_frame_address( 0 );
	vram_set_address( 0 );
	graphic1_set_frame_address( 0 );
	for( i = 0; i < 10000; i++ ) {
		color = rand() & 0xFFFF;
		x = rand() % 1024;
		y = rand() % 480;
		w = rand() % 200 + 1;
		h = rand() % 200 + 1;
		printf( "Boxfill test: filling box at (%d, %d)-step(%d, %d) with color %04X\n", x, y, w, h, color );
		graphic1_fill_rectangle( x, y, w, h, color, C_ROP_PUT );

	}
	vram_flush();
}

// ---------------------------------------------------------
void resizer_test( void ) {
	uint32_t src_address, dst_address;
	int x, y, i, j;

	display_set_frame_address( 0 );
	graphic1_set_frame_address( 0 );
	graphic1_fill_rectangle( 0, 0, 1024, 480, DISPLAY_RGB( 0, 12, 0 ), C_ROP_PUT );
	graphic1_set_frame_address( 1024 * 480 * 1 );
	graphic1_fill_rectangle( 0, 0, 1024, 480, DISPLAY_RGB( 0, 12, 0 ), C_ROP_PUT );

	src_address = 1024 * 480 * 2;
	dst_address = 1024 * 480 * 1;
	graphic2_set_source_frame_address( src_address );
	for( i = 0; i <= 800; i+=16 ) {
		graphic2_set_destination_frame_address( dst_address );
		graphic2_block_copy( 0, 0, 800, 480, 0, 0, i, i * 480 / 800, C_ROP_PUT );
		display_wait_complete();
		display_set_frame_address( dst_address );
		display_wait_frame_sync();
		dst_address = 1024 * 480 * 1 - dst_address;
	}
}

// ---------------------------------------------------------
int main() {
	int r, g, b, x, y;
	uint8_t button_state;

	stdio_init_all();
	button_init();
	fpga_io_init();
	cyw43_arch_init();
	sleep_ms(3000);

	//	テストパターンを描画
	vram_set_address( 0 );
	for( y = 0; y < 480; y++ ) {
		for( x = 0; x < 1024; x++ ) {
			r = ((x + y) & 63) >> 1;
			g = ((x + y) & 63);
			b = ((x + y) & 63) >> 1;
			vram_burst_write( DISPLAY_RGB( r, g, b ) );
		}
	}
	vram_flush();

	display_enable( true );
	while (1) {

		button_state = button_get();
		if( button_state & SW_A ) {
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			printf( "Button A pressed.\n" );
			if( sdcard_init_and_mount() ) {
				printf("SD card mount succeeded.\n");
				sdcard_print_root_directory();
			}
			else {
				printf("SD card mount failed.\n");
			}
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_B ) {
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			printf( "Button B pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_U ) {
			printf( "Button Up pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			vram_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_D ) {
			printf( "Button Down pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			usa_fpga_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_L ) {
			printf( "Button Left pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			boxfill_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_R ) {
			printf( "Button Right pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			resizer_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}

		do {
			button_state = button_get();
		} while( button_state != 0 );
	}
	return 0;
}
