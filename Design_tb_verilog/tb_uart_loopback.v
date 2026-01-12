`timescale 1ns / 1ps

module tb_uart_loopback;

    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter BIT_TICKS = CLK_FREQ / BAUD_RATE;

    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz

    reg rst;
    reg [7:0] data_in;
    reg data_valid;
    wire tx;
    wire [7:0] data_out;
    wire rx_valid;
    wire tx_busy;

    // Instantiate UART TX
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .tx(tx),
        .busy(tx_busy)
    );

    // Instantiate UART RX
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(tx), // Loopback: tx wire goes to rx
        .data_out(data_out),
        .data_valid(rx_valid)
    );

    initial begin
        rst = 1;
        data_in = 8'h00;
        data_valid = 0;
        #100;
        rst = 0;

        // Send byte 0xA5
        data_in = 8'h9B;
        #20;
        data_valid = 1;
        #10;
        data_valid = 0;

        // Wait for RX to complete reception
        wait (rx_valid);

        #20;
        $display("TX sent: 0x%h", data_in);
        $display("RX got : 0x%h", data_out);

        if (data_out == 8'h9B)
            $display("PASS: Loopback successful");
        else
            $display("FAIL: Loopback mismatch");

    end

endmodule
