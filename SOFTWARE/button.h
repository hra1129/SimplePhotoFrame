// -----------------------------------------------------------------------------
//	button.h
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

#ifndef __BUTTON_H__
#define __BUTTON_H__

#include <stdint.h>

#define SW_A					(1u << 0)
#define SW_B					(1u << 1)
#define SW_U					(1u << 2)
#define SW_D					(1u << 3)
#define SW_L					(1u << 4)
#define SW_R					(1u << 5)

#define SW_ON					(1u)
#define SW_OFF					(0u)

void button_init( void );
uint8_t button_get( void );

#endif
