// speck_encryptor.v
module speck_encryptor #(
    parameter W = 32,
    parameter ROUNDS = 27
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire [W-1:0]         pt_x,
    input  wire [W-1:0]         pt_y,
    input  wire [W*ROUNDS - 1:0]  rk_flat,
    output reg  [W-1:0]         ct_x,
    output reg  [W-1:0]         ct_y,
    output reg                  done
);

    // current state
    reg [W-1:0] x, y;
    reg [5:0]   round;
    reg         busy;

    // unpacked round key (internal only)
    wire [W-1:0] rk_curr;
    assign rk_curr = rk_flat[round*W +: W];

    // next-state from round function
    wire [W-1:0] x_next, y_next;

    speck_round #(.W(W)) u_round (
        .x_in(x),
        .y_in(y),
        .k_in(rk_curr),
        .x_out(x_next),
        .y_out(y_next)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x     <= 0;
            y     <= 0;
            round <= 0;
            busy  <= 0;
            done  <= 0;
            ct_x  <= 0;
            ct_y  <= 0;
        end else begin
            if (start && !busy) begin
                x     <= pt_x;
                y     <= pt_y;
                round <= 0;
                busy  <= 1;
                done  <= 0;
            end else if (busy) begin
				if (round < ROUNDS-1) begin
					x <= x_next;
					y <= y_next;
					round <= round + 1;
				end else if (round == ROUNDS-1) begin
                ct_x <= x_next;
                ct_y <= y_next;
                busy <= 0;
                done <= 1;
                end
            end
        end
    end

endmodule
