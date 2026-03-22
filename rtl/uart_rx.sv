`timescale 1ns / 1ps


module uart_rx#(parameter CLK_FREQ = 100_000_000,
                parameter BAUD_RATE = 115_200)(
               input logic clk,rst_n,rx_pin,
               output logic [7:0]rx_data,
               output logic rx_done
               );
      
localparam CLK_PER_BIT = CLK_FREQ/(BAUD_RATE*16);


typedef enum logic [2:0]{IDLE,START,DATA,STOP,DONE}state_t;
state_t state;

logic [15:0]baud_cnt;
logic baud_tick;
logic [3:0]tick_cnt;
logic [2:0]bit_idx;
logic [7:0] rx_shifter;

//synchroniser
logic rx_sync_1,rx_sync_2;
always@(posedge clk)begin
rx_sync_1 <= rx_pin;
rx_sync_2 <= rx_sync_1;
end

//16x baud generator

always_ff@(posedge clk)begin
if(!rst_n)begin
baud_cnt<=0;
baud_tick<=0;
end else begin
if(baud_cnt == CLK_PER_BIT-1)begin
    baud_cnt<=0;
    baud_tick<=1;
end else begin
    baud_cnt<= baud_cnt+1;
    baud_tick<=0;
    end
end
end

//FSM
always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            rx_done  <= 0;
            rx_data  <= 0;
            tick_cnt <= 0;
            bit_idx  <= 0;
        end else begin
            rx_done <= 0; // Default state for the pulse
            
            case (state)
                IDLE: begin
                    tick_cnt <= 0;
                    bit_idx  <= 0;
                    if (rx_sync_2 == 0) begin // Detect falling edge of Start Bit
                        state <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        if (tick_cnt == 7) begin 
                            if (rx_sync_2 == 0) begin
                                tick_cnt <= 0;
                                state    <= DATA;
                            end else begin
                                state    <= IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin 
                            tick_cnt <= 0;
                            rx_shifter[bit_idx] <= rx_sync_2; 
                            if (bit_idx == 7) begin
                                state <= STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin 
                            state   <= DONE;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                DONE: begin
                    rx_done <= 1;
                    rx_data <= rx_shifter;
                    state   <= IDLE;
                end
            endcase
        end
    end
endmodule
