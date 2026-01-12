// speck_round.v  (Speck64: word size = 32)
module speck_round #(
    parameter W = 32
)(
    input  wire [W-1:0] x_in,   // left word
    input  wire [W-1:0] y_in,   // right word
    input  wire [W-1:0] k_in,   // round key
    output wire [W-1:0] x_out,
    output wire [W-1:0] y_out
);

    function [W-1:0] rotr;
        input [W-1:0] v;
        input [5:0]   sh;
        begin
            rotr = (v >> sh) | (v << (W - sh));
        end
    endfunction

    function [W-1:0] rotl;
        input [W-1:0] v;
        input [5:0]   sh;
        begin
            rotl = (v << sh) | (v >> (W - sh));
        end
    endfunction

    wire [W-1:0] x1 = (rotr(x_in, 8) + y_in) ^ k_in;
    wire [W-1:0] y1 =  rotl(y_in, 3) ^ x1;

    assign x_out = x1;
    assign y_out = y1;

endmodule
