`timescale 1ns / 1ps

module uart_tx#(parameter CLK_FREQ = 100_000_000,parameter BAUD_RATE = 115_200)//100Mhz clock 
               (input logic clk,
               input logic rst_n,
               input logic[7:0]tx_data,
               input logic tx_start,
               output logic tx_pin,
               output logic tx_busy);
          
localparam CLKS_PER_BIT = CLK_FREQ/ BAUD_RATE;//cycles per bit = 100MHz/115200 = ~868
               
typedef enum logic [1:0]{IDLE,START,DATA,STOP}state_t;
state_t state;

logic [15:0]baud_cnt;// 16 bit to count till 868
logic baud_tick; //pulse generated every bit period

logic [7:0] bit_idx; // to track which bit is currently sending
logic [7:0] tx_data_buf;//internal buffer

//baud rate generator
always_ff@(posedge clk)begin
    if(!rst_n)begin
        baud_cnt<= 0;
        baud_tick<= 0;
    end else if(tx_busy)begin
        if(baud_cnt == CLKS_PER_BIT -1 )begin
        baud_cnt<= 0;//reset the counter
        baud_tick<= 1;//pulse for one clock cycle
        end else begin
        baud_cnt<= baud_cnt + 1;
        baud_tick <=0;
        end 
    end else begin
    baud_cnt<=0;
    baud_tick<= 0;
    end
end

//FSM
always_ff @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            tx_pin      <= 1; // Idle state for UART is HIGH
            tx_busy     <= 0;
            bit_idx     <= 0;
            tx_data_buf <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin  <= 1;
                    tx_busy <= 0;
                    bit_idx <= 0;
                    if (tx_start) begin
                        tx_data_buf <= tx_data;
                        tx_busy     <= 1;
                        state       <= START;
                    end
                end

                START: begin
                    tx_pin <= 0; // Drive Start Bit (LOW)
                    if (baud_tick) begin
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx_pin <= tx_data_buf[bit_idx]; // Send LSB first
                    if (baud_tick) begin
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end
                end

                STOP: begin
                    tx_pin <= 1; // Drive Stop Bit (HIGH)
                    if (baud_tick) begin
                        state   <= IDLE;
                        tx_busy <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule