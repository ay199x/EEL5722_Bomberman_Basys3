module LFSR_16(
    input wire clk, rst, w_en,
    input wire [15:0] w_in,
    output wire [15:0] out
);

reg [15:0] current_value, next_value;
wire feedback;

always @(posedge clk or posedge rst) begin
    if (rst) 
        current_value <= 16'd1;  // Initialize to a non-zero value
    else if (w_en) 
        current_value <= w_in;  // External input to set the LFSR value
    else 
        current_value <= next_value;
end

always @(*) begin
    next_value = {current_value[14:0], feedback};  // Shift left and input feedback
end

assign out = current_value;

assign feedback = current_value[15] ^ current_value[5] ^ current_value[3] ^ current_value[2];

endmodule
