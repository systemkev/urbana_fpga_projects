`timescale 1ns / 1ps
`default_nettype none

module uart_receive
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 230400
    )
   (
        input wire 	       clk,
        input wire 	       rst,
        input wire 	       din,
        output logic       dout_valid,
        output logic [7:0] dout
    );

    typedef enum {
        IDLE,
        START,
        DATA,
        STOP,
        TRANSMIT
    } uart_state;

    localparam logic [31:0] ACCUM_INC = (BAUD_RATE * 64'h1_0000_0000) / INPUT_CLOCK_FREQ;

    // note: for the online checker, don't rename this variable
    uart_state state;

    logic [31:0] accum; 
    logic [31:0] last_accum;

    logic [2:0] bit_cnt;

    always_ff @(posedge clk) begin : counter
        if (rst) begin
            accum           <= '0;
        end else begin
            if (state != IDLE) begin 
                accum       <= accum + ACCUM_INC;
                last_accum  <= accum;
            end else begin 
                accum       <= '0;
                last_accum  <= '0;
            end 
        end
    end : counter

    always_ff @(posedge clk) begin : fsm
        if (rst) begin
            state       <= IDLE;
            bit_cnt     <= '0;
            dout_valid  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    bit_cnt   <= '0;
                    if (!din) begin 
                        state <= START;
                    end 
                end

                START: begin
                    // wait for the middle of the start bit
                    if (accum[31] && !last_accum[31]) begin 
                        if (!din) begin 
                            state <= DATA;
                        end else begin 
                            state <= IDLE;
                        end 
                    end 
                end

                DATA: begin
                    // wait for the middle of each data bit
                    if (accum[31] && !last_accum[31]) begin 
                        
                        // shift in the new bit
                        dout <= {din, dout[7:1]};
                        
                        // if this was the 8th bit (index 7), we are done with DATA
                        if (bit_cnt == 4'd7) begin 
                            state   <= STOP;
                        end else begin 
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                STOP: begin
                    // wait for the stop bit
                    if (accum[31] && !last_accum[31]) begin 
                        if (din) begin 
                            state       <= TRANSMIT;
                            dout_valid  <= 1'b1;
                        end else begin 
                            state <= IDLE;
                        end 
                    end 
                end

                TRANSMIT: begin
                    state      <= IDLE;
                    dout_valid <= 1'b0;
                end
            endcase
        end
    end : fsm

endmodule // uart_receive

`default_nettype wire