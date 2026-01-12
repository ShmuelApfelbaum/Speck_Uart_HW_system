module speck_round_inverse #(
    parameter W = 32
)(
    input  wire [W-1:0] x_in,
    input  wire [W-1:0] y_in,
    input  wire [W-1:0] k_in,
    output wire [W-1:0] x_out,
    output wire [W-1:0] y_out
);

    wire [W-1:0] y_temp;
    wire [W-1:0] diff;

    // y = ROTR(y ^ x, 3)
    assign y_temp = ((y_in ^ x_in) >> 3) |
                    ((y_in ^ x_in) << (W - 3));

    // diff = (x ^ k) - y
    assign diff = (x_in ^ k_in) - y_temp;

    // x = ROTL(diff, 8)
    assign x_out = (diff << 8) |
                   (diff >> (W - 8));

    assign y_out = y_temp;

endmodule
