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

int main() {
	int r, g, b;

	stdio_init_all();
	fpga_io_init();
	sleep_ms(2000);

	while (1) {
//		if( sdcard_init_and_mount() ) {
//			break;
//		}
//		printf("SD card mount failed.\n");
		display_enable( false );
		r = rand() & 31;
		g = rand() & 63;
		b = rand() & 31;
		printf( "Fill color: R=%d, G=%d, B=%d\n", r, g, b );
		display_set_fill_color( DISPLAY_RGB( r, g, b ) );
		sleep_ms(1000);
		printf( "VRAM Image\n" );
		display_enable( true );
		r = rand() & 31;
		g = rand() & 63;
		b = rand() & 31;
		graphic1_fill_rectangle( rand() % 800, rand() % 480, rand() % 100, rand() % 100, DISPLAY_RGB( r, g, b ), C_ROP_PUT );
		sleep_ms(1000);
	}

	while( 1 ) {
		sdcard_print_root_directory();
		sleep_ms(1000);
	}
	return 0;
}
