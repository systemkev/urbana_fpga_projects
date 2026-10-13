`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite #(
        parameter WIDTH=256, HEIGHT=256)
    (
        input wire pixel_clk,
        input wire rst,
        input wire [10:0] x, h_count,
        input wire [9:0]  y, v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    // calculate ROM address
    logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
    assign image_addr = (h_count - x) + ((v_count - y) * WIDTH);

    logic in_sprite;
    assign in_sprite = ((h_count >= x && h_count < (x + WIDTH)) &&
                        (v_count >= y && v_count < (y + HEIGHT)));

    logic [23:0] palette_out; 
    logic [7:0] image_out;

    // Modify the module below to use your BRAMs!
    // this will not do anything without you doing that!
    assign pixel_red =    in_sprite ? palette_out[23:16] : 0;
    assign pixel_green =  in_sprite ? palette_out[15:8] : 0;
    assign pixel_blue =   in_sprite ? palette_out[7:0] : 0;

    //  Palette ROM
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),                       // Specify RAM data width
        .RAM_DEPTH(256),                      // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(palette.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) palette_rom (
        .addra  (image_out),         // Address bus, width determined from RAM_DEPTH
        .dina   ('0),       // RAM input data, width determined from RAM_WIDTH
        .clka   (pixel_clk),// Clock
        .wea    (1'b0),     // Write enable
        .ena    (1'b1),     // RAM Enable, for additional power savings, disable port when not in use
        .rsta   (rst),      // Output reset (does not affect memory contents)
        .regcea (1'b1),     // Output register enable
        .douta  (palette_out)       // RAM output data, width determined from RAM_WIDTH
    );

    // Image ROM 
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),                       // Specify RAM data width
        .RAM_DEPTH(WIDTH * HEIGHT),                      // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) image_rom (
        .addra  (image_addr),         // Address bus, width determined from RAM_DEPTH
        .dina   ('0),       // RAM input data, width determined from RAM_WIDTH
        .clka   (pixel_clk),// Clock
        .wea    (1'b0),     // Write enable
        .ena    (1'b1),     // RAM Enable, for additional power savings, disable port when not in use
        .rsta   (rst),      // Output reset (does not affect memory contents)
        .regcea (1'b1),     // Output register enable
        .douta  (image_out)       // RAM output data, width determined from RAM_WIDTH
    );
endmodule


`default_nettype none
