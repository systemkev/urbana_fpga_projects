module spi_con #(
    parameter DATA_WIDTH = 8,
    parameter DATA_CLK_PERIOD = 100
)(  
    input wire   clk, //system clock (100 MHz)
    input wire   rst, //reset in signal
    input wire   [DATA_WIDTH-1:0] data_in, //data to send
    input wire   trigger, //start a transaction
    output logic [DATA_WIDTH-1:0] data_out, //data received!
    output logic data_valid, //high when output data is present.
 
    output logic copi, //(Controller-Out-Peripheral-In)
    input wire   cipo, //(Controller-In-Peripheral-Out)
    output logic dclk, //(Data Clock)
    output logic cs // (Chip Select)
);

    localparam ACTUAL_CLK_PERIOD = DATA_CLK_PERIOD & ~1;

    typedef enum logic [2:0] {
        IDLE_ST,
        TRANSFER_ST,
        DONE_ST
    } fsm_state_t;

    fsm_state_t state;

    logic [DATA_WIDTH-1:0] shft_reg_in;
    logic [DATA_WIDTH-1:0] shft_reg_out; 

    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt;
    logic [$clog2(ACTUAL_CLK_PERIOD)-1:0] clock_cnt;

    logic rising_edge;
    logic falling_edge;

    always_ff @(posedge clk) begin : clock_gen
        if (rst || cs) begin
            clock_cnt       <= ACTUAL_CLK_PERIOD/2;
            dclk            <= 1'b0;
        end else if (!cs) begin
            rising_edge     <= 1'b0;
            falling_edge    <= 1'b0;
            if (clock_cnt == ACTUAL_CLK_PERIOD - 1) begin 
                clock_cnt   <= '0;
                dclk        <= 1'b1;
                rising_edge <= 1'b1;
            end else begin
                clock_cnt   <= clock_cnt + 1;

                if (clock_cnt == ACTUAL_CLK_PERIOD/2 - 1) begin 
                    dclk         <= 1'b0;
                    falling_edge <= 1'b1;
                end
            end 
        end else begin 
            rising_edge     <= 1'b0;
            falling_edge    <= 1'b0;
        end 
    end : clock_gen

    always_ff @(posedge clk) begin : fsm
        if (rst) begin 
            cs          <= 1'b1;
            state       <= IDLE_ST;
            bit_cnt     <= '0;
            data_valid  <= 1'b0;
            data_out    <= '0;
            copi        <= 1'b0;
        end else begin
            case (state)
                IDLE_ST : begin
                    cs          <= 1'b1;
                    data_valid  <= 1'b0;
                    if (trigger) begin 
                        state   <= TRANSFER_ST;
                        bit_cnt <= '0;
                        copi    <= data_in[DATA_WIDTH - 1];
                        cs      <= 1'b0;
                        shft_reg_out <= data_in;
                    end 
                end 

                TRANSFER_ST : begin
                    if (rising_edge) begin 
                        shft_reg_in     <= {shft_reg_in[DATA_WIDTH-2:0], cipo}; // shift in cipo and chop off MSB
                    end else if (falling_edge) begin 
                        shft_reg_out    <= {shft_reg_out[DATA_WIDTH-2:0], 1'b0};
                        bit_cnt         <= bit_cnt + 1;
                        copi            <= shft_reg_out[DATA_WIDTH-2];

                        // transaction done!
                        if (bit_cnt == DATA_WIDTH - 1) begin 
                            state       <= DONE_ST;
                            cs          <= 1'b1;
                        end  
                    end 
                end

                DONE_ST : begin
                    if (!data_valid) begin
                        data_valid  <= 1'b1;
                        data_out    <= shft_reg_in;
                    end else begin 
                        data_valid  <= 1'b0;
                        state       <= IDLE_ST;
                    end 
                end 
            endcase 
        end
    end : fsm 

endmodule