module score_display
(  
    input wire clk, reset,   // clock, reset signal inputs for synchronous roms and registers
    input wire [9:0] x, y,   // vga x/y pixel location
	 input enemy_hit,         // signal asserted when enemy is hit by explosion
    output reg score_on      // output asserted when x/y are within score location in display
); 

localparam NUM_WIDTH  = 16;
localparam NUM_TOP    = 16;
localparam NUM_BOTTOM = 32;

// The four bcd values bcd3 - bcd0 are displayed with boundaries A-E 
// |_|_|_|_|
// A B C D E

localparam A = 288;
localparam B = 304;
localparam C = 320;
localparam D = 336;
localparam E = 352;

// positive edge detection of enemy_hit
reg enemy_hit_reg;

always @(posedge clk, posedge reset)
   if(reset)
      enemy_hit_reg <= 0;
   else enemy_hit_reg <= enemy_hit;
   
wire enemy_hit_posedge = enemy_hit & ~enemy_hit_reg; 

   
// track score in register
reg  [13:0] score_reg;
wire [13:0] score_next;

always @(posedge clk, posedge reset)
   if(reset)
      score_reg <= 0;
   else 
	   score_reg <= score_next;

assign score_next = enemy_hit_posedge & score_reg < 9980 ? score_reg + 10 : score_reg;   

// route bcd values out from binary to bcd conversion circuit
wire [3:0] bcd3, bcd2, bcd1, bcd0;

// instantiate binary to bcd conversion circuit
binary2bcd bcd_unit (.clk(clk), .reset(reset), .start(enemy_hit_posedge),
                      .in(score_next), .bcd3(bcd3), .bcd2(bcd2), .bcd1(bcd1), .bcd0(bcd0),
							 .count(), .state());

// row and column regs to index numbers_rom
reg [7:0] row;
reg [3:0] col;

// output from numbers_rom
wire color_data;

// infer numbers rom
//numbers_dm numbers_dm_unit(.a({col + row}), .spo(color_data));
// infer number bitmap rom
numbers_rom numbers_rom_unit(.clk(clk), .row(row), .col(col), .color_data(color_data));

// display 4 digits on screen
always @* 
   begin
   // defaults
   score_on = 0;
   row = 0;
   col = 0;
   if(y >= NUM_TOP & y < NUM_BOTTOM)
      begin
      // if vga pixel within bcd3 location on screen
      if(x >= A & x < B)
         begin
         col = x - A;
         row = y - NUM_WIDTH + (bcd3 << 4); // offset row index by scaled bcd3 value
         if(color_data == 1'b1)      // if bit is 1, assert score_on output
            score_on = 1;
         end
      
      // if vga pixel within bcd2 location on screen
      if(x >= B & x < C)
         begin
         col = x - B;
         row = y - NUM_WIDTH + (bcd2 << 4); // offset row index by scaled bcd2 value
         if(color_data == 1'b1)      // if bit is 1, assert score_on output
            score_on = 1;
         end
      
      // if vga pixel within bcd1 location on screen
      if(x >= C & x < D)
         begin
         col = x - C;
         row = y - NUM_WIDTH + (bcd1 << 4); // offset row index by scaled bcd1 value
         if(color_data == 1'b1)      // if bit is 1, assert score_on output
            score_on = 1;
         end
      
      // if vga pixel within bcd0 location on screen
      if(x >= D & x < E)
         begin
         col = x - D;
         row = y - NUM_WIDTH + (bcd0 << 4); // offset row index by scaled bcd0 value
         if(color_data == 1'b1)      // if bit is 1, assert score_on output
            score_on = 1;
         end
      end
   end
   
endmodule