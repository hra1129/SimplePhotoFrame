// -----------------------------------------------------------------------------
//	button.c
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

#include "button.h"
#include "pico/stdlib.h"

#define PIN_SW_A				16
#define PIN_SW_B				17
#define PIN_SW_U				18
#define PIN_SW_D				19
#define PIN_SW_L				20
#define PIN_SW_R				21

// ---------------------------------------------------------
void button_init( void ) {
	gpio_init( PIN_SW_A );
	gpio_set_dir( PIN_SW_A, GPIO_IN );
	gpio_pull_up( PIN_SW_A );

	gpio_init( PIN_SW_B );
	gpio_set_dir( PIN_SW_B, GPIO_IN );
	gpio_pull_up( PIN_SW_B );

	gpio_init( PIN_SW_U );
	gpio_set_dir( PIN_SW_U, GPIO_IN );
	gpio_pull_up( PIN_SW_U );

	gpio_init( PIN_SW_D );
	gpio_set_dir( PIN_SW_D, GPIO_IN );
	gpio_pull_up( PIN_SW_D );

	gpio_init( PIN_SW_L );
	gpio_set_dir( PIN_SW_L, GPIO_IN );
	gpio_pull_up( PIN_SW_L );

	gpio_init( PIN_SW_R );
	gpio_set_dir( PIN_SW_R, GPIO_IN );
	gpio_pull_up( PIN_SW_R );
}

// ---------------------------------------------------------
uint8_t button_get( void ) {
	uint8_t result;

	result = 0;
	if( !gpio_get( PIN_SW_A ) ) result |= SW_A;
	if( !gpio_get( PIN_SW_B ) ) result |= SW_B;
	if( !gpio_get( PIN_SW_U ) ) result |= SW_U;
	if( !gpio_get( PIN_SW_D ) ) result |= SW_D;
	if( !gpio_get( PIN_SW_L ) ) result |= SW_L;
	if( !gpio_get( PIN_SW_R ) ) result |= SW_R;

	return result;
}
