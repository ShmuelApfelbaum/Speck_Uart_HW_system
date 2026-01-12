// tb_uart_top_final.v
// Final production testbench for SPECK UART Top Module
// Tests 10-block encryption/decryption with round-trip verification

`timescale 1ns / 1ps

module tb_uart_top_final;

    // Clock and reset
    reg clk;
    reg rst;
    
    // UART interface
    reg  rx;
    wire tx;
    wire [15:0] led;  // Status LEDs (not used in testbench)
    
    // Instantiate DUT
    speck_uart_top_v3 dut (
        .clk(clk),
        .rst(rst),
        .uart_rxd(rx),
        .uart_txd(tx),
        .led(led)
    );
    
    // UART parameters (115200 baud @ 100 MHz)
    localparam BIT_TIME = 8680;  // ns per bit
    
    // Test data storage
    reg [7:0] plaintext [0:9][0:7];    // 10 blocks of 8 bytes each
    reg [7:0] ciphertext [0:9][0:7];   // Captured ciphertexts
    reg [7:0] decrypted [0:9][0:7];    // Captured decrypted texts
    
    integer i, j, errors;
    
    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // UART byte transmission task
    task send_uart_byte;
        input [7:0] data;
        integer bit_idx;
        begin
            rx = 0;  // Start bit
            #BIT_TIME;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                rx = data[bit_idx];
                #BIT_TIME;
            end
            rx = 1;  // Stop bit
            #BIT_TIME;
        end
    endtask
    
    // UART byte reception task
    task receive_uart_byte;
        output [7:0] data;
        integer bit_idx;
        begin
            // Wait for start bit
            wait(tx == 0);
            #(BIT_TIME / 2);  // Sample in middle of bit
            #BIT_TIME;        // Skip start bit
            
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                data[bit_idx] = tx;
                #BIT_TIME;
            end
            // Stop bit already passed
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================================");
        $display("SPECK64/128 UART - 10-Block Round-Trip Verification");
        $display("========================================================\n");
        
        // Initialize test vectors
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
        
        // Reset
        rx = 1;
        rst = 1;
        #100;
        rst = 0;
        #100;
        
        // ========================================
        // STEP 1: Load Key
        // ========================================
        $display("STEP 1: Loading 128-bit key...");
        send_uart_byte(8'h4B);  // 'K' command
        send_uart_byte(8'h00); send_uart_byte(8'h01); send_uart_byte(8'h02); send_uart_byte(8'h03);
        send_uart_byte(8'h08); send_uart_byte(8'h09); send_uart_byte(8'h0a); send_uart_byte(8'h0b);
        send_uart_byte(8'h10); send_uart_byte(8'h11); send_uart_byte(8'h12); send_uart_byte(8'h13);
        send_uart_byte(8'h18); send_uart_byte(8'h19); send_uart_byte(8'h1a); send_uart_byte(8'h1b);
        #500000;  // Wait for key schedule
        $display("Key loaded and round keys generated\n");
        
        // ========================================
        // STEP 2: Encrypt 10 Blocks
        // ========================================
        $display("STEP 2: Encrypting 10 blocks...");
        for (i = 0; i < 10; i = i + 1) begin
            wait(dut.u_controller.busy == 0);
            #50000;
            
            send_uart_byte(8'h45);  // 'E' command
            for (j = 0; j < 8; j = j + 1) begin
                send_uart_byte(plaintext[i][j]);
            end
            
            for (j = 0; j < 8; j = j + 1) begin
                receive_uart_byte(ciphertext[i][j]);
            end
            $display("  Block %0d encrypted", i);
        end
        $display("All blocks encrypted\n");
        
        // ========================================
        // STEP 3: Decrypt 10 Blocks
        // ========================================
        $display("STEP 3: Decrypting 10 blocks...");
        for (i = 0; i < 10; i = i + 1) begin
            wait(dut.u_controller.busy == 0);
            #50000;
            
            send_uart_byte(8'h44);  // 'D' command
            for (j = 0; j < 8; j = j + 1) begin
                send_uart_byte(ciphertext[i][j]);
            end
            
            for (j = 0; j < 8; j = j + 1) begin
                receive_uart_byte(decrypted[i][j]);
            end
            $display("  Block %0d decrypted", i);
        end
        $display("All blocks decrypted\n");
        
        // ========================================
        // VERIFICATION
        // ========================================
        $display("========================================================");
        $display("VERIFICATION RESULTS");
        $display("========================================================\n");
        
        errors = 0;
        for (i = 0; i < 10; i = i + 1) begin
            $display("Block %0d:", i);
            $write("  PT:  ");
            for (j = 0; j < 8; j = j + 1) $write("%h ", plaintext[i][j]);
            $write("\n");
            
            $write("  CT:  ");
            for (j = 0; j < 8; j = j + 1) $write("%h ", ciphertext[i][j]);
            $write("\n");
            
            $write("  DEC: ");
            for (j = 0; j < 8; j = j + 1) $write("%h ", decrypted[i][j]);
            $write("\n");
            
            $write("  Result: ");
            for (j = 0; j < 8; j = j + 1) begin
                if (plaintext[i][j] !== decrypted[i][j]) begin
                    errors = errors + 1;
                end
            end
            
            if (plaintext[i][0] == decrypted[i][0] && 
                plaintext[i][1] == decrypted[i][1] && 
                plaintext[i][2] == decrypted[i][2] && 
                plaintext[i][3] == decrypted[i][3] && 
                plaintext[i][4] == decrypted[i][4] && 
                plaintext[i][5] == decrypted[i][5] && 
                plaintext[i][6] == decrypted[i][6] && 
                plaintext[i][7] == decrypted[i][7]) begin
                $display("PASS");
            end else begin
                $display("FAIL");
            end
            $display("");
        end
        
        $display("========================================================");
        $display("SUMMARY");
        $display("========================================================");
        $display("Total Blocks: 10");
        $display("Byte Errors:  %0d", errors);
        if (errors == 0) begin
            $display("Result:       *** ALL TESTS PASSED ***");
        end else begin
            $display("Result:       *** %0d ERRORS DETECTED ***", errors);
        end
        $display("========================================================\n");
        
        $stop;
    end

endmodule

