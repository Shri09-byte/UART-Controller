`timescale 1ns / 1ps

module tb_uart_loopback();

    parameter CLK_FREQ  = 100_000_000;
    parameter BAUD_RATE = 115_200;

    logic clk, rst_n;
    
    // TX Signals
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_pin;
    logic       tx_busy;

    // RX Signals
    logic [7:0] rx_data;
    logic       rx_done;
    
    // The Loopback Connection
    logic loopback_wire;
    assign loopback_wire = tx_pin;

    // Instantiate Transmitter
    uart_tx #(CLK_FREQ, BAUD_RATE) transmitter (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx_pin(tx_pin), .tx_busy(tx_busy)
    );

    // Instantiate Receiver
    uart_rx #(CLK_FREQ, BAUD_RATE) receiver (
        .clk(clk), .rst_n(rst_n),
        .rx_pin(loopback_wire),
        .rx_data(rx_data), .rx_done(rx_done)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Task to send and verify
 task send_and_check(input [7:0] data_to_send);
    wait(tx_busy == 0);
    #100;
    @(posedge clk);
    tx_data  <= data_to_send;
    tx_start <= 1'b1;
    
    @(posedge clk);
    tx_start <= 1'b0;
    
    $display("[TX] Command sent for: 0x%h", data_to_send);

    wait(rx_done == 1);
    
    @(posedge clk); 
    
    if (rx_data == data_to_send)
        $display("[SUCCESS] Received: 0x%h", rx_data);
    else
        $display("[ERROR] Got 0x%h, Expected 0x%h", rx_data, data_to_send);

    #10000; // wait before next call
endtask

    initial begin
        clk = 0; rst_n = 0; tx_start = 0; tx_data = 0;
        #200 rst_n = 1;
        #1000;

        send_and_check(8'hAB);
        #50000;
        send_and_check(8'h55);
        #50000;
        send_and_check(8'hFF);
        #50000;

        $display("Loopback Test Finished.");
        $finish;
    end

endmodule