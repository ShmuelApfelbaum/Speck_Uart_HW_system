// speck_key_schedule.v (Model B, with rk_flat output)
module speck_key_schedule #(
    parameter W      = 32,
    parameter ROUNDS = 27
)(
    input  wire             clk,
    input  wire             rst,     // synchronous reset
    input  wire             start,   // 1-cycle pulse to begin (when !busy)

    input  wire [W-1:0]     K0,
    input  wire [W-1:0]     K1,
    input  wire [W-1:0]     K2,
    input  wire [W-1:0]     K3,

    output reg  [W*ROUNDS-1:0] rk_flat,  // FLATTENED round key output
    output reg                busy,
    output reg                done
);

    // round-key memory
    reg [W-1:0] rk_mem [0:ROUNDS-1];
    reg [W-1:0] l_mem [0:ROUNDS+1];

    reg [4:0] i;

    reg [W-1:0] x_in_r, y_in_r, k_in_r;
    wire [W-1:0] x_out_w, y_out_w;

    speck_round #(.W(W)) u_round_for_keys (
        .x_in (x_in_r),
        .y_in (y_in_r),
        .k_in (k_in_r),
        .x_out(x_out_w),
        .y_out(y_out_w)
    );

    integer j;

    always @(posedge clk) begin
        if (rst) begin
            busy    <= 0;
            done    <= 0;
            i       <= 0;
            rk_flat <= 0;

            for (j = 0; j < ROUNDS; j = j + 1) rk_mem[j] <= 0;
            for (j = 0; j < ROUNDS + 2; j = j + 1) l_mem[j] <= 0;

            x_in_r <= 0;
            y_in_r <= 0;
            k_in_r <= 0;

        end else begin
            done <= 0;

            if (start && !busy) begin
                busy <= 1;
                i    <= 0;

                rk_mem[0] <= K0;
                l_mem[0]  <= K1;
                l_mem[1]  <= K2;
                l_mem[2]  <= K3;

                x_in_r <= K1;
                y_in_r <= K0;
                k_in_r <= 0;

            end else if (busy) begin
                // Write round results
                l_mem[i + 3]     <= x_out_w;
                rk_mem[i + 1]    <= y_out_w;

                if (i == ROUNDS - 1) begin
                    busy <= 0;
                    done <= 1;

                    // flatten the rk_mem into rk_flat
                    for (j = 0; j < ROUNDS; j = j + 1)
                        rk_flat[j*W +: W] <= rk_mem[j];

                end else begin
                    i      <= i + 1;
                    x_in_r <= l_mem[i + 1];
                    y_in_r <= y_out_w;
                    k_in_r <= {{(W-5){1'b0}}, i + 1};
                end
            end
        end
    end

endmodule
