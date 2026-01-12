// speck_uart_controller_v3.v
// Controller for SPECK encryption/decryption via UART
// Command-based protocol:
//   'K' (0x4B) + 16 bytes: Load key → run key schedule → store round keys
//   'E' (0x45) + 8 bytes:  Encrypt using stored keys → return 8 bytes
//   'D' (0x44) + 8 bytes:  Decrypt using stored keys → return 8 bytes
//
// VERSION 3: Fixed done signal not clearing between consecutive operations
// BUG FIX: Wait for done signal to clear in CRYPTO state before proceeding to WAIT_CRYPTO

module speck_uart_controller_v3 #(
    parameter W = 32,
    parameter ROUNDS = 27
)(
    input  wire clk,
    input  wire rst,
    
    // UART RX interface
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    
    // UART TX interface
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    input  wire        tx_busy,
    
    // Key schedule interface
    output reg  [W-1:0]       ks_K0,
    output reg  [W-1:0]       ks_K1,
    output reg  [W-1:0]       ks_K2,
    output reg  [W-1:0]       ks_K3,
    output reg                ks_start,
    input  wire               ks_done,
    input  wire [W*ROUNDS-1:0] rk_flat,
    output wire [W*ROUNDS-1:0] rk_flat_out,  // Stored round keys for crypto modules
    
    // Encryptor interface
    output reg  [W-1:0]       enc_pt_x,
    output reg  [W-1:0]       enc_pt_y,
    output reg                enc_start,
    input  wire [W-1:0]       enc_ct_x,
    input  wire [W-1:0]       enc_ct_y,
    input  wire               enc_done,
    
    // Decryptor interface
    output reg  [W-1:0]       dec_ct_x,
    output reg  [W-1:0]       dec_ct_y,
    output reg                dec_start,
    input  wire [W-1:0]       dec_pt_x,
    input  wire [W-1:0]       dec_pt_y,
    input  wire               dec_done,
    
    // Status outputs (optional, for debugging)
    output reg  [3:0]         state_out,
    output reg                busy
);

    // State machine
    reg [3:0] state;
    localparam IDLE             = 0,
               RX_COMMAND       = 1,
               RX_BYTES         = 2,
               KEY_SCHEDULE     = 3,
               WAIT_KEY         = 4,
               CRYPTO           = 5,
               WAIT_CRYPTO      = 6,
               TX_BYTES         = 7,
               WAIT_TX          = 8,
               DONE_STATE       = 9;
    
    // Command and byte counter
    reg [7:0]  command;          // 'K', 'E', or 'D'
    reg [4:0]  rx_count;         // Byte counter
    reg [4:0]  rx_target;        // Target byte count (16 for key, 8 for data)
    reg [7:0]  rx_buffer [0:15]; // Storage for incoming bytes (max 16 for key)
    
    reg [3:0]  tx_count;         // 0-8 (needs to count to 8 to detect completion)
    reg [7:0]  tx_buffer [0:7];  // Store result bytes
    
    // Stored round keys (persistent across commands)
    reg [W*ROUNDS-1:0] rk_flat_stored;
    reg                keys_loaded;  // Flag: have we loaded keys yet?
    
    // Flag to track if we've already started the crypto operation
    reg                crypto_started;
    
    // Output stored round keys to crypto modules
    assign rk_flat_out = rk_flat_stored;
    
    // Word assembly from received bytes (little endian)
    wire [W-1:0] word0 = {rx_buffer[3],  rx_buffer[2],  rx_buffer[1],  rx_buffer[0]};
    wire [W-1:0] word1 = {rx_buffer[7],  rx_buffer[6],  rx_buffer[5],  rx_buffer[4]};
    wire [W-1:0] word2 = {rx_buffer[11], rx_buffer[10], rx_buffer[9],  rx_buffer[8]};
    wire [W-1:0] word3 = {rx_buffer[15], rx_buffer[14], rx_buffer[13], rx_buffer[12]};
    
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            command        <= 0;
            rx_count       <= 0;
            rx_target      <= 0;
            tx_count       <= 0;
            ks_start       <= 0;
            enc_start      <= 0;
            dec_start      <= 0;
            tx_valid       <= 0;
            busy           <= 0;
            state_out      <= 0;
            keys_loaded    <= 0;
            rk_flat_stored <= 0;
            crypto_started <= 0;
            
            for (i = 0; i < 16; i = i + 1)
                rx_buffer[i] <= 0;
            for (i = 0; i < 8; i = i + 1)
                tx_buffer[i] <= 0;
                
        end else begin
            // Default: clear one-cycle pulses
            ks_start  <= 0;
            enc_start <= 0;
            dec_start <= 0;
            tx_valid  <= 0;
            
            state_out <= state;
            
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (rx_valid) begin
                        command <= rx_data;
                        state <= RX_COMMAND;
                        busy <= 1;
                    end
                end
                
                RX_COMMAND: begin
                    // Parse command and determine how many bytes to receive
                    case (command)
                        8'h4B: begin  // 'K' - Load Key
                            rx_target <= 16;  // Expect 16 bytes (K0-K3)
                            rx_count <= 0;
                            state <= RX_BYTES;
                        end
                        
                        8'h45: begin  // 'E' - Encrypt
                            if (!keys_loaded) begin
                                state <= DONE_STATE;  // Error: no key loaded yet
                            end else begin
                                rx_target <= 8;   // Expect 8 bytes (PT)
                                rx_count <= 0;
                                state <= RX_BYTES;
                            end
                        end
                        
                        8'h44: begin  // 'D' - Decrypt
                            if (!keys_loaded) begin
                                state <= DONE_STATE;  // Error: no key loaded yet
                            end else begin
                                rx_target <= 8;   // Expect 8 bytes (CT)
                                rx_count <= 0;
                                state <= RX_BYTES;
                            end
                        end
                        
                        default: begin
                            state <= DONE_STATE;  // Unknown command, go back to idle
                        end
                    endcase
                end
                
                RX_BYTES: begin
                    if (rx_valid) begin
                        rx_buffer[rx_count] <= rx_data;
                        
                        if (rx_count == rx_target - 1) begin
                            // Route to next state based on command
                            case (command)
                                8'h4B: state <= KEY_SCHEDULE;  // 'K' → run key schedule
                                8'h45: state <= CRYPTO;        // 'E' → encrypt
                                8'h44: state <= CRYPTO;        // 'D' → decrypt
                                default: state <= DONE_STATE;
                            endcase
                        end else begin
                            rx_count <= rx_count + 1;
                        end
                    end
                end
                
                KEY_SCHEDULE: begin
                    // Load key and trigger key schedule (one cycle only)
                    ks_K0 <= word0;  // bytes 0-3
                    ks_K1 <= word1;  // bytes 4-7
                    ks_K2 <= word2;  // bytes 8-11
                    ks_K3 <= word3;  // bytes 12-15
                    ks_start <= 1;
                    state <= WAIT_KEY;
                end
                
                WAIT_KEY: begin
                    // Wait for key schedule to complete (start is auto-cleared by defaults)
                    if (ks_done) begin
                        rk_flat_stored <= rk_flat;  // Store the round keys!
                        keys_loaded <= 1;
                        state <= DONE_STATE;  // 'K' command done, no output to send
                    end
                end
                
                CRYPTO: begin
                    // CRITICAL FIX: Load data once, pulse start once, wait for done to clear
                    if (!crypto_started) begin
                        // First cycle in CRYPTO: load data and pulse start (ONE TIME ONLY)
                        case (command)
                            8'h45: begin  // Encrypt
                                enc_pt_x <= word1;  // bytes 4-7 (SPECK convention: x is upper word)
                                enc_pt_y <= word0;  // bytes 0-3 (SPECK convention: y is lower word)
                                enc_start <= 1;
                            end
                            
                            8'h44: begin  // Decrypt
                                dec_ct_x <= word1;  // bytes 4-7 (SPECK convention: x is upper word)
                                dec_ct_y <= word0;  // bytes 0-3 (SPECK convention: y is lower word)
                                dec_start <= 1;
                            end
                        endcase
                        crypto_started <= 1;  // Mark that we've started
                    end else begin
                        // Subsequent cycles: wait for done signal to clear before proceeding
                        case (command)
                            8'h45: begin
                                if (!enc_done) begin
                                    state <= WAIT_CRYPTO;
                                    crypto_started <= 0;  // Reset for next operation
                                end
                            end
                            
                            8'h44: begin
                                if (!dec_done) begin
                                    state <= WAIT_CRYPTO;
                                    crypto_started <= 0;  // Reset for next operation
                                end
                            end
                        endcase
                    end
                end
                
                WAIT_CRYPTO: begin
                    // Wait for crypto operation to complete
                    if (command == 8'h45) begin  // Encrypt
                        if (enc_done) begin
                            // Store result bytes (little endian) - swap back to match input order
                            {tx_buffer[3], tx_buffer[2], tx_buffer[1], tx_buffer[0]} <= enc_ct_y;  // Lower word
                            {tx_buffer[7], tx_buffer[6], tx_buffer[5], tx_buffer[4]} <= enc_ct_x;  // Upper word
                            
                            tx_count <= 0;
                            state <= TX_BYTES;
                        end
                    end else begin  // Decrypt
                        if (dec_done) begin
                            // Store result bytes (little endian) - swap back to match input order
                            {tx_buffer[3], tx_buffer[2], tx_buffer[1], tx_buffer[0]} <= dec_pt_y;  // Lower word
                            {tx_buffer[7], tx_buffer[6], tx_buffer[5], tx_buffer[4]} <= dec_pt_x;  // Upper word
                            
                            tx_count <= 0;
                            state <= TX_BYTES;
                        end
                    end
                end
                
                TX_BYTES: begin
                    if (!tx_busy && !tx_valid) begin
                        if (tx_count < 8) begin
                            tx_data <= tx_buffer[tx_count];
                            tx_valid <= 1;
                            tx_count <= tx_count + 1;
                            state <= WAIT_TX;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end
                
                WAIT_TX: begin
                    // Wait for TX to become busy, then return to TX_BYTES
                    if (tx_busy) begin
                        state <= TX_BYTES;
                    end
                end
                
                DONE_STATE: begin
                    busy <= 0;
                    rx_count <= 0;
                    state <= IDLE;
                end
                
            endcase
        end
    end

endmodule

