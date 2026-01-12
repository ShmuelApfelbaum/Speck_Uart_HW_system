`timescale 1ns / 1ps

module tb_speck_encryptor;

    parameter W      = 32;
    parameter ROUNDS = 27;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz

    reg rst;
    reg start;

    reg  [W-1:0] pt_x, pt_y;
    reg  [W-1:0] rk_array [0:ROUNDS-1];
    reg  [W*ROUNDS-1:0] rk_flat;

    wire [W-1:0] ct_x, ct_y;
    wire done;

    reg [W-1:0] expected_pt_x [0:ROUNDS];
    reg [W-1:0] expected_pt_y [0:ROUNDS];

    speck_encryptor #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .pt_x(pt_x),
        .pt_y(pt_y),
        .rk_flat(rk_flat),
        .ct_x(ct_x),
        .ct_y(ct_y),
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
        pt_x  = 0;
        pt_y  = 0;
        #40;
        rst = 0;

        // -----------------------------
        // Pt[0] input
        // -----------------------------
        
        pt_x = 32'h3b726574;
		pt_y = 32'h7475432d;
		
        #20;
        start = 1;
        #10;
        start = 0;

        // -----------------------------
        // Wait for encryption to finish
        // -----------------------------
        wait (done);

        // -----------------------------
        // Results
        // -----------------------------
        $display("Encryption finished");
        $display("Computed ct_x = %h", ct_x);
        $display("Computed ct_y = %h", ct_y);
        $display("Expected ct_x = %h", expected_pt_x[ROUNDS]);
        $display("Expected ct_y = %h", expected_pt_y[ROUNDS]);

        if (ct_x === expected_pt_x[ROUNDS] &&
            ct_y === expected_pt_y[ROUNDS]) begin
            $display("PASS: ciphertext matches expected");
        end else begin
            $display("FAIL: ciphertext mismatch");
        end

        #50;
        $finish;
    end

endmodule