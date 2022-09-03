/*
 * Button [2:0] = button IRQ
 * Button 3 = async reset
 * TXD/RXD N,8,1 115200 connected to external CP2102
 * enabled interrupt for Buttons
 * Switches: direct connect
 *
 * -- btko Jul-22
 */

`default_nettype none
module top (
		input 		 clock,	// 12MHz
		input  [3:0] BUTTONn,
		output [7:0] LEDSn,
		output [2:0] RGB1n, RGB2n,
		output [8:0] SEG1n, SEG2n,
		input  [3:0] SW,
		output 		 TXD,
		input 		 RXD
	);

	
	// ~~~~~~~~~~  memory map ~~~~~~~~~~~~~~~~	sync with sections.lds, update sp in start.s
	localparam ROM_ADDR		=	32'h0000_0000;
	localparam ROM_ADDR_END	=	32'h0000_0FFF;
	localparam RAM_ADDR		=	32'h0000_1000;
	localparam RAM_ADDR_END	=	32'h0000_13ff;

	localparam LEDS_ADDR		=	32'h0200_0000;
	localparam SEG1_ADDR		=	32'h0200_2000;
	localparam SEG2_ADDR		=	32'h0200_2004;
	localparam RGB1_ADDR		=	32'h0200_3000;
	localparam RGB2_ADDR		=	32'h0200_3004;
	localparam UART_DAT_ADDR = 32'h0200_4000;		// for both R & W
	localparam UART_DIV_ADDR = 32'h0200_4008;
	localparam BUTTON_ADDR	=	32'h0200_5000;
	localparam SWITCH_ADDR	=	32'h0200_8000;
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	
	localparam RESET_ADDR	=	ROM_ADDR;
	localparam IRQ_ADDR		=	32'h0000_0008;		// irq table.. in start.s
	localparam STACK_ADDR	=	RAM_ADDR_END+1;

	// ========================= PLL =========================
	(* keep *) wire clock_main;
	(* keep *) wire locked;
	myPLL pll (
		.areset	(!BUTTONn[3]),		// Button3 = reset (closest to decimal point / pin 17)
		.inclk0	(clock),				// 12 MHz
		.c0		(clock_main),		// 50 MHz
		.locked	(locked)
	);
	

	// ========================= CPU =========================
	(* keep *) wire mem_valid, mem_ready, mem_instr;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0]  mem_wstrb;
	wire [31:0] mem_rdata;
	reg rom_ready;
	wire trapsig;
	reg [31:0] irq;
	wire [31:0] eoi;
	
	picorv32 #(
		.ENABLE_COUNTERS	(1),
		.BARREL_SHIFTER	(1),
		.ENABLE_IRQ			(1),
		.ENABLE_IRQ_TIMER	(1),
		.PROGADDR_RESET	(RESET_ADDR),
		.PROGADDR_IRQ		(IRQ_ADDR),
		.STACKADDR			(STACK_ADDR)
	) cpu (
		.clk		(clock_main),
		.resetn	(locked),
		.trap		(trapsig),
		.irq		(irq),		// input [31:0] irq
		.eoi		(eoi),		// output [31:0] eoi

		.mem_valid	(mem_valid),	//		output reg        mem_valid,	-- MEMORY ADDRESS VALID
		.mem_instr	(mem_instr),
		.mem_ready	(mem_ready),	//		input             mem_ready,
		.mem_addr	(mem_addr),		//		output reg [31:0] mem_addr,
		.mem_wdata	(mem_wdata),	//		output reg [31:0] mem_wdata,
		.mem_wstrb	(mem_wstrb),	//		output reg [ 3:0] mem_wstrb,
		.mem_rdata	(mem_rdata)		//		input      [31:0] mem_rdata
	);


	// ========================= ROM =========================
	// start addr 	: [0000_0000]
	// end_addr		: [0000_0FFF]
	wire [31:0] romout;
	myROM rom (
		.address	(mem_addr[11:2]),	// 1024 words x 32 bits
		.clock	(clock_main),
		.q			(romout)
	);
//	altsyncram #(
//		.operation_mode	("SINGLE_PORT"),
//		.width_a				(32),
//		.widthad_a			($clog2(1024)),
//		.init_file			("./fw/main.mif")
//	) rom (
//		.clock0		(clock_main),
//		.address_a	(mem_addr[11:2]),
//		.q_a			(romout)
//	);
	
	
	always @(posedge clock_main) 
		rom_ready <= mem_valid && !mem_ready && (mem_addr >= ROM_ADDR) && (mem_addr <= ROM_ADDR_END);

		
	// ========================= RAM =========================
	// start addr 	: [0000_1000]
	// end_addr		: [0000_13FF]
	reg ram_ready;
	reg ram_wren;
	wire [31:0] ram_out;

	myRAM ram (					// to debug with in-system memory content editor
		.address	(mem_addr[9:2]),
		.byteena (mem_wstrb),
		.clock	(clock_main),
		.data		(mem_wdata),
		.wren		(ram_wren),
		.q			(ram_out)
	);
	
	always @(posedge clock_main) begin
		ram_ready <= mem_valid && !mem_ready && (mem_addr >= RAM_ADDR) && (mem_addr <= RAM_ADDR_END);
		ram_wren <= (mem_valid && !mem_ready &&  (mem_addr >= RAM_ADDR) && (mem_addr <= RAM_ADDR_END) && |mem_wstrb);
	end

	
	// ========================= LEDS (8-bits) =========================
	// addr 	: [0200_0000]
	reg leds_ready;
	reg [31:0] ledreg;
	always @(posedge clock_main) 
		leds_ready <= mem_valid && !mem_ready && mem_addr == LEDS_ADDR;

	always @(posedge clock_main) begin
		if (!locked) 
			ledreg <= 32'h0000_0000;	// turn off
		else if (mem_valid && mem_addr == LEDS_ADDR) begin
			// ledreg <= leds_ready & mem_wstrb[0] ? mem_wdata[7:0] : 8'hff;
			if (mem_wstrb[0]) ledreg[7:0] <= mem_wdata[7:0];
			if (mem_wstrb[1]) ledreg[15:8] <= mem_wdata[15:8];
			if (mem_wstrb[2]) ledreg[23:16] <= mem_wdata[23:16];
			if (mem_wstrb[3]) ledreg[31:24] <= mem_wdata[31:24];
		end
	end
	assign LEDSn = ~ledreg[7:0];	// reverse logic


	// ========================= 7-segment x2 =========================
	// addr1 	: [2000_2000]
	// addr2 	: [2000_2004]
	reg seg1_ready, seg2_ready;
	reg [4:0] seg1reg, seg2reg;
	reg seg1_disable, seg2_disable;
	
	always @(posedge clock_main) begin
		seg1_ready <= mem_valid && !mem_ready && mem_addr == SEG1_ADDR;
		seg2_ready <= mem_valid && !mem_ready && mem_addr == SEG2_ADDR;
	end

	always @(posedge clock_main) begin
		if (!locked) begin
			seg1reg <= 5'b00000;
			seg2reg <= 5'b00000;
			seg1_disable <= 1;
			seg2_disable <= 1;
		end else begin
			if (mem_valid && !mem_ready && mem_wstrb == 4'hf && mem_addr == SEG1_ADDR) begin
				seg1reg <= mem_wdata[4:0];
				seg1_disable <= mem_wdata[5];
			end
			if (mem_valid && !mem_ready && mem_wstrb == 4'hf && mem_addr == SEG2_ADDR) begin
				seg2reg <= mem_wdata[4:0];
				seg2_disable <= mem_wdata[5];
			end
		end	
	end

	sevenSeg seg (
		.disable1 	(seg1_disable),
		.disable2 	(seg2_disable),
		.seg_data_1	(seg1reg),
		.seg_data_2	(seg2reg),
		.segment_led_1 (SEG1n),
		.segment_led_2	(SEG2n)
	);

	// ========================= RGB led x2  =========================
	// addr1 	: [0200_3000]
	// addr2		: [0200_3004]
	reg rgb1_ready, rgb2_ready;
	reg [2:0] rgb1reg, rgb2reg;
	always @(posedge clock_main) begin
		rgb1_ready = mem_valid && !mem_ready && mem_addr == RGB1_ADDR;
		rgb2_ready = mem_valid && !mem_ready && mem_addr == RGB2_ADDR;
	end
	
	always @(posedge clock_main) begin
		if (!locked) begin
			rgb1reg <= 3'b111;
			rgb2reg <= 3'b111;
		end else begin
			if (mem_valid && !mem_ready && mem_addr == RGB1_ADDR && mem_wstrb[0] == 1)  rgb1reg <= mem_wdata[2:0];
			if (mem_valid && !mem_ready && mem_addr == RGB2_ADDR && mem_wstrb[0] == 1)  rgb2reg <= mem_wdata[2:0];
		end
	end
	assign RGB1n = rgb1reg;
	assign RGB2n = rgb2reg;


	// ========================= UART =========================
	// DATA addr 	: [0200_4000]
	// DIV addr		: [0200_4008]

	// divisor register
	wire uart_div_ready = mem_valid && mem_addr == UART_DIV_ADDR;
	wire [31:0] uart_div_reg_do;
	
	// data write register
	wire uart_dat_wait;
	wire uart_data_ready = mem_valid && (mem_addr == UART_DAT_ADDR);
	
	// data read register
	wire [31:0] uart_dat_do;
	

	simpleuart uart (
		.clk				( clock_main	),
		.resetn			( locked	),
		.ser_tx			( TXD		),
		.ser_rx			( RXD		),

		// r/w UART divisor register
		.reg_div_we		( uart_div_ready ? mem_wstrb : 4'h0),
		.reg_div_di		( mem_wdata	),
		.reg_div_do		( uart_div_reg_do	),

		// r/w UART data register
		.reg_dat_we		( uart_data_ready ? mem_wstrb[0] : 1'b0),
		.reg_dat_di		( mem_wdata			),
		.reg_dat_wait	( uart_dat_wait	),
		
		.reg_dat_re		( uart_data_ready && !mem_wstrb ),
		.reg_dat_do		( uart_dat_do		)
	);
	
	
`ifdef old
	// divisor register
	reg uart_div_ready;
	wire [31:0] uart_div_reg_do;
	
	// data write register
	wire uart_dat_wait;
	wire uart_wdata_ready;
	
	// data read register
	wire [31:0] uart_dat_do;
	reg uart_rdata_ready;
	reg [31:0] uart_rx_reg;
	
	always @(posedge clock_main) begin
		uart_div_ready <= mem_valid && !mem_ready && mem_addr == UART_DIV_ADDR;
		uart_rdata_ready <= mem_valid && !mem_ready && mem_addr == UART_RDAT_ADDR;
		uart_rx_reg <= uart_dat_do;	// latch received char
	end
	assign uart_wdata_ready = mem_valid && (mem_addr == UART_WDAT_ADDR);


	simpleuart uart (
		.clk				( clock_main	),
		.resetn			( locked	),
		.ser_tx			( TXD		),
		.ser_rx			( RXD		),

		// r/w UART divisor register
		.reg_div_we		( (mem_valid && mem_addr == UART_DIV_ADDR) ? mem_wstrb : 4'h0),
		.reg_div_di		( mem_wdata	),
		.reg_div_do		( uart_div_reg_do	),

		// r/w UART data register
		.reg_dat_we		( uart_wdata_ready ? mem_wstrb[0] : 1'b0),
		.reg_dat_di		( mem_wdata			),
		.reg_dat_wait	( uart_dat_wait	),
		
		.reg_dat_re		( mem_valid && mem_addr == UART_RDAT_ADDR ),
		.reg_dat_do		( uart_dat_do		)
	);
`endif


	
	// ========================= Button (IRQ) x3, other button is 'reset' ==========
	// addr1 	: [0200_5000]
	(* keep *) wire [2:0] dBUTTONn;

	xBitDebounce #(.NUMBITS (3)) db3 (
		.clock	(clock_main),
		.i_db		(BUTTONn[2:0]),
		.o_db		(dBUTTONn)
	);

//	reg [31:0] button_reg;
	reg [2:0] button_reg;
	reg button_ready;
	always @(posedge clock_main)
		button_ready = mem_valid && !mem_ready && (mem_addr == BUTTON_ADDR);

	wire NandButton = ~&dBUTTONn;
	//	always @(posedge clock_main) irq[20] <= NandButton;		// during interrupt

	always @(posedge clock_main) begin
		if (!locked) begin
			button_reg <= 0;
		end else begin
			irq[20] <= NandButton;		// irq when not in reset
			if (NandButton)
//				button_reg <= {{29{1'b0}}, ~dBUTTONn};
				button_reg <= ~dBUTTONn;
			else if (button_ready) begin
				if (mem_wstrb[0]) button_reg <= 0;
//				if (mem_wstrb[0]) button_reg[7:0] <= 0;
//				if (mem_wstrb[1]) button_reg[15:8] <= 0;
//				if (mem_wstrb[2]) button_reg[23:16] <= 0;
//				if (mem_wstrb[3]) button_reg[31:24] <= 0;
			end
		end
	end

	
	// ========================= Switch x4 =========================
	// addr1 	: [0200_5000]
	reg sw_ready;
	always @(posedge clock_main) 
		sw_ready = mem_valid && !mem_ready && mem_addr == SWITCH_ADDR;
	
	// ========================= mem_ready & mem_rdata selector =========================

	assign mem_ready = rom_ready || ram_ready || 
							leds_ready || 
							seg1_ready || seg2_ready ||
							rgb1_ready || rgb2_ready ||
							button_ready ||
							sw_ready ||
							uart_div_ready ||
							uart_data_ready && !uart_dat_wait;
							
	assign mem_rdata = 	rom_ready ? romout : 
								ram_ready ? ram_out :
								leds_ready ? ledreg :
								seg1_ready ? {27'h0, seg1reg} :
								seg2_ready ? {27'h0, seg2reg} :
								rgb1_ready ? {29'h0, rgb1reg} :
								rgb2_ready ? {29'h0, rgb2reg} :
//								button_ready ? button_reg :
								button_ready ? {29'h0,button_reg} :
								sw_ready ? {28'h0, SW} :
								uart_div_ready ? uart_div_reg_do :
								uart_data_ready ? uart_dat_do :
								32'h0000_0000;

endmodule
