`timescale 1ns/1ps

module tb_controller_simple;

    parameter W = 32;
    parameter ROUNDS = 27;
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter BIT_TIME = 8680;  // 115200 baud at 100 MHz
    
    // Clock and reset
    reg clk = 0;
    reg rst = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // UART signals
    reg  [7:0] rx_data;
    reg        rx_valid;
    wire [7:0] tx_data;
    wire       tx_valid;
    reg        tx_busy;
    
    // Mock crypto signals
    wire [W-1:0] ks_K0, ks_K1, ks_K2, ks_K3;
    wire ks_start;
    reg  ks_done = 0;
    reg  [W*ROUNDS-1:0] rk_flat = 0;
    wire [W*ROUNDS-1:0] rk_flat_out;
    
    wire [W-1:0] enc_pt_x, enc_pt_y;
    wire enc_start;
    reg  [W-1:0] enc_ct_x = 0, enc_ct_y = 0;
    reg  enc_done = 0;
    
    wire [W-1:0] dec_ct_x, dec_ct_y;
    wire dec_start;
    reg  [W-1:0] dec_pt_x = 0, dec_pt_y = 0;
    reg  dec_done = 0;
    
    wire [3:0] state_out;
    wire busy;
    
    // DUT
    speck_uart_controller #(
        .W(W), .ROUNDS(ROUNDS)
    ) dut (
        .clk(clk), .rst(rst),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_busy(tx_busy),
        .ks_K0(ks_K0), .ks_K1(ks_K1), .ks_K2(ks_K2), .ks_K3(ks_K3),
        .ks_start(ks_start), .ks_done(ks_done), .rk_flat(rk_flat), .rk_flat_out(rk_flat_out),
        .enc_pt_x(enc_pt_x), .enc_pt_y(enc_pt_y), .enc_start(enc_start),
        .enc_ct_x(enc_ct_x), .enc_ct_y(enc_ct_y), .enc_done(enc_done),
        .dec_ct_x(dec_ct_x), .dec_ct_y(dec_ct_y), .dec_start(dec_start),
        .dec_pt_x(dec_pt_x), .dec_pt_y(dec_pt_y), .dec_done(dec_done),
        .state_out(state_out), .busy(busy)
    );
    
    // Task: Send byte to controller
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            rx_data = data;
            rx_valid = 1;
            @(posedge clk);
            rx_valid = 0;
        end
    endtask
    
    // Mock: Key schedule (50 cycles)
    integer ks_count = 0;
    always @(posedge clk) begin
        if (rst) begin
            ks_done <= 0;
            ks_count <= 0;
        end else if (ks_start) begin
            ks_count <= 50;
            $display("[%0t] Mock KS: Start", $time);
        end else if (ks_count > 0) begin
            ks_count <= ks_count - 1;
            if (ks_count == 1) begin
                ks_done <= 1;
                rk_flat <= {ROUNDS*W{1'b1}};
                $display("[%0t] Mock KS: Done", $time);
            end
        end else begin
            ks_done <= 0;
        end
    end
    
    // Mock: Encryptor (30 cycles)
    integer enc_count = 0;
    always @(posedge clk) begin
        if (rst) begin
            enc_done <= 0;
            enc_count <= 0;
        end else if (enc_start) begin
            enc_count <= 30;
            $display("[%0t] Mock ENC: PT x=%h y=%h", $time, enc_pt_x, enc_pt_y);
        end else if (enc_count > 0) begin
            enc_count <= enc_count - 1;
            if (enc_count == 1) begin
                enc_done <= 1;
                enc_ct_x <= ~enc_pt_x;  // Simple "encryption"
                enc_ct_y <= ~enc_pt_y;
                $display("[%0t] Mock ENC: CT x=%h y=%h", $time, ~enc_pt_x, ~enc_pt_y);
            end
        end else begin
            enc_done <= 0;
        end
    end
    
    // Mock: Decryptor (30 cycles)
    integer dec_count = 0;
    always @(posedge clk) begin
        if (rst) begin
            dec_done <= 0;
            dec_count <= 0;
        end else if (dec_start) begin
            dec_count <= 30;
            $display("[%0t] Mock DEC: CT x=%h y=%h", $time, dec_ct_x, dec_ct_y);
        end else if (dec_count > 0) begin
            dec_count <= dec_count - 1;
            if (dec_count == 1) begin
                dec_done <= 1;
                dec_pt_x <= ~dec_ct_x;  // Simple "decryption"
                dec_pt_y <= ~dec_ct_y;
                $display("[%0t] Mock DEC: PT x=%h y=%h", $time, ~dec_ct_x, ~dec_ct_y);
            end
        end else begin
            dec_done <= 0;
        end
    end
    
    // Mock: TX busy (1 cycle)
    always @(posedge clk) begin
        tx_busy <= tx_valid;
    end
    
    // Capture TX bytes
    integer tx_count = 0;
    always @(posedge clk) begin
        if (tx_valid && !tx_busy) begin
            $display("[%0t] TX byte[%0d] = %h", $time, tx_count, tx_data);
            tx_count <= tx_count + 1;
        end
    end
    
    // Display FSM state changes
    reg [3:0] prev_state = 0;
    always @(posedge clk) begin
        if (state_out != prev_state) begin
            case (state_out)
                0: $display("[%0t] FSM: IDLE", $time);
                1: $display("[%0t] FSM: RX_COMMAND", $time);
                2: $display("[%0t] FSM: RX_BYTES", $time);
                3: $display("[%0t] FSM: KEY_SCHEDULE", $time);
                4: $display("[%0t] FSM: WAIT_KEY", $time);
                5: $display("[%0t] FSM: CRYPTO", $time);
                6: $display("[%0t] FSM: WAIT_CRYPTO", $time);
                7: $display("[%0t] FSM: TX_BYTES", $time);
                8: $display("[%0t] FSM: WAIT_TX", $time);
                9: $display("[%0t] FSM: DONE_STATE", $time);
                default: $display("[%0t] FSM: UNKNOWN (%0d)", $time, state_out);
            endcase
            prev_state <= state_out;
        end
    end
    
    // Main test
    integer i;
    initial begin
        $display("=== Simple Controller Test ===");
        
        rst = 1;
        rx_valid = 0;
        #100;
        rst = 0;
        #100;
        
        // Test 1: Load Key
        $display("\n[%0t] TEST 1: Load Key", $time);
        send_byte(8'h4B);  // 'K'
        send_byte(8'h00); send_byte(8'h01); send_byte(8'h02); send_byte(8'h03);
        send_byte(8'h08); send_byte(8'h09); send_byte(8'h0a); send_byte(8'h0b);
        send_byte(8'h10); send_byte(8'h11); send_byte(8'h12); send_byte(8'h13);
        send_byte(8'h18); send_byte(8'h19); send_byte(8'h1a); send_byte(8'h1b);
        wait(busy == 0);
        #100;
        
        // Test 2: Encrypt
        $display("\n[%0t] TEST 2: Encrypt", $time);
        send_byte(8'h45);  // 'E'
        send_byte(8'h2d); send_byte(8'h43); send_byte(8'h75); send_byte(8'h74);
        send_byte(8'h74); send_byte(8'h65); send_byte(8'h72); send_byte(8'h3b);
        wait(busy == 0);
        #100;
        
        // Test 3: Decrypt
        $display("\n[%0t] TEST 3: Decrypt", $time);
        send_byte(8'h44);  // 'D'
        send_byte(8'h8b); send_byte(8'h02); send_byte(8'h4e); send_byte(8'h45);
        send_byte(8'h48); send_byte(8'ha5); send_byte(8'h6f); send_byte(8'h8c);
        wait(busy == 0);
        #100;
        
        $display("\n=== TEST COMPLETE ===");
        $display("Total TX bytes: %0d (should be 16)", tx_count);
        
        #1000;
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("\n*** TIMEOUT ***");
        $finish;
    end

endmodule

