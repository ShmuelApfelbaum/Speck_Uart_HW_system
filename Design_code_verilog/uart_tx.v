module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,     // Byte to transmit
    input  wire       data_valid,  // Pulse to start transmission
    output reg        tx,          // Serial output
    output reg        busy         // High while transmitting
);

    localparam BIT_TICKS = CLK_FREQ / BAUD_RATE;

    reg [15:0] tick_count = 0;
    reg [3:0]  bit_index = 0;
    reg [9:0]  tx_shift = 10'b1111111111;  // Start + Data + Stop bits

    reg [1:0] state = 0;
    localparam IDLE  = 0,
               SHIFT = 1,
               DONE  = 2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            tick_count <= 0;
            bit_index  <= 0;
            tx_shift   <= 10'b1111111111;
            tx         <= 1'b1;  // idle = high
            busy       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (data_valid) begin
                        // Load start bit (0), data_in[7:0], stop bit (1)
                        tx_shift <= {1'b1, data_in, 1'b0}; // LSB first
                        bit_index <= 0;
                        tick_count <= BIT_TICKS - 1;
                        state <= SHIFT;
                        busy <= 1;
                    end
                end

                SHIFT: begin
                    tx <= tx_shift[bit_index];

                    if (tick_count == 0) begin
                        bit_index <= bit_index + 1;
                        tick_count <= BIT_TICKS - 1;

                        if (bit_index == 9)
                            state <= DONE;
                    end else begin
                        tick_count <= tick_count - 1;
                    end
                end

                DONE: begin
                    tx <= 1'b1;  // idle
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
