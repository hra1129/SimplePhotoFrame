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
#include <string.h>
#include <ctype.h>
#include "pico/stdlib.h"
#include "sdcard.h"
#include "jpeg_decoder.h"
#include "display_controller.h"
#include "vram_accessor.h"
#include "button.h"
#include "pico/cyw43_arch.h"
#include "ff.h"
#include "lcd_console.h"

#define PHOTO_MAX_FILES      128
#define PHOTO_PATH_MAX       128
#define PHOTO_FRAME_ADDRESS  0
#define PHOTO_VIEW_WIDTH     800
#define PHOTO_VIEW_HEIGHT    480
#define VRAM_STRIDE_WORDS    1024

typedef struct {
	uint16_t src_width;
	uint16_t src_height;
	uint16_t dst_width;
	uint16_t dst_height;
	uint16_t offset_x;
	uint16_t offset_y;
	uint32_t frame_address;
} jpeg_render_context_t;

static char g_photo_paths[PHOTO_MAX_FILES][PHOTO_PATH_MAX];
static int g_photo_count = 0;
static int g_photo_index = 0;

// ---------------------------------------------------------
static bool has_jpeg_extension( const char *name ) {
	const char *dot;
	char ext[6];
	size_t i;

	if( name == NULL ) {
		return false;
	}

	dot = strrchr( name, '.' );
	if( dot == NULL || dot[1] == '\0' ) {
		return false;
	}

	for( i = 0; i < sizeof(ext) - 1 && dot[1 + i] != '\0'; i++ ) {
		ext[i] = (char)tolower( (unsigned char)dot[1 + i] );
	}
	ext[i] = '\0';

	if( strcmp( ext, "jpg" ) == 0 ) {
		return true;
	}
	if( strcmp( ext, "jpeg" ) == 0 ) {
		return true;
	}
	return false;
}

// ---------------------------------------------------------
static void compute_fit_size( uint16_t src_width, uint16_t src_height, uint16_t *out_width, uint16_t *out_height ) {
	uint16_t dst_width;
	uint16_t dst_height;

	if( src_width <= PHOTO_VIEW_WIDTH && src_height <= PHOTO_VIEW_HEIGHT ) {
		dst_width = src_width;
		dst_height = src_height;
	}
	else if( (uint32_t)src_width * PHOTO_VIEW_HEIGHT > (uint32_t)src_height * PHOTO_VIEW_WIDTH ) {
		dst_width = PHOTO_VIEW_WIDTH;
		dst_height = (uint16_t)(((uint32_t)src_height * PHOTO_VIEW_WIDTH) / src_width);
	}
	else {
		dst_height = PHOTO_VIEW_HEIGHT;
		dst_width = (uint16_t)(((uint32_t)src_width * PHOTO_VIEW_HEIGHT) / src_height);
	}

	if( dst_width == 0 ) {
		dst_width = 1;
	}
	if( dst_height == 0 ) {
		dst_height = 1;
	}

	if( out_width != NULL ) {
		*out_width = dst_width;
	}
	if( out_height != NULL ) {
		*out_height = dst_height;
	}
}

// ---------------------------------------------------------
static bool jpeg_render_callback(
	uint16_t left,
	uint16_t top,
	uint16_t right,
	uint16_t bottom,
	const uint16_t *rgb565_pixels,
	void *user_data ) {
	jpeg_render_context_t *ctx;
	uint16_t rect_width;
	uint16_t src_y;
	int32_t prev_dst_y;

	ctx = (jpeg_render_context_t *)user_data;
	if( ctx == NULL || rgb565_pixels == NULL ) {
		return false;
	}

	rect_width = (uint16_t)(right - left + 1);
	prev_dst_y = -1;
	for( src_y = top; src_y <= bottom; src_y++ ) {
		uint16_t src_x;
		uint16_t dst_y;
		uint32_t dst_line_base;
		int32_t prev_dst_x;
		const uint16_t *src_line;

		dst_y = (uint16_t)(((uint32_t)src_y * ctx->dst_height) / ctx->src_height);
		if( dst_y >= ctx->dst_height ) {
			dst_y = (uint16_t)(ctx->dst_height - 1);
		}
		if( (int32_t)dst_y == prev_dst_y ) {
			continue;
		}
		prev_dst_y = (int32_t)dst_y;

		dst_line_base = ctx->frame_address
			+ (uint32_t)(ctx->offset_y + dst_y) * VRAM_STRIDE_WORDS
			+ ctx->offset_x;
		prev_dst_x = -1;
		src_line = rgb565_pixels + (uint32_t)(src_y - top) * rect_width;

		for( src_x = left; src_x <= right; src_x++ ) {
			uint16_t dst_x;
			uint16_t pixel;

			dst_x = (uint16_t)(((uint32_t)src_x * ctx->dst_width) / ctx->src_width);
			if( dst_x >= ctx->dst_width ) {
				dst_x = (uint16_t)(ctx->dst_width - 1);
			}
			if( (int32_t)dst_x == prev_dst_x ) {
				continue;
			}
			prev_dst_x = (int32_t)dst_x;

			pixel = src_line[src_x - left];
			vram_write( dst_line_base + dst_x, pixel );
		}
	}

	return true;
}

// ---------------------------------------------------------
static void clear_photo_frame( uint32_t frame_address ) {
	graphic1_set_frame_address( frame_address );
	graphic1_fill_rectangle( 0, 0, VRAM_STRIDE_WORDS, PHOTO_VIEW_HEIGHT, DISPLAY_RGB( 0, 0, 0 ), C_ROP_PUT );
	display_wait_complete();
}

// ---------------------------------------------------------
static bool load_photo_file_list( void ) {
	FRESULT fr;
	DIR dir;
	FILINFO fno;
	int i;

	g_photo_count = 0;

	fr = f_opendir( &dir, "/photo" );
	if( fr != FR_OK ) {
		lcd_printf( "f_opendir(/photo) failed: %d\n", fr );
		return false;
	}

	while( 1 ) {
		fr = f_readdir( &dir, &fno );
		if( fr != FR_OK ) {
			lcd_printf( "f_readdir(/photo) failed: %d\n", fr );
			break;
		}
		if( fno.fname[0] == '\0' ) {
			break;
		}
		if( (fno.fattrib & AM_DIR) == 0 && has_jpeg_extension( fno.fname ) ) {
			if( g_photo_count < PHOTO_MAX_FILES ) {
				snprintf( g_photo_paths[g_photo_count], PHOTO_PATH_MAX, "/photo/%s", fno.fname );
				g_photo_count++;
			}
		}
	}

	(void)f_closedir( &dir );

	for( i = 0; i < g_photo_count; i++ ) {
		int j;
		for( j = i + 1; j < g_photo_count; j++ ) {
			if( strcmp( g_photo_paths[i], g_photo_paths[j] ) > 0 ) {
				char temp[PHOTO_PATH_MAX];
				strcpy( temp, g_photo_paths[i] );
				strcpy( g_photo_paths[i], g_photo_paths[j] );
				strcpy( g_photo_paths[j], temp );
			}
		}
	}

	if( g_photo_count <= 0 ) {
		lcd_printf( "No JPEG file found in /photo.\n" );
		return false;
	}

	if( g_photo_index >= g_photo_count ) {
		g_photo_index = 0;
	}

	lcd_printf( "Photo list loaded: %d files\n", g_photo_count );
	return true;
}

// ---------------------------------------------------------
static bool display_jpeg_on_vram( const char *path ) {
	jpeg_render_context_t ctx;
	uint16_t src_width;
	uint16_t src_height;

	if( !jpeg_probe_file( path, &src_width, &src_height ) ) {
		return false;
	}

	compute_fit_size( src_width, src_height, &ctx.dst_width, &ctx.dst_height );
	ctx.src_width = src_width;
	ctx.src_height = src_height;
	ctx.offset_x = (uint16_t)((PHOTO_VIEW_WIDTH - ctx.dst_width) / 2);
	ctx.offset_y = (uint16_t)((PHOTO_VIEW_HEIGHT - ctx.dst_height) / 2);
	ctx.frame_address = PHOTO_FRAME_ADDRESS;

	lcd_printf( "Display JPEG: %s\n", path );
	lcd_printf( "  source=%ux%u, fitted=%ux%u, offset=(%u,%u)\n",
		src_width,
		src_height,
		ctx.dst_width,
		ctx.dst_height,
		ctx.offset_x,
		ctx.offset_y );

	clear_photo_frame( ctx.frame_address );
	if( !jpeg_decode_file( path, 0, jpeg_render_callback, &ctx, NULL, NULL ) ) {
		return false;
	}

	vram_flush();
	display_set_frame_address( ctx.frame_address );
	return true;
}

// ---------------------------------------------------------
static bool show_next_photo( void ) {
	int attempt;

	if( g_photo_count <= 0 ) {
		if( !load_photo_file_list() ) {
			return false;
		}
	}

	for( attempt = 0; attempt < g_photo_count; attempt++ ) {
		int index;
		const char *path;

		index = g_photo_index;
		path = g_photo_paths[index];
		g_photo_index = (g_photo_index + 1) % g_photo_count;

		if( display_jpeg_on_vram( path ) ) {
			lcd_printf( "Displayed [%d/%d]: %s\n", index + 1, g_photo_count, path );
			return true;
		}

		lcd_printf( "Skip unreadable JPEG: %s\n", path );
	}

	lcd_printf( "No decodable JPEG in /photo.\n" );
	return false;
}

// ---------------------------------------------------------
void vram_test( void ) {
	int address;
	uint16_t data;

	//	テストパターンを描画
	lcd_printf( "VRAM test: writing test pattern...\n" );
	display_set_frame_address( 0 );
	vram_set_address( 0 );
	for( address = 0; address < (1024 * 480); address++ ) {
		vram_burst_write( address & 0xFFFF );
	}
	//	テストパターンを再度読み出してチェック
	lcd_printf( "VRAM test: verifying test pattern...\n" );
	vram_set_address( 0 );
	for( address = 0; address < (1024 * 480); address++ ) {
		data = vram_burst_read();
		if( data != (address & 0xFFFF) ) {
			lcd_printf( "VRAM test2 failed at address %d: expected %04X, got %04X\n", address, address & 0xFFFF, data );
		}
	}
	lcd_printf( "VRAM test completed.\n" );
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
		lcd_printf( "Boxfill test: filling box at (%d, %d)-step(%d, %d) with color %04X\n", x, y, w, h, color );
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
	sleep_ms(5000);
	lcd_console_init();

	//	表示を初期化
	graphic1_set_frame_address( 0 );
	graphic1_fill_rectangle( 0, 0, 800, 480, DISPLAY_RGB( 0, 0, 0 ), C_ROP_PUT );
	display_wait_complete();

	display_enable( true );
	lcd_printf( "Simple Photo Frame\n" );
	lcd_printf( "Press Button A to mount SD card and list photos.\n" );
	lcd_printf( "0123456789\n" );
	lcd_printf( "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n" );
	lcd_printf( "abcdefghijklmnopqrstuvwxyz\n" );

	while (1) {
		button_state = button_get();
		if( button_state & SW_A ) {
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			lcd_printf( "Button A pressed.\n" );
			if( sdcard_init_and_mount() ) {
				lcd_printf("SD card mount succeeded.\n");
				sdcard_print_root_directory();
			}
			else {
				lcd_printf("SD card mount failed.\n");
			}
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_B ) {
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			lcd_printf( "Button B pressed.\n" );
			if( sdcard_init_and_mount() ) {
				lcd_printf( "SD card mount succeeded and showing next photo.\n" );
				(void)show_next_photo();
			}
			else {
				lcd_printf( "SD card mount failed.\n" );
			}
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_U ) {
			lcd_printf( "Button Up pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			vram_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_D ) {
			lcd_printf( "Button Down pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);




			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_L ) {
			lcd_printf( "Button Left pressed.\n" );
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
			boxfill_test();
			cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
		}
		else if( button_state & SW_R ) {
			lcd_printf( "Button Right pressed.\n" );
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
