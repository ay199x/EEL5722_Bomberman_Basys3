`timescale 1ns / 1ps

module top_module

(
   input wire clk, rst,                                     // clk from oscillator, rst from asynchronous button
   input wire PB_ENTER, PB_UP, PB_DOWN, PB_LEFT, PB_RIGHT,  // tactile pushbutton inputs
   output wire hsync, vsync,                                // VGA timing outputs
   output wire [11:0] rgb                                   // RGB data for VGA DAC
);

// synchronize asynchronous reset
reg reset;
always@(posedge clk)
   reset <= rst;

// debounce pushbutton inputs to debounced signals U - A
wire U, D, L, R, A;
debounce_button db_u(.clk(clk), .reset(reset), .button(PB_UP)   , .db_out(U));
debounce_button db_d(.clk(clk), .reset(reset), .button(PB_DOWN) , .db_out(D));
debounce_button db_l(.clk(clk), .reset(reset), .button(PB_LEFT) , .db_out(L));
debounce_button db_r(.clk(clk), .reset(reset), .button(PB_RIGHT), .db_out(R));
debounce_button db_a(.clk(clk), .reset(reset), .button(PB_ENTER), .db_out(A));


// constants
localparam X_WALL_L = 48;      // end of left wall x coordinate
localparam Y_WALL_U = 32;      // bottom of top wall y coordinate

localparam LEFT_WALL = 49;     // coordinate positions of arena walls
localparam RIGHT_WALL = 575;
localparam TOP_WALL = 33;
localparam BOTTOM_WALL = 463;

localparam CD_U = 2'b00;       // current direction register vals
localparam CD_R = 2'b01;
localparam CD_D = 2'b10;
localparam CD_L = 2'b11;


// signals
wire display_on, pixel_tick;                      // route VGA signals
wire [9:0] x, y;                                  // VGA x/y pixel location
reg  [11:0] rgb_reg;                              // register to hold RGB signal values to route out
wire [11:0] rgb_next;

wire [11:0] bomberman_rgb, pillar_rgb, block_rgb,
           bomb_rgb, exp_rgb, enemy_rgb,
           background_rgb;                        // routing vector for rgb signals out of object modules
           
wire bomberman_on, pillar_on, block_on,
     bomb_on, exp_on, enemy_on, bm_hb_on,
     score_on;                                    // signals asserted when x/y located within respective object
     
wire [9:0] x_b, y_b;                              // routing vectors for bomberman location
reg  [1:0] current_dir_reg;                       // register to hold current direction of bomberman
wire [1:0] current_dir_next;                      // next-state logic
wire wall_on;                                     // signal asserted when x/y is in outer wall region
wire bm_blocked;                                  // signal asserted when bomberman is blocked by a block
wire block_we;
wire [9:0] block_w_addr;
wire gameover;
wire enemy_hit;
wire post_exp_active;

// x/y pixel coordinates translated to arena coordinates
wire [9:0] x_a, y_a;
assign x_a = x - X_WALL_L;
assign y_a = y - Y_WALL_U;

// infer current direction register
always @(posedge clk, posedge reset)
      if(reset)
         current_dir_reg <= CD_D;
      else 
         current_dir_reg <= current_dir_next;
         
// current direction register next-state logic
assign current_dir_next = U ? CD_U :
                          R ? CD_R :
                          D ? CD_D :
                          L ? CD_L : current_dir_reg;


// aassert wall_on when x/y pixel coordinates are outside arena
assign wall_on = ((x < LEFT_WALL) | ( x > RIGHT_WALL) | (y < TOP_WALL) | (y > BOTTOM_WALL)) ? 1 : 0;

// module instantiations

// instantiate block module

pillar_display pillar_disp_unit(.x(x), .y(y), .x_a(x_a), .y_a(y_a), .pillar_on(pillar_on), .rgb_out(pillar_rgb));

bomberman_module bm_module(.clk(clk), .reset(reset), .x(x), .y(y), .L(L), .R(R), .U(U), .D(D), .cd(current_dir_reg), .bm_blocked(bm_blocked),
                           .gameover(gameover), .bomberman_on(bomberman_on), .bm_hb_on(bm_hb_on),
                           .x_b(x_b), .y_b(y_b), .rgb_out(bomberman_rgb));
                           

block_module block_module_unit(.clk(clk), .reset(reset), .display_on(display_on),
                               .x(x), .y(y), .x_a(x_a), .y_a(y_a), .cd(current_dir_reg), .x_b(x_b),
                               .y_b(y_b), .waddr(block_w_addr), .we(block_we),
                               .rgb_out(block_rgb), .block_on(block_on), .bm_blocked(bm_blocked));


        


bomb_module bomb_module_unit(.clk(clk), .reset(reset), .x_a(x_a), .y_a(y_a), .cd(current_dir_reg), 
                               .x_b(x_b), .y_b(y_b), .A(A), .gameover(gameover), .bomb_rgb(bomb_rgb),
                               .exp_rgb(exp_rgb), .bomb_on(bomb_on), .exp_on(exp_on), .block_w_addr(block_w_addr), 
                               .block_we(block_we), .post_exp_active(post_exp_active));


                        
enemy_module enemy_module_unit(.clk(clk), .reset(reset), .display_on(display_on),
                               .x(x), .y(y), .x_b(x_b), .y_b(y_b),
                               .exp_on(exp_on), .post_exp_active(post_exp_active), .rgb_out(enemy_rgb),
                               .enemy_on(enemy_on), .enemy_hit(enemy_hit));      



                             
game_lives game_lives_unit(.clk(clk), .reset(reset), .x(x), .y(y), .bm_hb_on(bm_hb_on),
                           .enemy_on(enemy_on), .exp_on(exp_on), .gameover(gameover),
                           .background_rgb(background_rgb));



score_display score_display_unit(.clk(clk), .reset(reset), .x(x), .y(y), .enemy_hit(enemy_hit), .score_on(score_on));

// infer register for RGB color data signal
always @(posedge clk, posedge reset)
   if(reset)
      rgb_reg <= 0;
   else 
      rgb_reg <= rgb_next;
      
// rgb register next-state logic
assign rgb_next = pixel_tick? 
                  (bomberman_on & bomberman_rgb != 2049)? bomberman_rgb:
                  (enemy_on     & enemy_rgb     != 2049)? enemy_rgb:
                  (pillar_on)                           ? pillar_rgb:
                  (block_on)                            ? block_rgb:
                  (bomb_on       & bomb_rgb     != 2049)? bomb_rgb:
                  (exp_on        & exp_rgb      != 2048)? exp_rgb :
                  (score_on)                            ? 12'b111111111111:
                  (wall_on)                             ? background_rgb:
                  12'b001000100000 : rgb_reg;

// assign rgb output of top module
assign rgb = (display_on) ? rgb_reg : 8'h00;
                
// instantiate vga synchronization circuit 
vga_sync vga_sync_unit (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync), .video_on(display_on), .p_tick(pixel_tick), .x(x), .y(y));

endmodule