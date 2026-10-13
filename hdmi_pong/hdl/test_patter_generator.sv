module test_pattern_generator(
    input wire [1:0] pattern_select,
    input wire [10:0] h_count,
    input wire [10:0] v_count,
    output logic [7:0] pixel_red,
    output logic [7:0] pixel_green,
    output logic [7:0] pixel_blue
);

    always_comb begin
        case (pattern_select)
            2'b00: begin //solid color
                pixel_red   = 8'h14;
                pixel_green = 8'h69;
                pixel_blue  = 8'h21;
            end

            2'b01: begin //vertical stripes
                if (v_count == 360 || h_count == 640) begin
                    pixel_red   = 8'hFF;
                    pixel_green = 8'hFF;
                    pixel_blue  = 8'hFF;
                end else begin 
                    pixel_red   = 8'h0;
                    pixel_green = 8'h0;
                    pixel_blue  = 8'h0;
                end 
            end

            2'b10: begin //horizontal stripes
                pixel_red   = h_count[7:0];
                pixel_green = h_count[7:0];
                pixel_blue  = h_count[7:0];
            end

            2'b11: begin //checkerboard pattern
                pixel_red   = h_count[7:0];
                pixel_green = v_count[7:0];
                pixel_blue  = h_count[7:0] + v_count[7:0];
            end

            default: begin //checkerboard pattern
                pixel_red   = h_count[7:0] + v_count[7:0];
                pixel_green = h_count[7:0] - v_count[7:0];
                pixel_blue  = h_count[7:0] + v_count[7:0];
            end
        endcase
    end

endmodule 