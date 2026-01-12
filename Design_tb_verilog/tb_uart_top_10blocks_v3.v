`timescale 1ns / 1ps

// VERSION 3: Tests the fixed controller that waits for done signal to clear
module tb_uart_top_10blocks_v3;

    // Parameters
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 10;  // 100 MHz = 10ns
    parameter NUM_BLOCKS = 10;
    
    // DUT signals
    reg clk;
    reg rst;
    reg uart_rxd;
    wire uart_txd;
    wire [15:0] led;
    
    // UART bit timing
    localparam BIT_TIME = 1_000_000_000 / BAUD_RATE;  // in ns
    
    // Real UART RX for capturing responses
    wire [7:0] rx_data;
    wire rx_valid;
    
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_testbench_rx (
        .clk(clk),
        .rst(rst),
        .rx(uart_txd),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );
    
    // DUT - Top-level module (VERSION 3)
    speck_uart_top_v3 #(
        .W(32),
        .ROUNDS(27),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .led(led)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task: Capture byte from UART (with debug)
    task capture_tx_byte;
        output [7:0] byte_val;
        begin
            $display("    [%0t] Waiting for TX byte (rx_valid=%0b)...", $time, rx_valid);
            wait(rx_valid == 1);
            byte_val = rx_data;
            $display("    [%0t] Captured TX byte: %02h", $time, rx_data);
            wait(rx_valid == 0);
            $display("    [%0t] rx_valid cleared", $time);
        end
    endtask
    
    // Task: Send byte via UART (with debug)
    task send_uart_byte;
        input [7:0] byte;
        integer i;
        begin
            $display("    [%0t] Sending RX byte: %02h", $time, byte);
            uart_rxd = 0;  // Start bit
            #BIT_TIME;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = byte[i];
                #BIT_TIME;
            end
            uart_rxd = 1;  // Stop bit
            #BIT_TIME;
            $display("    [%0t] Sent RX byte: %02h complete", $time, byte);
        end
    endtask
    
    // Storage for test data
    reg [7:0] plaintext [0:NUM_BLOCKS-1][0:7];   // 10 blocks, 8 bytes each
    reg [7:0] ciphertext [0:NUM_BLOCKS-1][0:7];  // 10 blocks, 8 bytes each
    reg [7:0] decrypted [0:NUM_BLOCKS-1][0:7];   // 10 blocks, 8 bytes each
    
    // Test key (fixed)
    reg [7:0] test_key [0:15];
    
    integer i, j, block_num;
    reg [7:0] temp_byte;
    integer errors;
    
    // Monitor controller FSM state changes
    reg [3:0] prev_ctrl_state = 0;
    always @(posedge clk) begin
        if (dut.u_controller.state_out != prev_ctrl_state) begin
            case (dut.u_controller.state_out)
                0: $display("    [%0t] CTRL FSM: IDLE", $time);
                1: $display("    [%0t] CTRL FSM: RX_COMMAND", $time);
                2: $display("    [%0t] CTRL FSM: RX_BYTES (count=%0d)", $time, dut.u_controller.rx_count);
                3: $display("    [%0t] CTRL FSM: KEY_SCHEDULE", $time);
                4: $display("    [%0t] CTRL FSM: WAIT_KEY", $time);
                5: $display("    [%0t] CTRL FSM: CRYPTO", $time);
                6: $display("    [%0t] CTRL FSM: WAIT_CRYPTO", $time);
                7: $display("    [%0t] CTRL FSM: TX_BYTES (count=%0d)", $time, dut.u_controller.tx_count);
                8: $display("    [%0t] CTRL FSM: WAIT_TX", $time);
                9: $display("    [%0t] CTRL FSM: DONE_STATE", $time);
                default: $display("    [%0t] CTRL FSM: UNKNOWN (%0d)", $time, dut.u_controller.state_out);
            endcase
            prev_ctrl_state <= dut.u_controller.state_out;
        end
    end
    
    // Monitor controller RX data reception (from top-level UART RX)
    always @(posedge clk) begin
        if (dut.rx_valid) begin
            $display("    [%0t] CTRL RX: Received byte %02h (ctrl_state=%0d, rx_count=%0d)", 
                     $time, dut.rx_data, dut.u_controller.state, dut.u_controller.rx_count);
        end
    end
    
    initial begin
        $display("========================================================");
        $display("SPECK64/128 Multi-Block Test - 10 Blocks Round-Trip");
        $display("VERSION 3: Fixed Controller - Done Signal Bug");
        $display("========================================================");
        $display("");
        
        // Initialize
        rst = 1;
        uart_rxd = 1;
        errors = 0;
        
        // Setup test key: 00 01 02 03 08 09 0a 0b 10 11 12 13 18 19 1a 1b
        test_key[0]  = 8'h00; test_key[1]  = 8'h01; test_key[2]  = 8'h02; test_key[3]  = 8'h03;
        test_key[4]  = 8'h08; test_key[5]  = 8'h09; test_key[6]  = 8'h0a; test_key[7]  = 8'h0b;
        test_key[8]  = 8'h10; test_key[9]  = 8'h11; test_key[10] = 8'h12; test_key[11] = 8'h13;
        test_key[12] = 8'h18; test_key[13] = 8'h19; test_key[14] = 8'h1a; test_key[15] = 8'h1b;
        
        // Setup 10 different plaintext blocks (varied data)
        plaintext[0][0] = 8'h2d; plaintext[0][1] = 8'h43; plaintext[0][2] = 8'h75; plaintext[0][3] = 8'h74;
        plaintext[0][4] = 8'h74; plaintext[0][5] = 8'h65; plaintext[0][6] = 8'h72; plaintext[0][7] = 8'h3b;
        
        plaintext[1][0] = 8'h11; plaintext[1][1] = 8'h22; plaintext[1][2] = 8'h33; plaintext[1][3] = 8'h44;
        plaintext[1][4] = 8'h55; plaintext[1][5] = 8'h66; plaintext[1][6] = 8'h77; plaintext[1][7] = 8'h88;
        
        plaintext[2][0] = 8'haa; plaintext[2][1] = 8'hbb; plaintext[2][2] = 8'hcc; plaintext[2][3] = 8'hdd;
        plaintext[2][4] = 8'hee; plaintext[2][5] = 8'hff; plaintext[2][6] = 8'h00; plaintext[2][7] = 8'h11;
        
        plaintext[3][0] = 8'hde; plaintext[3][1] = 8'had; plaintext[3][2] = 8'hbe; plaintext[3][3] = 8'hef;
        plaintext[3][4] = 8'hca; plaintext[3][5] = 8'hfe; plaintext[3][6] = 8'hba; plaintext[3][7] = 8'hbe;
        
        plaintext[4][0] = 8'h01; plaintext[4][1] = 8'h23; plaintext[4][2] = 8'h45; plaintext[4][3] = 8'h67;
        plaintext[4][4] = 8'h89; plaintext[4][5] = 8'hab; plaintext[4][6] = 8'hcd; plaintext[4][7] = 8'hef;
        
        plaintext[5][0] = 8'hfe; plaintext[5][1] = 8'hdc; plaintext[5][2] = 8'hba; plaintext[5][3] = 8'h98;
        plaintext[5][4] = 8'h76; plaintext[5][5] = 8'h54; plaintext[5][6] = 8'h32; plaintext[5][7] = 8'h10;
        
        plaintext[6][0] = 8'h00; plaintext[6][1] = 8'h00; plaintext[6][2] = 8'h00; plaintext[6][3] = 8'h00;
        plaintext[6][4] = 8'h00; plaintext[6][5] = 8'h00; plaintext[6][6] = 8'h00; plaintext[6][7] = 8'h00;
        
        plaintext[7][0] = 8'hff; plaintext[7][1] = 8'hff; plaintext[7][2] = 8'hff; plaintext[7][3] = 8'hff;
        plaintext[7][4] = 8'hff; plaintext[7][5] = 8'hff; plaintext[7][6] = 8'hff; plaintext[7][7] = 8'hff;
        
        plaintext[8][0] = 8'ha5; plaintext[8][1] = 8'h5a; plaintext[8][2] = 8'ha5; plaintext[8][3] = 8'h5a;
        plaintext[8][4] = 8'h5a; plaintext[8][5] = 8'ha5; plaintext[8][6] = 8'h5a; plaintext[8][7] = 8'ha5;
        
        plaintext[9][0] = 8'h12; plaintext[9][1] = 8'h34; plaintext[9][2] = 8'h56; plaintext[9][3] = 8'h78;
        plaintext[9][4] = 8'h9a; plaintext[9][5] = 8'hbc; plaintext[9][6] = 8'hde; plaintext[9][7] = 8'hf0;
        
        // Release reset
        #(CLK_PERIOD * 10);
        rst = 0;
        #(CLK_PERIOD * 10);
        
        // ================================================================
        // STEP 1: Load Key
        // ================================================================
        $display("[%0t] STEP 1: Loading Key...", $time);
        send_uart_byte(8'h4B);  // 'K'
        for (i = 0; i < 16; i = i + 1) begin
            send_uart_byte(test_key[i]);
        end
        wait(led[0] == 0);  // Wait for busy to clear
        #(BIT_TIME * 50);   // Large delay after key load
        $display("[%0t] Key loaded successfully", $time);
        $display("");
        
        // ================================================================
        // STEP 2: Encrypt 10 blocks
        // ================================================================
        $display("[%0t] STEP 2: Encrypting %0d blocks...", $time, NUM_BLOCKS);
        for (block_num = 0; block_num < NUM_BLOCKS; block_num = block_num + 1) begin
            // Wait for controller to be fully ready
            $display("  [%0t] === BLOCK %0d ENCRYPTION START ===", $time, block_num);
            $display("  [%0t] Waiting for busy=0 (currently=%0b)...", $time, led[0]);
            wait(led[0] == 0);  // Ensure busy is clear before starting
            $display("  [%0t] busy=0, adding delay...", $time);
            #(BIT_TIME * 50);   // Large delay to ensure UART RX is ready
            
            $display("  [%0t] Encrypting block %0d", $time, block_num);
            
            // Display plaintext
            $write("  [%0t] PT to send: ", $time);
            for (j = 0; j < 8; j = j + 1) $write("%02h ", plaintext[block_num][j]);
            $write("\n");
            
            // Send 'E' + 8 bytes
            $display("  [%0t] Sending 'E' command...", $time);
            send_uart_byte(8'h45);  // 'E'
            $display("  [%0t] Sending 8 plaintext bytes...", $time);
            for (j = 0; j < 8; j = j + 1) begin
                send_uart_byte(plaintext[block_num][j]);
            end
            $display("  [%0t] All plaintext sent, waiting for ciphertext...", $time);
            
            // Capture 8 ciphertext bytes
            for (j = 0; j < 8; j = j + 1) begin
                capture_tx_byte(temp_byte);
                ciphertext[block_num][j] = temp_byte;
            end
            
            // Display captured ciphertext
            $write("  [%0t] CT captured: ", $time);
            for (j = 0; j < 8; j = j + 1) $write("%02h ", ciphertext[block_num][j]);
            $write("\n");
            $display("  [%0t] === BLOCK %0d ENCRYPTION COMPLETE ===\n", $time, block_num);
        end
        $display("[%0t] All blocks encrypted", $time);
        $display("");
        
        // ================================================================
        // STEP 3: Decrypt 10 blocks
        // ================================================================
        $display("[%0t] STEP 3: Decrypting %0d blocks...", $time, NUM_BLOCKS);
        for (block_num = 0; block_num < NUM_BLOCKS; block_num = block_num + 1) begin
            // Wait for controller to be fully ready
            $display("  [%0t] === BLOCK %0d DECRYPTION START ===", $time, block_num);
            $display("  [%0t] Waiting for busy=0 (currently=%0b)...", $time, led[0]);
            wait(led[0] == 0);  // Ensure busy is clear before starting
            $display("  [%0t] busy=0, adding delay...", $time);
            #(BIT_TIME * 50);   // Large delay to ensure UART RX is ready
            
            $display("  [%0t] Decrypting block %0d", $time, block_num);
            
            // Display ciphertext to decrypt
            $write("  [%0t] CT to send: ", $time);
            for (j = 0; j < 8; j = j + 1) $write("%02h ", ciphertext[block_num][j]);
            $write("\n");
            
            // Send 'D' + 8 bytes (ciphertext)
            $display("  [%0t] Sending 'D' command...", $time);
            send_uart_byte(8'h44);  // 'D'
            $display("  [%0t] Sending 8 ciphertext bytes...", $time);
            for (j = 0; j < 8; j = j + 1) begin
                send_uart_byte(ciphertext[block_num][j]);
            end
            $display("  [%0t] All ciphertext sent, waiting for plaintext...", $time);
            
            // Capture 8 decrypted bytes
            for (j = 0; j < 8; j = j + 1) begin
                capture_tx_byte(temp_byte);
                decrypted[block_num][j] = temp_byte;
            end
            
            // Display captured plaintext
            $write("  [%0t] DEC captured: ", $time);
            for (j = 0; j < 8; j = j + 1) $write("%02h ", decrypted[block_num][j]);
            $write("\n");
            $display("  [%0t] === BLOCK %0d DECRYPTION COMPLETE ===\n", $time, block_num);
        end
        $display("[%0t] All blocks decrypted", $time);
        $display("");
        
        // ================================================================
        // STEP 4: Compare and Display Results
        // ================================================================
        $display("========================================================");
        $display("VERIFICATION RESULTS:");
        $display("========================================================");
        $display("");
        
        for (block_num = 0; block_num < NUM_BLOCKS; block_num = block_num + 1) begin
            $display("Block %0d:", block_num);
            
            // Display plaintext
            $write("  PT:  ");
            for (j = 0; j < 8; j = j + 1) $write("%02h ", plaintext[block_num][j]);
            $write("\n");
            
            // Display ciphertext
            $write("  CT:  ");
            for (j = 0; j < 8; j = j + 1) $write("%02h ", ciphertext[block_num][j]);
            $write("\n");
            
            // Display decrypted
            $write("  DEC: ");
            for (j = 0; j < 8; j = j + 1) $write("%02h ", decrypted[block_num][j]);
            $write("\n");
            
            // Compare
            $write("  MATCH: ");
            for (j = 0; j < 8; j = j + 1) begin
                if (plaintext[block_num][j] !== decrypted[block_num][j]) begin
                    $write("FAIL[%0d] ", j);
                    errors = errors + 1;
                end else begin
                    $write("OK[%0d] ", j);
                end
            end
            $write("\n");
            
            if (plaintext[block_num][0] == decrypted[block_num][0] &&
                plaintext[block_num][1] == decrypted[block_num][1] &&
                plaintext[block_num][2] == decrypted[block_num][2] &&
                plaintext[block_num][3] == decrypted[block_num][3] &&
                plaintext[block_num][4] == decrypted[block_num][4] &&
                plaintext[block_num][5] == decrypted[block_num][5] &&
                plaintext[block_num][6] == decrypted[block_num][6] &&
                plaintext[block_num][7] == decrypted[block_num][7]) begin
                $display("  RESULT: *** PASS ***");
            end else begin
                $display("  RESULT: *** FAIL ***");
            end
            $display("");
        end
        
        $display("========================================================");
        $display("SUMMARY:");
        $display("  Total Blocks Tested: %0d", NUM_BLOCKS);
        $display("  Byte Errors: %0d", errors);
        if (errors == 0) begin
            $display("  OVERALL: *** ALL TESTS PASSED ***");
        end else begin
            $display("  OVERALL: *** SOME TESTS FAILED ***");
        end
        $display("========================================================");
        
        #1000;
        $stop;
    end
    
    // Timeout watchdog
    initial begin
        #(BIT_TIME * 50000);  // Very generous timeout
        $display("\n*** TIMEOUT - Test took too long ***");
        $stop;
    end

endmodule

