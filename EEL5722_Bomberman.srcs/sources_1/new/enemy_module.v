module enemy_module
(
	input wire clk, reset, display_on,
   input wire [9:0] x, y,                   // current pixel location on screen
   input wire [9:0] x_b, y_b,               // bomberman coordinates
   input wire exp_on, post_exp_active,      // signal asserted when explosion on screen and active (bomb_exp_state_reg == post_exp)
   output wire [11:0] rgb_out,              // enemy rgb out
   output wire enemy_on,                    // signal asserted when x/y pixel coordinates are within enemy tile on screen
   output reg enemy_hit                     // output asserted when in "exp_enemy" state
);

// symbolic state declarations
localparam [2:0] idle            = 3'b000,  // wait for motion timer reg to hit max val
                 move_btwn_tiles = 3'b001,  // move enemy in current dir 15 pixels
                 get_rand_dir    = 3'b010,  // get random_dir from LFSR and set r_addr to block module block_map
                 check_dir       = 3'b011,  // check if new dir is blocked by wall or pillar
                 exp_enemy       = 3'b100;  // state for when explosion tile intersects with enemy tile
                 
localparam CD_U = 2'b00;                    // current direction register vals
localparam CD_R = 2'b01;
localparam CD_D = 2'b10;
localparam CD_L = 2'b11;     

localparam X_WALL_L = 48;                   // end of left wall x coordinate
localparam Y_WALL_U = 31;                   // bottom of top wall y coordinate

localparam ENEMY_WH = 16;                   // enemy width/height

// y indexing constants into enemy sprite ROM. 3 frames for UP, RIGHT, DOWN, one frame for when enemy is hit.
localparam U_1 = 0;
localparam U_2 = 16;
localparam U_3 = 32;
localparam R_1 = 48;
localparam R_2 = 64;
localparam R_3 = 80;
localparam D_1 = 96;
localparam D_2 = 112;
localparam D_3 = 128;
localparam exp = 144;

localparam TIMER_MAX = 4000000;                          // max value for motion_timer_reg

localparam ENEMY_X_INIT = X_WALL_L + 10*ENEMY_WH;        // enemy initial value
localparam ENEMY_Y_INIT = Y_WALL_U + 10*ENEMY_WH;        


reg [7:0] rom_offset_reg, rom_offset_next;               // register to hold y index offset into bomberman sprite ROM
reg [2:0] e_state_reg, e_state_next;                     // register for enemy FSM states      
reg [21:0] motion_timer_reg, motion_timer_next;          // delay timer reg, next_state for setting speed of enemy
reg [21:0] motion_timer_max_reg, motion_timer_max_next;  // max value of motion timer reg, gets shorter as game progresses
reg [3:0] move_cnt_reg, move_cnt_next;                   // register to count from 0 to 15, number of pixel steps between tiles
reg [9:0] x_e_reg, y_e_reg, x_e_next, y_e_next;          // enemy x/y location reg, next_state
reg [1:0] e_cd_reg, e_cd_next;                           // enemy current direction register

wire [9:0] x_e_a = (x_e_reg - X_WALL_L);                 // enemy coordinates in arena coordinate frame
wire [9:0] y_e_a = (y_e_reg - Y_WALL_U);
wire [5:0] x_e_abm = x_e_a[9:4];                         // enemy location in ABM coordinates
wire [5:0] y_e_abm = y_e_a[9:4]; 

wire [15:0] random_16;                                   // output from LFSR module

// infer LFSR module, used to get pseudorandom direction for enemy and pseudorandom chance of getting new direction
LFSR_16 LFSR_16_unit(.clk(clk), .rst(reset), .w_en(), .w_in(), .out(random_16));

// infer registers for FSM
always @(posedge clk, posedge reset)
    if (reset)
        begin
        e_state_reg          <= idle;
        x_e_reg              <= ENEMY_X_INIT;          
        y_e_reg              <= ENEMY_Y_INIT;
        e_cd_reg             <= CD_U;
        motion_timer_reg     <= 0;
		  motion_timer_max_reg <= TIMER_MAX;
        move_cnt_reg         <= 0;  
        end
    else
        begin
        e_state_reg          <= e_state_next;
        x_e_reg              <= x_e_next;
        y_e_reg              <= y_e_next;
        e_cd_reg             <= e_cd_next;
        motion_timer_reg     <= motion_timer_next;
		  motion_timer_max_reg <= motion_timer_max_next;
        move_cnt_reg         <= move_cnt_next;
        end
 
// FSM next-state logic
always @*
   begin 
   // defaults
   e_state_next          = e_state_reg;
   x_e_next              = x_e_reg;
   y_e_next              = y_e_reg;
   e_cd_next             = e_cd_reg;
   motion_timer_next     = motion_timer_reg; 
	motion_timer_max_next = motion_timer_max_reg;
   move_cnt_next         = move_cnt_reg;  
	enemy_hit             = 0;

   case(e_state_reg)
    idle: 
        if(exp_on && enemy_on) begin
            motion_timer_next <= 0;
            enemy_hit <= 1;
            e_state_next <= exp_enemy;
        end
        else if(motion_timer_reg == motion_timer_max_reg) begin
            if(move_cnt_reg < 15) begin
                move_cnt_next <= move_cnt_reg + 1;
                e_state_next <= move_btwn_tiles;
            end
            else begin
                move_cnt_next <= 0;
                e_state_next <= get_rand_dir;
            end
            motion_timer_next <= 0;
        end
        else begin
            motion_timer_next <= motion_timer_reg + 1;
            e_state_next <= idle;
        end
    move_btwn_tiles: begin
        if(e_cd_reg == CD_U)
            y_e_next <= y_e_reg - 1;
        else if(e_cd_reg == CD_D)
            y_e_next <= y_e_reg + 1;
        else if(e_cd_reg == CD_L)
            x_e_next <= x_e_reg - 1;
        else if(e_cd_reg == CD_R)
            x_e_next <= x_e_reg + 1;
        e_state_next <= idle;
    end
    get_rand_dir: begin
        if(random_16[4:2] == 3'b000)
            e_cd_next <= random_16[1:0];
        e_state_next <= check_dir;
    end
    check_dir: begin
        if(e_cd_next == CD_U && ((x_e_abm % 2 != 0 && (y_e_abm - 1) % 2 != 0) || y_e_abm == 0))
                e_state_next <= get_rand_dir;
        else if(e_cd_next == CD_D && ((x_e_abm % 2 != 0 && (y_e_abm + 1) % 2 != 0) || y_e_abm == 26))
                e_state_next <= get_rand_dir;
        else if(e_cd_next == CD_L && (((x_e_abm - 1) % 2 != 0 && y_e_abm % 2 != 0) || x_e_abm == 0))
                e_state_next <= get_rand_dir;
        else if(e_cd_next == CD_R && (((x_e_abm + 1) % 2 != 0 && y_e_abm % 2 != 0) || x_e_abm == 32))
                e_state_next <= get_rand_dir;
        else
            e_state_next <= move_btwn_tiles;
    end
    exp_enemy:
        if(!post_exp_active) begin
            motion_timer_next <= 0;
            motion_timer_max_next <= motion_timer_max_reg - 'd1000000;
            enemy_hit <= 0;
            e_state_next <= idle;
        end
        else
            e_state_next <= exp_enemy;
   endcase
	
end         
                        
// assign output telling top_module when to display bomberman's sprite on screen
assign enemy_on = (x >= x_e_reg) & (x <= x_e_reg + ENEMY_WH - 1) & (y >= y_e_reg) & (y <= y_e_reg + ENEMY_WH - 1);

// infer register for index offset into sprite ROM using current direction and frame timer register value
always @(posedge clk, posedge reset)
      if(reset)
         rom_offset_reg <= 0;
      else 
         rom_offset_reg <= rom_offset_next;

// next-state logic for rom offset reg
always @(posedge clk)
      begin
      if(e_state_reg == exp_enemy)     // explosion hit enemy
         rom_offset_next = exp;
      else if(move_cnt_reg[3:2] == 1)  // move_cnt_reg = 4-7
         begin
         if(e_cd_reg == CD_U)          
            rom_offset_next = U_2;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_2;
         else 
            rom_offset_next = R_2;
         end
      else if(move_cnt_reg[3:2] == 3)   // move_cnt_reg = 12-15
         begin
         if(e_cd_reg == CD_U)
            rom_offset_next = U_3;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_3;
         else 
            rom_offset_next = R_3;
         end
      else                              // move_cnt_reg = 0-3, 8-11
         begin
         if(e_cd_reg == CD_U) 
            rom_offset_next = U_1;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_1;
         else 
            rom_offset_next = R_1;
         end
      end

// block ram address, indexing mirrors right sprites when moving left
wire [11:0] br_addr = (e_cd_reg == CD_L) ? 15 - (x - x_e_reg) + ((y-y_e_reg+rom_offset_reg) << 4) 
                                         :      (x - x_e_reg) + ((y-y_e_reg+rom_offset_reg) << 4);

// instantiate bomberman sprite ROM
enemy_sprite_br enemy_s_unit(.clka(clk), .ena(1'b1), .addra(br_addr), .douta(rgb_out));

endmodule