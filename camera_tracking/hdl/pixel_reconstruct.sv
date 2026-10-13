`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct #(
    parameter HCOUNT_WIDTH = 11,
    parameter VCOUNT_WIDTH = 10
)(
    input wire                         clk,
    input wire                         rst,
    input wire                         camera_pclk,
    input wire                         camera_h_sync,
    input wire                         camera_v_sync,
    input wire [7:0]                   camera_data,

    output logic                       pixel_valid,
    output logic [HCOUNT_WIDTH-1:0]    pixel_h_count,
    output logic [VCOUNT_WIDTH-1:0]    pixel_v_count,
    output logic [15:0]                pixel_data
);
    // your code here! and here's a handful of logics that you may find helpful to utilize.

    // previous value of PCLK
    logic  pclk_prev;
    // can be assigned combinationally:
    //  true when pclk transitions from 0 to 1
    logic camera_sample_valid;
    assign camera_sample_valid = !pclk_prev && camera_pclk;
    
    // TODO: fix this assign
    // previous value of camera data, from last valid sample!
    // should NOT update on every cycle of clk, only
    // when samples are valid.
    logic last_sampled_hs;
    logic [7:0] last_sampled_data;
    // flag indicating whether the last byte has been transmitted or not.
    logic half_pixel_ready;

    always_ff@(posedge clk) begin
        if (rst) begin
            pixel_valid     <= 1'b0;
            pixel_h_count   <= '0;
            pixel_v_count   <= '0;
            pixel_data      <= '0;

            pclk_prev        <= 1'b0;
            last_sampled_hs  <= 1'b1;
            half_pixel_ready <= 1'b0; 
        end else begin
            pclk_prev   <= camera_pclk;
            pixel_valid <= 1'b0;

            if (pixel_valid) begin 
                pixel_h_count <= pixel_h_count + 1;
            end 

            if(camera_sample_valid) begin
                last_sampled_hs <= camera_h_sync;

                if (!camera_v_sync) begin 
                    pixel_h_count    <= '0;
                    pixel_v_count    <= '0;
                    half_pixel_ready <= 1'b0;
                end else begin 
                    if (!camera_h_sync) begin 
                        pixel_h_count    <= '0;
                        pixel_v_count    <= last_sampled_hs? pixel_v_count + 1 : pixel_v_count;
                        half_pixel_ready <= 1'b0;
                    end else begin
                        half_pixel_ready <= ~half_pixel_ready;

                        if (!half_pixel_ready) begin 
                            last_sampled_data <= camera_data;
                        end else begin 
                            pixel_valid <= 1'b1;
                            pixel_data  <= {last_sampled_data, camera_data};
                        end 
                    end 
                end 
            end
        end
    end
endmodule

`default_nettype wire
