`timescale 1ns/1ps

module tb_key_schedule;

    parameter W = 32;
    parameter R = 27;

    reg clk = 0;
    reg rst = 0;
    reg start = 0;

    // Keys: starting from K3 = 0x1b1a1918
    reg [W-1:0] K3 = 32'h1b1a1918;
    reg [W-1:0] K2 = 32'h13121110;
    reg [W-1:0] K1 = 32'h0b0a0908;
    reg [W-1:0] K0 = 32'h03020100;

    wire [W*R-1:0] rk_flat;
    wire busy;
    wire done;

    // DUT
    speck_key_schedule #(
        .W(W),
        .ROUNDS(R)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .K0(K0),
        .K1(K1),
        .K2(K2),
        .K3(K3),
        .rk_flat(rk_flat),
        .busy(busy),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Reset
        rst = 1;
        #20;
        rst = 0;

        // Start key schedule
        #10;
        start = 1;
        #10;
        start = 0;

        // Wait for done
        wait(done);
        #10;
		$display("Input Keys: K0=%h K1=%h K2=%h K3=%h", K0, K1, K2, K3);
        // Dump all round keys
        $display("Flattened round keys:");
        //for (i = 0; i < R; i = i + 1) begin
        //    $display("rk[%0d] = %h", i, rk_flat[i*W +: W]);
        //end
		for (i = 0; i < R; i = i + 4) begin
			if (i + 3 < R)
				$display("rk[%0d]=%h  rk[%0d]=%h  rk[%0d]=%h  rk[%0d]=%h", 
						 i, rk_flat[i*W +: W], 
						 i+1, rk_flat[(i+1)*W +: W], 
						 i+2, rk_flat[(i+2)*W +: W], 
						 i+3, rk_flat[(i+3)*W +: W]);
			else if (i + 2 < R)
				$display("rk[%0d]=%h  rk[%0d]=%h  rk[%0d]=%h", 
						 i, rk_flat[i*W +: W], 
						 i+1, rk_flat[(i+1)*W +: W], 
						 i+2, rk_flat[(i+2)*W +: W]);
			else if (i + 1 < R)
				$display("rk[%0d]=%h  rk[%0d]=%h", 
						 i, rk_flat[i*W +: W], 
						 i+1, rk_flat[(i+1)*W +: W]);
			else
				$display("rk[%0d]=%h", i, rk_flat[i*W +: W]);
		end		

        $stop;
    end

endmodule
