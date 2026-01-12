// tb_speck_round.v
`timescale 1ns/1ps

module tb_speck_round;

    localparam W = 32;

    reg  [W-1:0] x, y, k;
    wire [W-1:0] xo, yo;

    speck_round #(W) dut (
        .x_in(x), .y_in(y), .k_in(k),
        .x_out(xo), .y_out(yo)
    );

    reg [W-1:0] xr, yr;

    initial begin
        x = 32'h0; 
        y = 32'h0;
        k = 32'h0;
		xr = 32'h0;
        yr = 32'h0;
        #1;
		x = 32'hebb2b492; 
        y = 32'h4818adf9;
        k = 32'h131d0309;
		xr = 32'hc81963a4;
        yr = 32'h88dc0c6e;
        if (xo !== xr || yo !== yr) begin
            $display("FAIL test1: got xo=%h yo=%h expected xr=%h yr=%h", xo, yo, xr, yr);
			#1;
			$stop;
        end

        $display("PASS: speck_round");
		#1;
		$stop;
    end

endmodule

