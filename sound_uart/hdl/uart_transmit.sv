module uart_transmit #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 230400
) (
    input wire clk,
    input wire rst,
    input wire [7:0] din,
    input wire trigger,
    output logic busy,
    output logic dout
);

    localparam logic [31:0] ACCUM_INC = (BAUD_RATE * 64'h1_0000_0000) / INPUT_CLOCK_FREQ;

    typedef enum logic [2:0] { 
        IDLE_ST,
        START_ST,
        TRANSMIT_ST,
        STOP_ST
    } state_t;

    state_t state; 

    logic [32:0] count;
    logic last_flag;
    logic send_bit;
    logic [7:0] d_in;
    logic [2:0] bit_cnt;

    assign busy = (state == IDLE_ST)? 1'b0 : 1'b1;

    always_ff @(posedge clk) begin : counter 
        if (rst) begin 
            count       <= '0;
            send_bit    <= 1'b0;
            last_flag   <= 1'b0;
        end else begin 
            if (state == IDLE_ST) begin 
                count       <= '0;
            end else begin
                count       <= count + ACCUM_INC;
                send_bit    <= 1'b0; 
                last_flag   <= count[32] == 1'b1;

                if (~last_flag == count[32]) begin 
                    send_bit <= 1'b1;
                end 
            end
        end 
    end : counter 

    always_ff @(posedge clk) begin : fsm
        if (rst) begin 
            dout    <= 1'b1;
            state   <= IDLE_ST;
            bit_cnt <= '0;
        end else begin 
            case (state)
                IDLE_ST : begin
                    bit_cnt     <= '0;
                    dout        <= 1'b1;

                    if (trigger) begin 
                        state   <= START_ST;
                        d_in    <= din;
                        dout    <= 1'b0;
                    end 
                end 

                START_ST : begin
                    if (send_bit == 1'b1) begin 
                        state <= TRANSMIT_ST;
                    end 
                end 

                TRANSMIT_ST : begin 
                    dout <= d_in[0];

                    if (send_bit == 1'b1) begin 
                        d_in    <= {1'b1, d_in[7:1]};
                        bit_cnt <= bit_cnt + 1;

                        if (bit_cnt == 8'd7) begin 
                            state   <= STOP_ST;
                            dout    <= 1'b1;
                        end 
                    end 
                end 

                STOP_ST : begin
                    if (send_bit == 1'b1) begin 
                        state <= IDLE_ST;
                    end 
                end 
            endcase 
        end 
    end : fsm

endmodule 