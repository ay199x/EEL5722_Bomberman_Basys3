`timescale 1ns / 1ps

module pillar_display
(
   input [9:0] x, y, x_a, y_a,
   output wire pillar_on,             // output asserted high when x,y are within pillar location on screen
   output wire [11:0] rgb_out
);

localparam X_WALL_L = 48;             // end of left wall x coordinate
localparam X_WALL_R = 576;            // begin of right wall x coordinate
localparam Y_WALL_U = 32;             // bottom of top wall y coordinate
localparam Y_WALL_D = 448;            // top of bottom wall y coordinate

// when both of the above play area pixel x_a & y_a coordinates are divided by 16 and both 
// yield even values, the x_a, y_a coordinate is where a pillar should be drawn.

// this is determined easily by checking that the 5th bit is asserted in the x_a & y_a coordinates
// 0-15 (bit = 0), 16-31 (bit = 1), 32-47 (bit = 0), ...

// thus the pillar_on signal is asserted when the pixel location x, y is within the play area and
// the play area pixel coordinates x_a & y_a 5th bits == 1.

assign pillar_on = (x > X_WALL_L & x < X_WALL_R & y > Y_WALL_U & y < Y_WALL_D) &
                    (x_a[4] == 1) & (y_a[4] == 1);

// instantiate pillar sprite ROM
pillar_dm pillar_unit(.a({(x_a[3:0]) + {(y_a[3:0]), 4'd0}}), .spo(rgb_out));

endmodule