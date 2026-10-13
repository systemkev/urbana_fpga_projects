`timescale 1ns / 1ps
`default_nettype none

module lfsr_16 (
    input wire clk,
    input wire rst,
    input wire [15:0] seed,
    output logic [15:0] q
);

    always_ff @(posedge clk) begin 
        if (rst) begin 
            q <= seed;
        end else begin
            q <= {q[14] ^ q[15], q[13:2], q[1] ^ q[15], q[0], q[15]};
        end 
    end 

endmodule

`default_nettype wire
