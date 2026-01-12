// speck_decryptor.v
module speck_decryptor #(
    parameter W = 32,
    parameter ROUNDS = 27
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  start,
    input  wire [W-1:0]          ct_x,
    input  wire [W-1:0]          ct_y,
    input  wire [W*ROUNDS-1:0]   rk_flat,
    output reg  [W-1:0]          pt_x,
    output reg  [W-1:0]          pt_y,
    output reg                   done
);

    // current state
    reg [W-1:0] x, y;
    reg [5:0]   round;
    reg         busy;

    // current round key (reverse order)
    wire [W-1:0] rk_curr;
    assign rk_curr = rk_flat[round*W +: W];

    // next-state from inverse round
    wire [W-1:0] x_next, y_next;

    speck_round_inverse #(.W(W)) u_inv_round (
        .x_in (x),
        .y_in (y),
        .k_in (rk_curr),
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
            pt_x  <= 0;
            pt_y  <= 0;
        end else begin
            if (start && !busy) begin
                x     <= ct_x;
                y     <= ct_y;
                round <= ROUNDS-1;
                busy  <= 1;
                done  <= 0;
            end else if (busy) begin
                if (round > 0) begin
                    x <= x_next;
                    y <= y_next;
                    round <= round - 1;
                end else begin
                    pt_x <= x_next;
                    pt_y <= y_next;
                    busy <= 0;
                    done <= 1;
                end
            end
        end
    end

endmodule
