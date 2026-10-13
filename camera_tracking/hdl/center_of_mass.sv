`default_nettype none
module center_of_mass (
        input wire clk,
        input wire rst,
        input wire [10:0] pixel_x,
        input wire [9:0]  pixel_y,
        input wire pixel_valid,
        input wire calculate,
        output logic [10:0] com_x,
        output logic [9:0] com_y,
        output logic com_valid
    );

    typedef enum logic [2:0] { 
        ACCUM,
        TRIGGER,
        WAIT,
        OUTPUT
    } major_fsm;

    major_fsm major_state;

    logic [31:0] sum_x, sum_y, sum_pixel;

    parameter WIDTH = 32;
    logic [WIDTH-1:0] dividend_x, dividend_y, divisor;
    logic [WIDTH-1:0] quotient_x, quotient_y, remainder_x, remainder_y;
    logic data_in_valid, data_out_valid_x, data_out_valid_y, error_x, error_y, busy_x, busy_y;

    logic [1:0] done; 

    divider div_x (
        .clk (clk),
        .rst (rst),
        .dividend (dividend_x),
        .divisor (divisor),
        .data_in_valid (data_in_valid),
        .quotient (quotient_x),
        .remainder (remainder_x),
        .data_out_valid (data_out_valid_x),
        .error (error_x),
        .busy (busy_x)
    );

    divider div_y (
        .clk (clk),
        .rst (rst),
        .dividend (dividend_y),
        .divisor (divisor),
        .data_in_valid (data_in_valid),
        .quotient (quotient_y),
        .remainder (remainder_y),
        .data_out_valid (data_out_valid_y),
        .error (error_y),
        .busy (busy_y)
    );

    always_ff @(posedge clk) begin 
        if (rst) begin 
            major_state   <= ACCUM;
            data_in_valid <= 1'b0;
            sum_pixel     <= '0;
            sum_x         <= '0;
            sum_y         <= '0;
            com_valid     <= 1'b0;
            done          <= '0;
        end else begin 
            case (major_state) 
                ACCUM : begin 
                    data_in_valid <= 1'b0;
                    done          <= 2'b0;

                    if (calculate) begin 
                        major_state <= TRIGGER;
                    end 

                    if (pixel_valid) begin 
                        sum_x     <= sum_x + pixel_x;
                        sum_y     <= sum_y + pixel_y;
                        sum_pixel <= sum_pixel + 1;
                    end 
                end 

                TRIGGER : begin 
                    if (sum_pixel >= 1) begin
                        dividend_x  <= sum_x;
                        dividend_y  <= sum_y;
                        divisor     <= sum_pixel;

                        if (!busy_x && !busy_y) begin 
                            data_in_valid <= 1'b1;
                            major_state   <= WAIT;
                        end 
                    end else begin 
                        major_state <= ACCUM;
                        
                        // Flush
                        sum_x       <= '0;
                        sum_y       <= '0;
                        sum_pixel   <= '0;
                    end 
                end 

                WAIT : begin 
                    data_in_valid <= 1'b0;

                    if (data_out_valid_x) begin 
                        done[1] <= 1'b1;
                        com_x   <= quotient_x;
                    end 

                    if (data_out_valid_y) begin 
                        done[0] <= 1'b1;
                        com_y   <= quotient_y;
                    end 

                    if ((data_out_valid_x || done[1]) && (data_out_valid_y || done[0])) begin  
                        major_state <= OUTPUT;
                        com_valid   <= 1'b1;
                    end 
                end 

                OUTPUT : begin 
                    major_state <= ACCUM;
                    com_valid   <= 1'b0;
                    done        <= '0;
                    sum_x       <= '0;
                    sum_y       <= '0;
                    sum_pixel   <= '0;
                end 
            endcase 
        end 
    end 

endmodule 

`default_nettype wire



