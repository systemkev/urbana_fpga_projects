module pwm (
    input  logic clk,
    input  logic rst,
    input  logic [7:0] dc_in,
    output logic sig_out
);

    logic [31:0] count;
    logic [7:0] dc;

    counter mc (
        .clk    (clk),
        .rst    (rst),
        .period (256),
        .count  (count)
    );

    assign sig_out = count < dc; 

    always_ff @(posedge clk) begin
        if (rst) begin
            dc <= '0;
        end else if (count == 255) begin
            dc <= dc_in; 
        end 
    end  
endmodule