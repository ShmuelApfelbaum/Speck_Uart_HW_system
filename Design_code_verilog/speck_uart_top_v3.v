// speck_uart_top_v3.v
// Top-level module for SPECK64/128 cipher with UART interface
// Target: Basys 3 FPGA (Artix-7)
// 
// VERSION 3: Uses fixed controller that waits for done signal to clear
// This module contains NO logic - only instantiations and wiring

module speck_uart_top_v3 #(
    parameter W = 32,
    parameter ROUNDS = 27,
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    // Clock and Reset
    input  wire clk,           // 100 MHz system clock
    input  wire rst,           // Active-high reset (from button)
    
    // UART Interface
    input  wire uart_rxd,      // UART receive line (from PC)
    output wire uart_txd,      // UART transmit line (to PC)
    
    // Status LEDs (16 available on Basys 3)
    output wire [15:0] led     // Status indicators
);

    // ========================================================================
    // Internal Signal Declarations
    // ========================================================================
    
    // UART RX signals
    wire [7:0] rx_data;
    wire       rx_valid;
    
    // UART TX signals
    wire [7:0] tx_data;
    wire       tx_valid;
    wire       tx_busy;
    
    // Key Schedule signals
    wire [W-1:0]       ks_K0, ks_K1, ks_K2, ks_K3;
    wire               ks_start;
    wire               ks_done;
    wire [W*ROUNDS-1:0] rk_flat;       // Fresh round keys from key schedule
    wire [W*ROUNDS-1:0] rk_flat_out;   // Stored round keys from controller
    
    // Encryptor signals
    wire [W-1:0] enc_pt_x, enc_pt_y;
    wire         enc_start;
    wire [W-1:0] enc_ct_x, enc_ct_y;
    wire         enc_done;
    
    // Decryptor signals
    wire [W-1:0] dec_ct_x, dec_ct_y;
    wire         dec_start;
    wire [W-1:0] dec_pt_x, dec_pt_y;
    wire         dec_done;
    
    // Controller status
    wire [3:0]   state;
    wire         busy;
    
    // ========================================================================
    // UART-Triggered Hardware Reset
    // ========================================================================
    // Detect 'R' (0x52) command and trigger hardware reset (just like button)
    
    reg       uart_reset_trigger;
    reg [15:0] uart_reset_counter;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Button reset pressed - clear UART reset logic
            uart_reset_trigger <= 1'b0;
            uart_reset_counter <= 16'd0;
        end else begin
            // Detect 'R' command (0x52)
            if (rx_valid && rx_data == 8'h52) begin
                uart_reset_trigger <= 1'b1;
                uart_reset_counter <= 16'd1000;  // Hold reset for 1000 cycles (~10us)
            end 
            // Count down reset pulse
            else if (uart_reset_counter > 0) begin
                uart_reset_counter <= uart_reset_counter - 1;
                uart_reset_trigger <= 1'b1;
            end else begin
                uart_reset_trigger <= 1'b0;
            end
        end
    end
    
    // Combine button reset with UART reset
    wire rst_combined = rst | uart_reset_trigger;
    
    // ========================================================================
    // Module Instantiations
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // UART Receiver
    // ------------------------------------------------------------------------
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk(clk),
        .rst(rst_combined),
        .rx(uart_rxd),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );
    
    // ------------------------------------------------------------------------
    // UART Transmitter
    // ------------------------------------------------------------------------
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst_combined),
        .data_in(tx_data),
        .data_valid(tx_valid),
        .tx(uart_txd),
        .busy(tx_busy)
    );
    
    // ------------------------------------------------------------------------
    // SPECK Key Schedule
    // ------------------------------------------------------------------------
    speck_key_schedule #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) u_key_schedule (
        .clk(clk),
        .rst(rst_combined),
        .start(ks_start),
        .K0(ks_K0),
        .K1(ks_K1),
        .K2(ks_K2),
        .K3(ks_K3),
        .rk_flat(rk_flat),
        .busy(),              // Not used
        .done(ks_done)
    );
    
    // ------------------------------------------------------------------------
    // SPECK Encryptor
    // ------------------------------------------------------------------------
    speck_encryptor #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) u_encryptor (
        .clk(clk),
        .rst(rst_combined),
        .start(enc_start),
        .pt_x(enc_pt_x),
        .pt_y(enc_pt_y),
        .rk_flat(rk_flat_out),  // Use stored keys from controller
        .ct_x(enc_ct_x),
        .ct_y(enc_ct_y),
        .done(enc_done)
    );
    
    // ------------------------------------------------------------------------
    // SPECK Decryptor
    // ------------------------------------------------------------------------
    speck_decryptor #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) u_decryptor (
        .clk(clk),
        .rst(rst_combined),
        .start(dec_start),
        .ct_x(dec_ct_x),
        .ct_y(dec_ct_y),
        .rk_flat(rk_flat_out),  // Use stored keys from controller
        .pt_x(dec_pt_x),
        .pt_y(dec_pt_y),
        .done(dec_done)
    );
    
    // ------------------------------------------------------------------------
    // System Controller (VERSION 3 - FIXED DONE SIGNAL BUG)
    // ------------------------------------------------------------------------
    speck_uart_controller_v3 #(
        .W(W),
        .ROUNDS(ROUNDS)
    ) u_controller (
        .clk(clk),
        .rst(rst_combined),
        
        // UART RX interface
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        
        // UART TX interface
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_busy(tx_busy),
        
        // Key schedule interface
        .ks_K0(ks_K0),
        .ks_K1(ks_K1),
        .ks_K2(ks_K2),
        .ks_K3(ks_K3),
        .ks_start(ks_start),
        .ks_done(ks_done),
        .rk_flat(rk_flat),
        .rk_flat_out(rk_flat_out),  // Stored round keys output
        
        // Encryptor interface
        .enc_pt_x(enc_pt_x),
        .enc_pt_y(enc_pt_y),
        .enc_start(enc_start),
        .enc_ct_x(enc_ct_x),
        .enc_ct_y(enc_ct_y),
        .enc_done(enc_done),
        
        // Decryptor interface
        .dec_ct_x(dec_ct_x),
        .dec_ct_y(dec_ct_y),
        .dec_start(dec_start),
        .dec_pt_x(dec_pt_x),
        .dec_pt_y(dec_pt_y),
        .dec_done(dec_done),
        
        // Status outputs
        .state_out(state),
        .busy(busy)
    );
    
    // ========================================================================
    // LED Status Assignment
    // ========================================================================
    
    assign led[0]   = busy;              // LED 0: System busy
    assign led[1]   = rx_valid;          // LED 1: Receiving data
    assign led[2]   = tx_busy;           // LED 2: Transmitting data
    assign led[3]   = ks_done;           // LED 3: Key schedule complete
    assign led[7:4] = state[3:0];        // LED 7-4: State machine position
    assign led[8]   = enc_start;         // LED 8: Encryption active
    assign led[9]   = dec_start;         // LED 9: Decryption active
    assign led[10]  = enc_done;          // LED 10: Encryption done
    assign led[11]  = dec_done;          // LED 11: Decryption done
    assign led[15:12] = 4'b0000;         // LED 15-12: Reserved/unused

endmodule
