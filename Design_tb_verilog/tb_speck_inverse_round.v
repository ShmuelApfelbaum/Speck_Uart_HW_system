`timescale 1ns/1ps

module tb_speck_inverse_round;

    parameter W = 32;

    reg  [W-1:0] ct_x, ct_y;
    reg  [W-1:0] rk;
    wire [W-1:0] pt_x, pt_y;

    speck_round_inverse #(.W(W)) uut (
        .x_in(ct_x),
        .y_in(ct_y),
        .k_in(rk),
        .x_out(pt_x),
        .y_out(pt_y)
    );

    initial begin
        // Inputs: ciphertext (from encryption output), rk[0]
        ct_x = 32'hc81963a4; // PT[1] was used as ct_x
        ct_y = 32'h88dc0c6e; // PT[0] was used as ct_y
        rk   = 32'h131d0309; // use same round key that was used in encrypt round 0

        #5;

        $display("==== Speck Inverse Round ====");
        $display("Input CT_x = %h", ct_x);
        $display("Input CT_y = %h", ct_y);
        $display("Key         = %h", rk);
        $display("Decrypted PT_x = %h", pt_x);
        $display("Decrypted PT_y = %h", pt_y);

        $stop;
    end

endmodule
