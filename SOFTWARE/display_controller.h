// -----------------------------------------------------------------------------
//	display_controller.h
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

#ifndef __DISPLAY_CONTROLLER_H__
#define __DISPLAY_CONTROLLER_H__

#include "fpga_io.h"

#define DISPLAY_RGB( r, g, b ) (((b) & 0x1F) | (((g) & 0x1F) << 5) | (((r) & 0x1F) << 11))

// -----------------------------------------------------------------------------
//	display_enable
//	input:
//		enable: true=表示有効, false=表示無効
//	output:
//		none
//	description:
//		表示の有効/無効を切り替える
// -----------------------------------------------------------------------------
void display_enable( bool enable );

// -----------------------------------------------------------------------------
//	display_set_fill_color
//	input:
//		color: 16bit RGB color value
//	output:
//		none
//	description:
//		bitmap非表示の場合に表示される色を指定する
// -----------------------------------------------------------------------------
void display_set_fill_color( uint16_t color );

#endif
