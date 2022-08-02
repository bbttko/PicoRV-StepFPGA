#ifndef __MAIN_H__
#define __MAIN_H__

#include <stdint.h>


// 8-bit leds
#define leds 	(* (volatile uint32_t *) 	0x02000000)

// 7-segment display
#define segment1 (* (volatile uint32_t *) 	0x02002000)	
#define segment2 (* (volatile uint32_t *) 	0x02002004)	
#define segment_disable = 0x00000020

// 2x RGB leds
#define rgb1	(* (volatile uint32_t *) 	0x02003000)
#define rgb2	(* (volatile uint32_t *) 	0x02003004)
#define RGB_RED 	6
#define RGB_GREEN	5
#define RGB_BLUE	3
#define RGB_OFF		7

// UART
#define uart_div	(* (volatile uint32_t *) 	0x02004008)
#define uart_rx		(* (volatile uint32_t *) 	0x02004000)
#define uart_tx		(* (volatile uint32_t *) 	0x02004000)

// button
#define buttons		(* (volatile uint32_t *) 	0x02005000)

// switch
#define sw 			(* (volatile uint32_t *) 	0x02008000)

/* -- not used --
#define spimem (* (volatile uint32_t *) 	0x00100000)
#define spimemcfg (* (volatile uint32_t *) 	0x00111111)
#define ram 	(* (volatile uint32_t *) 0x00004000)
*/


#define _FREQ_ 50000000		// 50 MHz clock
#define _BAUD_ 115200
#define UART_DIV_VALUE (int) (_FREQ_/_BAUD_) - 1	// baud = clk_freq / (divisor + 1)

#endif //__MAIN_H__