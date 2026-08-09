// -----------------------------------------------------------------------------
//	lcd_console.c
//	Copyright (C)2026 Takayuki Hara (HRA!)
// -----------------------------------------------------------------------------

#include "lcd_console.h"

#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>

#include "display_controller.h"
#include "font.h"
#include "vram_accessor.h"

#define LCD_WIDTH_PIXELS             800
#define LCD_HEIGHT_PIXELS            480
#define VRAM_STRIDE_WORDS            1024
#define VRAM_HEIGHT_LINES            4096

#define FONT_WIDTH_PIXELS            20
#define FONT_HEIGHT_PIXELS           20
#define FONT_CHAR_FIRST              ' '
#define FONT_CHAR_COUNT              100

#define FONT_ATLAS_WIDTH_PIXELS      1000
#define FONT_CHARS_PER_ROW           (FONT_ATLAS_WIDTH_PIXELS / FONT_WIDTH_PIXELS)
#define FONT_ATLAS_ROWS              ((FONT_CHAR_COUNT + FONT_CHARS_PER_ROW - 1) / FONT_CHARS_PER_ROW)
#define FONT_ATLAS_HEIGHT_PIXELS     (FONT_ATLAS_ROWS * FONT_HEIGHT_PIXELS)

#define FONT_STORE_LINES             40
#define FONT_STORE_BASE_Y            (VRAM_HEIGHT_LINES - FONT_STORE_LINES)
#define FONT_STORE_BASE_ADDRESS      (FONT_STORE_BASE_Y * VRAM_STRIDE_WORDS)

#define CONSOLE_COLS                 (LCD_WIDTH_PIXELS / FONT_WIDTH_PIXELS)
#define CONSOLE_ROWS                 (LCD_HEIGHT_PIXELS / FONT_HEIGHT_PIXELS)
#define TAB_WIDTH                    4

static uint16_t s_cursor_x;
static uint16_t s_cursor_y;

// -----------------------------------------------------------------------------
static void lcd_newline( void ) {
	s_cursor_x = 0;
	if( s_cursor_y + 1 < CONSOLE_ROWS ) {
		s_cursor_y++;
		return;
	}

	graphic2_set_source_frame_address( 0 );
	graphic2_set_destination_frame_address( 0 );
	graphic2_block_copy(
		0,
		FONT_HEIGHT_PIXELS,
		LCD_WIDTH_PIXELS,
		LCD_HEIGHT_PIXELS - FONT_HEIGHT_PIXELS,
		0,
		0,
		LCD_WIDTH_PIXELS,
		LCD_HEIGHT_PIXELS - FONT_HEIGHT_PIXELS,
		C_ROP_PUT );
	display_wait_complete();

	graphic1_set_frame_address( 0 );
	graphic1_fill_rectangle(
		0,
		LCD_HEIGHT_PIXELS - FONT_HEIGHT_PIXELS,
		LCD_WIDTH_PIXELS,
		FONT_HEIGHT_PIXELS,
		0x0000,
		C_ROP_PUT );
	display_wait_complete();

	graphic2_set_source_frame_address( FONT_STORE_BASE_ADDRESS );
	graphic2_set_destination_frame_address( 0 );
}

// -----------------------------------------------------------------------------
static void lcd_putc_internal( char c ) {
	uint16_t code;
	uint16_t glyph_index;
	uint16_t src_col;
	uint16_t src_row;
	uint16_t src_x;
	uint16_t src_y;
	uint16_t dst_x;
	uint16_t dst_y;

	if( c == '\r' ) {
		return;
	}
	if( c == '\n' ) {
		lcd_newline();
		return;
	}
	if( c == '\t' ) {
		do {
			lcd_putc_internal( ' ' );
		} while( (s_cursor_x % TAB_WIDTH) != 0 );
		return;
	}

	if( s_cursor_x >= CONSOLE_COLS ) {
		lcd_newline();
	}

	code = (uint16_t)(uint8_t)c;
	if( code < (uint16_t)FONT_CHAR_FIRST || code >= (uint16_t)(FONT_CHAR_FIRST + FONT_CHAR_COUNT) ) {
		code = '?';
	}

	glyph_index = (uint16_t)(code - FONT_CHAR_FIRST);
	src_col = (uint16_t)(glyph_index % FONT_CHARS_PER_ROW);
	src_row = (uint16_t)(glyph_index / FONT_CHARS_PER_ROW);
	src_x = (uint16_t)(src_col * FONT_WIDTH_PIXELS);
	src_y = (uint16_t)(src_row * FONT_HEIGHT_PIXELS);
	dst_x = (uint16_t)(s_cursor_x * FONT_WIDTH_PIXELS);
	dst_y = (uint16_t)(s_cursor_y * FONT_HEIGHT_PIXELS);

	graphic2_block_copy(
		src_x,
		src_y,
		FONT_WIDTH_PIXELS,
		FONT_HEIGHT_PIXELS,
		dst_x,
		dst_y,
		FONT_WIDTH_PIXELS,
		FONT_HEIGHT_PIXELS,
		C_ROP_PUT );

	s_cursor_x++;
	if( s_cursor_x >= CONSOLE_COLS ) {
		lcd_newline();
	}
}

// -----------------------------------------------------------------------------
void lcd_console_init( void ) {
	uint32_t y, x, i;

	i = 0;
	for( y = 0; y < FONT_STORE_LINES; y++ ) {
		vram_set_address( FONT_STORE_BASE_ADDRESS + y * VRAM_STRIDE_WORDS );
		for( x = 0; x < FONT_ATLAS_WIDTH_PIXELS; x++ ) {
			vram_burst_write( font[i] );
			i++;
		}
	}
	vram_flush();

	s_cursor_x = 0;
	s_cursor_y = 0;
}

// -----------------------------------------------------------------------------
void lcd_set_pos( uint16_t x, uint16_t y ) {
	if( x >= CONSOLE_COLS ) {
		x = (uint16_t)(CONSOLE_COLS - 1);
	}
	if( y >= CONSOLE_ROWS ) {
		y = (uint16_t)(CONSOLE_ROWS - 1);
	}
	s_cursor_x = x;
	s_cursor_y = y;
}

// -----------------------------------------------------------------------------
void lcd_puts( const char *text ) {
	if( text == NULL ) {
		return;
	}

	while( *text != '\0' ) {
		lcd_putc_internal( *text );
		text++;
	}
}

// -----------------------------------------------------------------------------
void lcd_printf( const char *format, ... ) {
	va_list args;
	char text[256];
	int written;

	if( format == NULL ) {
		return;
	}

	va_start( args, format );
	written = vsnprintf( text, sizeof(text), format, args );
	va_end( args );

	if( written <= 0 ) {
		return;
	}

	graphic2_set_source_frame_address( FONT_STORE_BASE_ADDRESS );
	graphic2_set_destination_frame_address( 0 );
	lcd_puts( text );
}
