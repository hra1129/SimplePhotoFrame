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

#define DISPLAY_FRAME_ADDRESS0		(1024 * 480 * 0)
#define DISPLAY_FRAME_ADDRESS1		(1024 * 480 * 1)
#define JPEG_LOAD_FRAME_ADDRESS		(1024 * 480 * 2)
#define BACK_BUFFER_FRAME_ADDRESS	(1024 * 480 * 3)
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
static uint8_t g_display_frame_no = 0;
static uint8_t g_draw_frame_no = 1;
static const uint32_t g_frame_addresses[2] = { DISPLAY_FRAME_ADDRESS0, DISPLAY_FRAME_ADDRESS1 };

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
	int32_t prev_vram_address;

	ctx = (jpeg_render_context_t *)user_data;
	if( ctx == NULL || rgb565_pixels == NULL ) {
		return false;
	}

	rect_width = (uint16_t)(right - left + 1);
	prev_dst_y = -1;
	prev_vram_address = -999;
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

			uint32_t vram_address;

			pixel = src_line[src_x - left];
			vram_address = dst_line_base + dst_x;
			if( (int32_t)vram_address == prev_vram_address + 1 ) {
				vram_burst_write( pixel );
			}
			else {
				vram_write( vram_address, pixel );
			}
			prev_vram_address = (int32_t)vram_address;
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
//	フォトフレームのJPEGファイルリストを読み込む
//	/photoディレクトリ内のJPEGファイルを検索し、
//	g_photo_pathsに格納する
//	戻り値: true=JPEGファイルが見つかった, false=JPEGファイルが見つからなかった
// ---------------------------------------------------------
static bool load_photo_file_list( void ) {
	FRESULT fr;
	DIR dir;
	FILINFO fno;
	int i;

	g_photo_count = 0;

	fr = f_opendir( &dir, "/photo" );
	if( fr != FR_OK ) {
		return false;
	}

	while( 1 ) {
		fr = f_readdir( &dir, &fno );
		if( fr != FR_OK ) {
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
		return false;
	}

	if( g_photo_index >= g_photo_count ) {
		g_photo_index = 0;
	}
	return true;
}

// ---------------------------------------------------------
static bool display_jpeg_on_vram( const char *path, uint32_t frame_address ) {
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
	ctx.frame_address = frame_address;

	clear_photo_frame( ctx.frame_address );
	if( !jpeg_decode_file( path, 0, jpeg_render_callback, &ctx, NULL, NULL ) ) {
		return false;
	}

	vram_flush();
	return true;
}

// ---------------------------------------------------------
static bool show_next_photo( uint32_t frame_address ) {
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

		if( display_jpeg_on_vram( path, frame_address ) ) {
			//	Displayed: path
			return true;
		}
		//	Skip unreadable JPEG: path
	}
	//	No decodable JPEG in /photo.
	return false;
}

// ---------------------------------------------------------
void initialization( void ) {

	stdio_init_all();
	button_init();
	cyw43_arch_init();
	fpga_io_init();
	lcd_console_init();
}

// ---------------------------------------------------------
void opening_animation( void ) {
	int i;
	uint16_t color;

	display_set_frame_address( 0 );
	graphic1_set_frame_address( 0 );
	graphic1_fill_rectangle( 0, 0, 800, 480, DISPLAY_RGB( 0, 0, 0 ), C_ROP_PUT );

	for( i = 63; i >= 0; i-- ) {
		display_set_fill_color( DISPLAY_RGB( i >> 1, i, i >> 1 ) );
		sleep_ms( 50 );
		display_wait_frame_sync();
	}
	display_wait_complete();
	display_enable( true );

	lcd_set_pos( 11, 11 );
	lcd_printf( "Simple Photo Frame\n" );
}

// ---------------------------------------------------------
void check_press_button( uint8_t button_code ) {

	while( (button_get() & button_code) == 0 ) {
		// Wait for the button to be pressed
	}
	while( (button_get() & button_code) != 0 ) {
		// Wait for the button to be released
	}
}

// ---------------------------------------------------------
void try_mount_sdcard( void ) {

	while( !sdcard_init_and_mount() ) {
		lcd_set_pos( 3, 13 );
		lcd_printf( "Insert memory card and push A button.\n" );
		check_press_button( SW_A );
		lcd_set_pos( 3, 13 );
		lcd_printf( "                                     \n" );
		sleep_ms( 100 );
	}
}

// ---------------------------------------------------------
void check_sdcard( void ) {
	bool file_list_loaded = false;

	do {
		try_mount_sdcard();
		file_list_loaded = load_photo_file_list();
		if( !file_list_loaded ) {
			lcd_set_pos( 3, 13 );
			lcd_printf( "    No photo found in /photo.        \n" );
			check_press_button( SW_A );
			lcd_set_pos( 3, 13 );
			lcd_printf( "                                     \n" );
		}
	} while( !file_list_loaded );

	lcd_set_pos( 3, 13 );
	lcd_printf( "        Load 1st image.           \n" );
}

// ---------------------------------------------------------
//	左から右へスクロールして切り替わる
void transition_swipe( void ) {
	int x, y, i;
	const int anime[] = {
		0, 46, 92, 138, 184, 229, 273, 316, 359, 400, 439, 477, 514, 548, 581, 612, 641, 668, 692, 714, 734, 751, 766, 778, 787, 794, 798, 800 
	};
	const int anime_size = sizeof(anime) / sizeof(anime[0]);

	//	現在の表示を BACK_BUFFER_FRAME_ADDRESS にコピーする
	graphic2_set_source_frame_address( g_frame_addresses[g_display_frame_no] );
	graphic2_set_destination_frame_address( BACK_BUFFER_FRAME_ADDRESS );
	graphic2_block_copy( 0, 0, 800, 480, 0, 0, 800, 480, C_ROP_PUT );
	display_wait_complete();
	//	転送元を JPEGデコード結果、転送先を表示フレームに指定する
	graphic2_set_source_frame_address( BACK_BUFFER_FRAME_ADDRESS );
	graphic2_set_destination_frame_address( g_frame_addresses[g_draw_frame_no] );
	graphic2_block_copy( 0, 0, 800, 480, 0, 0, 800, 480, C_ROP_PUT );
	display_wait_complete();
	//	スクロールアニメーション
	for( y = 0; y < 480; y += 96 ) {
		for( i = 0; i < anime_size; i++ ) {
			x = anime[i];
			//	x より左は新しい画像( JPEG_LOAD_FRAME_ADDRESS ), x より右は古い画像（ BACK_BUFFER_FRAME_ADDRESS )を描画する
			graphic2_set_source_frame_address( JPEG_LOAD_FRAME_ADDRESS );
			graphic2_block_copy( 800 - x, y, x, 96, 0, y, x, 96, C_ROP_PUT );
			display_wait_complete();
			graphic2_set_source_frame_address( BACK_BUFFER_FRAME_ADDRESS );
			graphic2_block_copy( 0, y, 800 - x, 96, x, y, 800 - x, 96, C_ROP_PUT );
			display_wait_complete();
			display_set_frame_address( g_frame_addresses[g_draw_frame_no] );
			display_wait_frame_sync();
			g_display_frame_no = g_draw_frame_no;
			g_draw_frame_no = ( g_draw_frame_no + 1 ) & 1;
			graphic2_set_destination_frame_address( g_frame_addresses[g_draw_frame_no] );
		}
	}
}

// ---------------------------------------------------------
//	小さなパネルのように見せかけて切り替わる
void transition_panel( void ) {
	int x, y, i, j, k, l, k_base;
	const int step = 10;
	const int next_step = 13;

	//	転送元を JPEGデコード結果、転送先を表示フレームに指定する
	graphic2_set_source_frame_address( JPEG_LOAD_FRAME_ADDRESS );
	graphic2_set_destination_frame_address( g_frame_addresses[g_display_frame_no] );
	//	パネルアニメーション
	k = 50;
	for( j = 0; j < 100; j+=step ) {
		k_base = k;
		for( i = 4; i <= 80; i+=4 ) {
			k = k_base;
			for( l = 0; l < step; l++ ) {
				x = ( k % 10 ) * 80;
				y = ( k / 10 ) * 48;
				graphic2_block_copy( x, y, 80, 48, x, y, i, 48, C_ROP_PUT );
				display_wait_complete();
				k = ( k + next_step ) % 100; 
			}
			display_wait_frame_sync();
		}
		k_base = ( k_base + next_step * step ) % 100;
	}
}

// ---------------------------------------------------------
void transition_effect( void ) {
	static int animation = 0;

	switch( animation ) {
	case 0:
		transition_swipe();
		break;
	case 1:
		transition_panel();
		break;
	}
	animation = ( animation + 1 ) & 1;
}

// ---------------------------------------------------------
int main() {
	int r, g, b, x, y;
	uint8_t button_state;

	initialization();
	opening_animation();
	check_sdcard();


	while (1) {
		//	時間計測開始
		absolute_time_t measurement_start = get_absolute_time();

		//	次の画像をデコードする
		show_next_photo( JPEG_LOAD_FRAME_ADDRESS );
		//	時間が経過するのを待機する
		while( absolute_time_diff_us( measurement_start, get_absolute_time() ) < 5000000 ) {
			sleep_ms( 1 );
		}

		//	表示フレームを切り替える
		transition_effect();
	}
	return 0;
}
