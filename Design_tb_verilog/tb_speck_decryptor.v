`timescale 1ns / 1ps

module tb_speck_decryptor;

    parameter W      = 32;
    parameter ROUNDS = 27;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz

    reg rst;
    reg start;

    reg  [W-1:0] ct_x, ct_y;
    reg  [W-1:0] rk_array [0:ROUNDS-1];
    reg  [W*ROUNDS-1:0] rk_flat;

    wire [W-1:0] pt_x, pt_y;
    wire done;

    reg [W-1:0] expected_pt_x [0:ROUNDS];
    reg [W-1:0] expected_pt_y [0:ROUNDS];

    speck_decryptor #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .ct_x(ct_x),
        .ct_y(ct_y),
        .rk_flat(rk_flat),
        .pt_x(pt_x),
        .pt_y(pt_y),
        .done(done)
    );

    integer i;

    initial begin
        // -----------------------------
        // Load reference data
        // -----------------------------
        $readmemh("expected_rk.mem",   rk_array);
        $readmemh("expected_pt_x.mem", expected_pt_x);
        $readmemh("expected_pt_y.mem", expected_pt_y);

        // Flatten round keys
        for (i = 0; i < ROUNDS; i = i + 1)
            rk_flat[i*W +: W] = rk_array[i];

        // -----------------------------
        // Reset
        // -----------------------------
        rst   = 1;
        start = 0;
        ct_x  = 0;
        ct_y  = 0;
        #40;
        rst = 0;

        // -----------------------------
        // Ciphertext = Pt[ROUNDS]
        // -----------------------------
        ct_x = expected_pt_x[ROUNDS];
        ct_y = expected_pt_y[ROUNDS];

        #20;
        start = 1;
        #10;
        start = 0;

        // -----------------------------
        // Wait for decryption
        // -----------------------------
        wait (done);

        // -----------------------------
        // Results
        // -----------------------------
        $display("Decryption finished");
        $display("Computed pt_x = %h", pt_x);
        $display("Computed pt_y = %h", pt_y);
        $display("Expected pt_x = %h", expected_pt_x[0]);
        $display("Expected pt_y = %h", expected_pt_y[0]);

        if (pt_x === expected_pt_x[0] &&
            pt_y === expected_pt_y[0]) begin
            $display("PASS: plaintext matches expected");
        end else begin
            $display("FAIL: plaintext mismatch");
        end

        #50;
        $stop;
    end

endmodule