`timescale 1ns / 1ps
`default_nettype none
 
module tmds_encoder(
        input wire clk,
        input wire rst,
        input wire [7:0] video_data,  // video data (red, green or blue)
        input wire [1:0] control,   //for blue set to {vs,hs}, else will be 0
        input wire video_enable,    //choose between control (0) or video (1)
        output logic [9:0] tmds
);

    logic [8:0] q_m;
    logic signed [4:0] tally; 
    logic signed [4:0] num_ones;
    logic signed [4:0] num_zero;
 
    tm_choice mtm(
        .d(video_data),
        .q_m(q_m)
    );

    assign num_ones = q_m[7] + q_m[6] + q_m[5] + q_m[4] + q_m[3] + q_m[2] + q_m[1] + q_m[0];
    assign num_zero = 8 - num_ones;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            tally   <= '0;
            tmds    <= '0;
        end else begin 
            if (!video_enable) begin 
                tally   <= '0;
                case (control)
                    2'b00: 
                        tmds <= 10'b1101010100;

                    2'b01: 
                        tmds <= 10'b0010101011;

                    2'b10: 
                        tmds <= 10'b0101010100;

                    2'b11: 
                        tmds <= 10'b1010101011;
                endcase 
            end else begin 
                if (tally == 0 || num_ones == 4) begin 
                    tmds[9]     <= ~q_m[8];
                    tmds[8]     <= q_m[8];
                    tmds[7:0]   <= (q_m[8])? q_m[7:0] : ~q_m[7:0];
                    tally       <= tally + (q_m[8] ? num_ones - num_zero : num_zero - num_ones);
                end else begin 
                    if ((tally > 0 && num_ones > num_zero) || (tally < 0 && num_zero > num_ones)) begin 
                        tmds[9]     <= 1'b1;
                        tmds[8]     <= q_m[8];
                        tmds[7:0]   <= ~q_m[7:0];
                        tally       <= tally + (num_zero - num_ones) + (q_m[8] ? 2 : 0);
                    end else begin 
                        tmds[9]     <= 1'b0;
                        tmds[8]     <= q_m[8];
                        tmds[7:0]   <= q_m[7:0];
                        tally       <= tally + (num_ones - num_zero) + (q_m[8] ? 0 : -2);
                    end 
                end 
            end 
        end 
    end 
 
endmodule
 
`default_nettype wire