`timescale 1ns / 1ps

module game_lives
(
   input wire clk, reset,
   input wire [9:0] x, y,                 // current pixel location on screen
   input wire bm_hb_on, enemy_on, exp_on, // input to determine when bomberman's hitbox overlaps enemy or explosion
   output wire gameover,                  // output asserted when lives == 0 and game is over, used to turn off bomberman moving and bomb
	output wire [11:0] background_rgb      // output for background frame to arena color, going from red to black indicating bomberman's lives
);

localparam INVISIBILITY_MAX = 150000000;  // max value for invisibility counter

// counter register to count a time period after bomberman is hit and cannot be hit immediately again
reg  [27:0] invisibility_reg;
wire [27:0] invisibility_next;

always @(posedge clk, posedge reset)
	if(reset)
		invisibility_reg <= 0;
   else 
	   invisibility_reg <= invisibility_next;

// if register is maxed out, reset to 0,
// if register > 0 and not maxed out, increment,
// if register == 0 and bomberman is hit, start counting up by making register > 0, else keep value of register
assign invisibility_next =                                   (invisibility_reg == INVISIBILITY_MAX) ?                    0 :
                           (invisibility_reg > 0) & (invisibility_reg < INVISIBILITY_MAX)           ? invisibility_reg + 1 :
								   invisibility_reg == 0  & ((exp_on & bm_hb_on) | (enemy_on & bm_hb_on))   ? 1 : invisibility_reg; 

// register to hold number of lives for bomberman, starting with 5
reg  [2:0] lives_reg;
wire [2:0] lives_next;

always @(posedge clk, posedge reset)
	if(reset)
		lives_reg <= 5;
   else 
	   lives_reg <= lives_next;
      
// when bomberman is hit, invisibility_reg is set to 1 and then increments to max, indicating a hit,
// if invisibility_reg == 1 and lives > 0, decrement lives.		
assign lives_next = invisibility_reg == 1 & lives_reg > 0 ? lives_reg - 1 : lives_reg;

// assert gameover output signal when lives == 0
assign gameover = lives_reg == 0;

localparam SCREEN_WIDTH = 640;
localparam SCREEN_HEIGHT = 480;
localparam LIFE_BAR_WIDTH = 20;
localparam LIFE_BAR_HEIGHT = 8;
localparam LIFE_BAR_X_START = SCREEN_WIDTH - LIFE_BAR_WIDTH;
localparam LIFE_BAR_Y_START = 0;

wire is_within_life_bar = (x >= LIFE_BAR_X_START) && (x < LIFE_BAR_X_START + LIFE_BAR_WIDTH) && 
                          (y >= LIFE_BAR_Y_START) && (y < LIFE_BAR_Y_START + LIFE_BAR_HEIGHT);

localparam LIFE_BAR_FILL_PER_LIFE = LIFE_BAR_WIDTH / 5;
wire [9:0] life_bar_fill = (5 - lives_reg) * LIFE_BAR_FILL_PER_LIFE;

assign background_rgb = (is_within_life_bar && (x < LIFE_BAR_X_START + life_bar_fill)) ? 
                          12'b000000000000 : // Black for lost lives
                          (is_within_life_bar ? 12'b111100000000 : 12'b000000000000); // Red for remaining lives or normal background color
					  
endmodule