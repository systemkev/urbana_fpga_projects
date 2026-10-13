`timescale 1ns / 1ps
`default_nettype none

module lfsr_4 (
        input wire clk,
        input wire rst,
        input wire [3:0] seed,
        output logic [3:0] q
    );

    always_ff @(posedge clk) begin 
        if (rst) begin 
            q <= seed;
        end else begin
            q <= {q[2], q[1], q[0] ^ q[3], q[3]}; 
        end 
    end 

endmodule

`default_nettype wire