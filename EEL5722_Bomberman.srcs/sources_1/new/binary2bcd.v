module binary2bcd(
    input wire clk, reset,
    input wire start,
    input wire [13:0] in,
    output wire [3:0] bcd3, bcd2, bcd1, bcd0,
    output wire [3:0] count,
    output wire [1:0] state
);

    localparam [2:0] 
        S_IDLE = 3'b000,
        S_INIT = 3'b001,
        S_SHIFT = 3'b010,
        S_CHECK1 = 3'b011,
        S_CHECK2 = 3'b100,
        S_CHECK3 = 3'b101,
        S_CHECK4 = 3'b110,
        S_FINISH = 3'b111;

    reg [15:0] bcd_internal;
    reg [13:0] binary_internal;
    reg [2:0] fsm_state = S_IDLE;
    reg [3:0] shift_counter;
    reg [3:0] digit_1000, digit_100, digit_10, digit_1;

    assign bcd3 = digit_1000;
    assign bcd2 = digit_100;
    assign bcd1 = digit_10;
    assign bcd0 = digit_1;
    assign count = shift_counter;
    assign state = fsm_state[1:0];

    always @(posedge clk) begin
        if (reset) begin
            bcd_internal <= 0;
            binary_internal <= 0;
            digit_1000 <= 0;
            digit_100 <= 0;
            digit_10 <= 0;
            digit_1 <= 0;
            fsm_state <= S_IDLE;
        end else begin
            case (fsm_state)
                S_IDLE: 
                    if (start)
                        fsm_state <= S_INIT;
                S_INIT: begin
                    binary_internal <= in;
                    shift_counter <= 0;
                    bcd_internal <= 0;
                    fsm_state <= S_SHIFT;
                end
                S_SHIFT:
                    if (shift_counter < 14) begin
                        bcd_internal <= {bcd_internal[14:0], binary_internal[13]};
                        binary_internal <= binary_internal << 1;
                        shift_counter <= shift_counter + 1;
                        fsm_state <= S_CHECK1;
                    end else
                        fsm_state <= S_FINISH;
                S_CHECK1: begin
                    if (bcd_internal[15:12] > 4)
                        bcd_internal[15:12] <= bcd_internal[15:12] + 3;
                    fsm_state <= S_CHECK2;
                end
                S_CHECK2: begin
                    if (bcd_internal[11:8] > 4)
                        bcd_internal[11:8] <= bcd_internal[11:8] + 3;
                    fsm_state <= S_CHECK3;
                end
                S_CHECK3: begin
                    if (bcd_internal[7:4] > 4)
                        bcd_internal[7:4] <= bcd_internal[7:4] + 3;
                    fsm_state <= S_CHECK4;
                end
                S_CHECK4: begin
                    if (bcd_internal[3:0] > 4)
                        bcd_internal[3:0] <= bcd_internal[3:0] + 3;
                    fsm_state <= S_SHIFT;
                end
                S_FINISH: begin
                    digit_1000 <= bcd_internal[15:12];
                    digit_100 <= bcd_internal[11:8];
                    digit_10 <= bcd_internal[7:4];
                    digit_1 <= bcd_internal[3:0];
                    fsm_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
