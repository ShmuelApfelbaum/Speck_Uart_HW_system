module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,               // Serial input
    output reg  [7:0] data_out,   // Received byte
    output reg  data_valid        // Pulse when byte is ready
);

    localparam BIT_TICKS = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT_TICKS = BIT_TICKS / 2;

    reg [15:0] tick_count = 0;
    reg [3:0]  bit_index = 0;
    reg [7:0]  rx_shift = 0;

    reg [1:0]  state = 0;
    localparam IDLE  = 0,
               START = 1,
               DATA  = 2,
               STOP  = 3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            tick_count <= 0;
            bit_index  <= 0;
            data_out   <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0; // default

            case (state)
                IDLE: begin
                    if (~rx) begin // start bit detected
                        state <= START;
                        tick_count <= HALF_BIT_TICKS;
                    end
                end

                START: begin
                    if (tick_count == 0) begin
                        if (~rx) begin // still low
                            state <= DATA;
                            tick_count <= BIT_TICKS - 1;
                            bit_index <= 0;
                        end else begin
                            state <= IDLE; // false start bit
                        end
                    end else begin
                        tick_count <= tick_count - 1;
                    end
                end

                DATA: begin
                    if (tick_count == 0) begin
                        rx_shift[bit_index] <= rx;
                        bit_index <= bit_index + 1;
                        tick_count <= BIT_TICKS - 1;

                        if (bit_index == 7)
                            state <= STOP;
                    end else begin
                        tick_count <= tick_count - 1;
                    end
                end

                STOP: begin
                    if (tick_count == 0) begin
                        if (rx) begin // stop bit should be high
                            data_out <= rx_shift;
                            data_valid <= 1;
                        end
                        state <= IDLE;
                    end else begin
                        tick_count <= tick_count - 1;
                    end
                end

            endcase
        end
    end

endmodule
