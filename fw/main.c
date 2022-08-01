/*

// to do
3.  custom interrupt .. uart rx??
*/
#include "main.h"
#include "irq.h"
#include "print.h"

extern void delay_1s();

char greet[] = "\n\r__RiscV StepFPGA__\n\rMax10 10M08SAM153C8G\n\r";

uint32_t val = 0;
uint8_t timer_enabled = 0;

void timer_handler(void) {
	leds = val++;
	if (val == 0x0100) val = 0;
	set_timer(_FREQ_);
}

void irq_20_handler(void) {
	switch(buttons) {
		case 1:
			print_str("0");
			break;
		case 2:
			print_str("1");
			break;
		case 4:
			print_str("2");
			break;
		default:
			break;
	}
	buttons = 0;
}

void menu() {
	print_str(greet);
	print_str(" [a or 'space'] - printing this message\n\r");
	print_str(" [t] - timer interrupt to count leds (toggle)\n\r");
	print_str(" [r,g,b,o] - Red, Green, Blue, turn Off leds\n\r");
	print_str(" others - echo command & ascii to 7-segment display\n\r");
	print_str(" buttons: irq prints button# for K1,K2,K3. Button K4 = reset\n\r");
}

/*
 * main ===============================================================================
 */
int main() {
	uint8_t rx_temp;
	
	// uart setup
	uart_div = UART_DIV_VALUE;
	irq_unmask_one_bit(IRQ20_BUTTONS);	// enable IRQ20 (buttons)
	menu();		// usage menu
	
	while (1) {
		if ((rx_temp = uart_rx) != 0xff) {

			switch (rx_temp) {
				case 't':
					if (timer_enabled) {
						print_str("disabling timer irq\n\r");
						irq_mask_one_bit(IRQ0_TIMER);
					} else {
						print_str("enabling timer irq\n\r");
						irq_unmask_one_bit(IRQ0_TIMER);
						set_timer(_FREQ_);
					}
					timer_enabled = !timer_enabled;
					break;
					
				case 'a':
				case ' ':
					menu();
					break;
					
				case 'r':
					rgb1 = RGB_RED;
					rgb2 = RGB_RED;
					break;
					
				case 'g':
					rgb1 = RGB_GREEN;
					rgb2 = RGB_GREEN;
					break;
					
				case 'b':
					rgb1 = RGB_BLUE;
					rgb2 = RGB_BLUE;
					break;

				case 'o':
					rgb1 = RGB_OFF;
					rgb2 = RGB_OFF;
					break;
					
				default:
					uart_tx = rx_temp;	// echo
					segment1 = rx_temp & 0x0F;
					segment2 = (rx_temp >> 4) & 0x0f; 
					break;
			}
		}

	}
	return 0;
}
//  main end ===============================================================================




