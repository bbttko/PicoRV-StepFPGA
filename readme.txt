__RiscV PicoRV on StepFPGA MAX10__


PicoRV on StepFPGA
	- interrupts: timer & button
	- basic uart with print functions
	- demo code in /fw dir
	- outputs: 2x 7-seg and 8-bit leds
	- input: 4x switches

todo:
	* switch enable in top.v
	* remove debugs from main.c
	* connection diagram

to use:
	pre-req
		riscv32 cross compiler 
		Quartus Prime (18.1)
	
	1. 'make' files in fw/ dir
	2. Syn, fit & assemble in Quartus Prime
	3. connect Uart 115200 N,8,1 
	4. download to FPGA, follow 'menu' in uart
	5. use 'update_mif_asm.tcl' for fw changes, w/o HDL change


reference/resources
	StepFPGA info -> https://www.stepfpga.com/doc/step-max10

	
btko - Aug 2022