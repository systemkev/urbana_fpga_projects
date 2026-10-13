`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite_2 #(
        parameter WIDTH=256, HEIGHT=256)
    (
        input wire pixel_clk,
        input wire rst,
        input wire [10:0] x, h_count,
        input wire [9:0]  y, v_count,
        input wire pop,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    // calculate ROM address
    logic [$clog2(WIDTH*HEIGHT*2)-1:0] image_addr;
    assign image_addr = (!pop)? (h_count - x) + ((v_count - y) * WIDTH) : (h_count - x) + ((v_count - y) * WIDTH) + WIDTH * HEIGHT;

    logic in_sprite;
    assign in_sprite = ((h_count >= x && h_count < (x + WIDTH)) &&
                        (v_count >= y && v_count < (y + HEIGHT)));

    // ps10: Match the image ROM + palette ROM latency
    // 2 cycles + 2 cycles = 4 cycles

    logic [3:0] in_sprite_pipe;

    always_ff @(posedge pixel_clk) begin
        if (rst) begin
            in_sprite_pipe <= 4'b0;
        end else begin
            in_sprite_pipe <= {in_sprite_pipe[2:0], in_sprite};
        end
    end

    logic [23:0] palette_out; 
    logic [7:0] image_out;

    // Modify the module below to use your BRAMs!
    // this will not do anything without you doing that!
    assign pixel_red = in_sprite_pipe[3] ? palette_out[23:16] : 8'b0;

    assign pixel_green = in_sprite_pipe[3] ? palette_out[15:8] : 8'b0;

    assign pixel_blue = in_sprite_pipe[3] ? palette_out[7:0] : 8'b0;

    //  Palette ROM
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),                       // Specify RAM data width
        .RAM_DEPTH(256),                      // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(palette2.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
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
        .RAM_DEPTH(WIDTH * HEIGHT * 2),                      // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(image2.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
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
