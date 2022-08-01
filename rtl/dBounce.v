module xBitDebounce (
		input wire clock,
		input wire [NUMBITS-1:0] i_db,
		output wire [NUMBITS-1:0] o_db
	);
	parameter NUMBITS = 3;
	
	genvar i;
	generate
		for (i=0; i<NUMBITS; i=i+1) begin : HiThere
			dBounce #(.NUMCYCLES (500_000)) dbgen (
				.i_clk (clock),
				.i_db  (i_db[i]),
				.o_db  (o_db[i])
			);
		end
	endgenerate
endmodule





module dBounce(
		input i_clk, i_db,
		output o_db
	);
	parameter NUMCYCLES = 50_000;		// how many cycles at least >=1, cannot be 0
	
	localparam NUMBITS = $clog2(NUMCYCLES)+1;		// number of bits+1 to count NUMCYCLES 
	localparam MAX_COUNT = {1'b1,{NUMBITS{1'b0}}} + NUMCYCLES;	
	localparam MIN_COUNT = {1'b1,{NUMBITS{1'b0}}} - (NUMCYCLES);
	
	reg [NUMBITS:0] count = {1'b1,{(NUMBITS-1){1'b0}} };		// counter, default at midpoint 
	
	
	// increment count if input value = 1 and hasn't reached max
	// decrement count if input value = 0 and hasn't reached min, 
	// otherwise, stay put
	always @(posedge i_clk) 
		count <= (count != MAX_COUNT && i_db) ? count+1 :
				(count != MIN_COUNT && !i_db) ? count-1 :
				count;
				
	// count MSB is the output, see ascii diag above
	assign o_db = count[NUMBITS] ? 1 : 0;
endmodule




///*
// * debounce old
// */
//module dBounce (
//		input i_clk, i_db,
//		output o_db
//	);
//	parameter CLOCK = 50_000_000;	// 50 MHz
//	parameter CLOCKDLY = 1;	
//
//	parameter ENDCOUNT = CLOCK/CLOCKDLY;
//	integer count = 0;
//
//	reg prev_pin, out_pin;
//	initial out_pin = i_db;
//	initial prev_pin = i_db;
//
//	always @(posedge i_clk) begin
//		if (prev_pin != i_db) begin
//			count = 0;
//			prev_pin = i_db;
//		end
//		
//		if (count != ENDCOUNT) begin
//			count = count + 1;
//			out_pin = prev_pin;
//		end
//		
//    end
//    assign o_db = out_pin;
//endmodule

