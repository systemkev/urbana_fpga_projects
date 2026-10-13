`timescale 1ns / 1ps
`default_nettype none

module tm_choice (
    input wire [7:0] d,
    output logic [8:0] q_m
);

    logic [3:0] num_ones; 

    assign num_ones = d[7] + d[6] + d[5] + d[4] + d[3] + d[2] + d[1] + d[0];

    always_comb begin 
        q_m[0] = d[0];
        if (num_ones > 4 || (num_ones == 4 && !d[0])) begin 
            // option 2
            q_m[8]  = 1'b0;
            for (int i = 1; i <= 7; i++) begin 
                q_m[i] = d[i] ~^ q_m[i-1];
            end 
        end else begin 
            // option 1
            q_m[8]  = 1'b1;
            for (int i = 1; i <= 7; i++) begin 
                q_m[i] = d[i] ^ q_m[i-1];
            end 
        end 
    end 
endmodule //end tm_choice

`default_nettype wire