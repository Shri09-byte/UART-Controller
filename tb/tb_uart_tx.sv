`timescale 1ns / 1ps

module tb_uart_tx();

    parameter CLK_FREQ  = 100_000_000;
    parameter BAUD_RATE = 115_200;
    
    logic clk, rst_n;
    logic [7:0] tx_data;
    logic tx_start;
    logic tx_pin;
    logic tx_busy;

    uart_tx #(CLK_FREQ, BAUD_RATE) uut (.*);

    always #5 clk = ~clk;

    // Task to send byte
    task send_byte(input [7:0] data);
        @(posedge clk);
        while(tx_busy) @(posedge clk); // Wait if busy
        tx_data  <= data;
        tx_start <= 1;
        @(posedge clk);
        tx_start <= 0;
        $display("[TIME: %0t] Sending Byte: 0x%h", $time, data);
        
        // Wait for the transmission to complete
        wait(tx_busy == 1);
        wait(tx_busy == 0);
        $display("[TIME: %0t] Transmission Finished.", $time);
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        tx_data = 0;
        tx_start = 0;

        #20 rst_n = 1;
        #50;

        // Test 1: Send 'A' (8'h41 -> 0100 0001)
        // Expected Serial: Start(0) -> 1,0,0,0,0,1,0,0 (LSB first) -> Stop(1)
        send_byte(8'h41);
        #10000; // Small gap between frames

        // Test 2: Send '5' (8'h35 -> 0011 0101)
        send_byte(8'h35);
        
        #100000; 
        $display("Simulation Complete.");
        $finish;
    end

endmodule