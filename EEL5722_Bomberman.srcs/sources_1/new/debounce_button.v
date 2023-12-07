`timescale 1ns / 1ps

module debounce_button
(
   input wire clk, reset, button,
	output db_out
);

// debounce button input for 2 ms (super long, but still responsive)
reg [17:0] db_reg;     // register for debounce counter

// infer debounce register and next-state logic 
always @(posedge clk, posedge reset)
	if(reset)
		db_reg <= 0;
	else
		// if button unpressed, set to 0, else if button pressed and db_reg not maxed,
		// increment, else remain the same
		db_reg <= !button ? 0 : (button && db_reg < 200000) ? db_reg + 1 : db_reg;
	
// assing debounced signal, asserted when db_reg maxes out, and 2 ms have elapsed 
assign db_out = (db_reg == 200000) ? 1 : 0;

endmodule