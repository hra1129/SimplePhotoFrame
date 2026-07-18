// -----------------------------------------------------------------------------
//	fpga_io.h
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

#ifndef __FPGA_IO_H__
#define __FPGA_IO_H__

#include "pico/stdlib.h"

#define IO_UART						0x10

#define IO_EXTIO_MANUFACTURER_ID	0x40
#define IO_EXTIO_DEVICE_ID			0x41
#define IO_EXTIO_ROM_COMMAND_PORT	0x42
#define IO_EXTIO_ROM_DATA_PORT		0x43

#define IO_DISPLAY					(0 << 5)
#define IO_GRAPHIC1					(1 << 5)
#define IO_GRAPHIC2					(2 << 5)
#define IO_VRAM						(6 << 5)
#define IO_CONFIG					(7 << 5)

void fpga_io_init( void );
void fpga_outport( uint8_t io_address, uint16_t data );
uint16_t fpga_inport( uint8_t io_address );

#endif
