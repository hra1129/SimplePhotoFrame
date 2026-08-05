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

	vram_set_address( 1024 * 480 );
	i = 0;
	for( y = 0; y < 480; y++ ) {
		vram_set_address( 1024 * 480 + y * 1024 );
		for( x = 0; x < 800; x++ ) {
			vram_burst_write( usa_image[i] );
			i++;
		}
	}
	vram_flush();
	display_set_frame_address( 1024 * 480 );
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

	while (1) {
//		if( sdcard_init_and_mount() ) {
//			break;
//		}
//		printf("SD card mount failed.\n");

		button_state = button_get();
		if( button_state & SW_A ) {
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			printf( "Button A pressed.\n" );
			display_enable( false );
			r = rand() & 31;
			g = rand() & 63;
			b = rand() & 31;
			display_set_fill_color( DISPLAY_RGB( r, g, b ) );
			printf( "Fill color: R=%d, G=%d, B=%d\n", r, g, b );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_B ) {
			printf( "Button B pressed.\n" );
			display_enable( true );
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

		do {
			button_state = button_get();
		} while( button_state != 0 );
	}

	while( 1 ) {
		sdcard_print_root_directory();
		sleep_ms(1000);
	}
	return 0;
}
