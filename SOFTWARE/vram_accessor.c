// -----------------------------------------------------------------------------
//	vram_accessor.c
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

#include "vram_accessor.h"

#define IO_VRAM_ADDRESS_L	0x00
#define IO_VRAM_ADDRESS_H	0x01
#define IO_VRAM_DATA		0x02
#define IO_VRAM_FLUSH		0x03

// -----------------------------------------------------------------------------
//	vram_set_address
//	description:
	//		VRAM アドレスレジスタへ 22bit ワードアドレスを設定する
// -----------------------------------------------------------------------------
void vram_set_address( uint32_t address ) {

	fpga_outport( IO_VRAM | IO_VRAM_ADDRESS_L, (uint16_t)(address & 0xFFFF) );
	fpga_outport( IO_VRAM | IO_VRAM_ADDRESS_H, (uint16_t)((address >> 16) & 0x003F) );
}

// -----------------------------------------------------------------------------
//	vram_burst_write
//	description:
//		設定済みのアドレスに 16bit データを書き込む
// -----------------------------------------------------------------------------
void vram_burst_write( uint16_t data ) {
	
	fpga_outport( IO_VRAM | IO_VRAM_DATA, data );
}

// -----------------------------------------------------------------------------
//	vram_write
//	description:
//		指定アドレスの VRAM へ 16bit データを書き込む
// -----------------------------------------------------------------------------
void vram_write( uint32_t address, uint16_t data ) {

	vram_set_address( address );
	vram_burst_write( data );
}

// -----------------------------------------------------------------------------
//	vram_burst_read
//	description:
//		指定アドレスの VRAM から 16bit データを読み出す
// -----------------------------------------------------------------------------
uint16_t vram_burst_read( void ) {

	return fpga_inport( IO_VRAM | IO_VRAM_DATA );
}

// -----------------------------------------------------------------------------
//	vram_read
//	description:
//		指定アドレスの VRAM から 16bit データを読み出す
// -----------------------------------------------------------------------------
uint16_t vram_read( uint32_t address ) {

	vram_set_address( address );
	return vram_burst_read();
}

// -----------------------------------------------------------------------------
//	vram_flush
//	description:
//		VRAM へ保留中の書き込みデータをフラッシュする
// -----------------------------------------------------------------------------
void vram_flush( void ) {

	fpga_outport( IO_VRAM | IO_VRAM_FLUSH, 1 );
}