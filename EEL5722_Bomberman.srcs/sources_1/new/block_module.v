`timescale 1ns / 1ps

module block_module
(
   input wire clk, reset, display_on,
   input wire [9:0] x, y, x_a, y_a,     // current pixel location on screen, without and with arena offset subtracted
   input wire [1:0] cd,                 // bomberman current direction
   input wire [9:0] x_b, y_b,           // bomberman coordinates
   input wire [9:0] waddr,              // write address (a) into block map RAM
   input wire we,                       // write enable to block map RAM
   output wire [11:0] rgb_out,          // output block rgb
   output wire block_on,                // asserted when x/y within block location on screen
   output wire bm_blocked               // asserted when bomberman is blocked by a block at current location and direction
);

localparam X_WALL_L = 48;                       // end of left wall x coordinate
localparam X_WALL_R = 576;                      // begin of right wall x coordinate
localparam Y_WALL_U = 32;                       // bottom of top wall y coordinate
localparam Y_WALL_D = 448;                      // top of bottom wall y coordinate

localparam BM_HB_OFFSET_9 = 9;                  // offset from top of sprite down to top of 16x16 hit box              
localparam BM_WIDTH       = 16;                 // sprite width
localparam BM_HEIGHT      = 25;                 // sprite height

localparam UP_LEFT_X   = 48;                    // constraints of Bomberman sprite location (upper left corner) within arena.
localparam UP_LEFT_Y   = 32;
localparam LOW_RIGHT_X = 576 - BM_WIDTH;
localparam LOW_RIGHT_Y = 448 - BM_HB_OFFSET_9;    

localparam CD_U = 2'b00;                        // current direction register vals
localparam CD_R = 2'b01;
localparam CD_D = 2'b10;
localparam CD_L = 2'b11;       

// IO for block map dual port RAM
wire data_in = 1'b0; // data input (d)
reg [9:0] raddr;     // read address (dpra)          // write enable (we)
wire data_out;       // data output (dpo)

// signals used to index into block_map RAM to determine if bomberman will collide with a box 
// if moving in a specific direction at the current location. format: <coordinate>_b_hit_<left, right, bottom, top>
wire [9:0] x_b_hit_l, x_b_hit_r, y_b_hit_b, y_b_hit_t;    
wire [9:0] y_b_hit_lr, x_b_hit_bt;

assign x_b_hit_l  = x_b - 1 - X_WALL_L;                   // x coordinate of left  edge of hitbox
assign x_b_hit_r  = x_b + BM_WIDTH - X_WALL_L;            // x coordinate of right edge of hitbox
assign y_b_hit_lr = y_b + BM_HB_OFFSET_9 + 8 - Y_WALL_U;  // y coordinate of middle of hit box

assign y_b_hit_b  = y_b + BM_HEIGHT - Y_WALL_U;           // y coordiante of bottom of hitbox if sprite were going to move down (y + 1)
assign y_b_hit_t  = y_b + BM_HB_OFFSET_9 - 1 - Y_WALL_U;  // y coordinate of top of hitbox if sprite were going to move up (y - 1)
assign x_b_hit_bt = x_b + 7 - X_WALL_L;                   // x coordinate of middle of hitbox

// read address into block_map RAM
// first address condition reads into RAM for current ABM coordinate of VGA pixel on screen to display blocks
// next four address conditions index into RAM to check block_map if a block is in bomberman's path to assert bm_blocked output           
always @(posedge clk)
   begin
   if(display_on & x > X_WALL_L & x < X_WALL_R & y > Y_WALL_U & y < Y_WALL_D+16)
      raddr = x_a[9:4] + y_a[9:4]*33;
   else if(!display_on)
      begin
      if(cd == CD_L)
         raddr = x_b_hit_l[9:4]  + y_b_hit_lr[9:4]*33;
      else if(cd == CD_R)
         raddr = x_b_hit_r[9:4]  + y_b_hit_lr[9:4]*33;
      else if(cd == CD_U)
         raddr = x_b_hit_bt[9:4] +  y_b_hit_t[9:4]*33;
      else 
         raddr = x_b_hit_bt[9:4] +  y_b_hit_b[9:4]*33;
      end
   else 
      raddr = 896; // don't care index in RAM
   end
   
// instantiate block sprite ROM
// index into ROM uses x/y pixel arena coordinates lower 4 bits, as each block is 16x16
block_dm block_unit(.a((x_a[3:0]) + {(y_a[3:0]), 4'd0}), .spo(rgb_out));

// instantiate block_map distributed dual port RAM
block_map block_map_unit(.a(waddr), .d(data_in), .dpra(raddr), .clk(clk), .we(we), .spo(), .dpo(data_out));
   
// register to hold state of bomberman being blocked in current direction by a block
reg blocked_reg; 
wire blocked_next;

always @(posedge clk, posedge reset)
   if(reset)
      blocked_reg <= 0;
   else 
      blocked_reg <= blocked_next;
      
// check output of block_map when !display_on and raddr is looking for a block in bomberman's path
assign blocked_next = (!display_on & data_out == 1) ? 1 : 
                      (!display_on & data_out == 0) ? 0 : blocked_reg;

// assert when bomberman is blocked by a block
assign bm_blocked = blocked_reg;

// assert when display is on and output from block_map is 1, indicating x/y is in a block
assign block_on = display_on & data_out; 

endmodule