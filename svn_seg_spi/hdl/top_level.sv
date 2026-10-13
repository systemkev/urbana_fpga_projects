`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module top_level(
    input wire clk_100mhz, //100 MHz onboard clock
    input wire [15:0] sw, //all 16 input slide switches
    input wire [3:0] btn, //all four momentary button switches
    output logic [15:0] led, //16 green output LEDs (located right above switches)
    output logic [2:0] rgb0, //RGB channels of RGB LED0
    output logic [2:0] rgb1, //RGB channels of RGB LED1
    output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
    output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
    output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
    output logic [6:0] ss1_c, //cathode controls for the segments of lower four digits
    input wire cipo,
    output logic copi,
    output logic cs,
    output logic dclk
    );

    // this signal should go high for one cycle on the ..
    //rising edge of the (debounced) button output
    logic btn_pulse;
 
    //shut up those rgb LEDs for now (active high):
    assign rgb1 = 0; //set to 0.
 
    //have btnd control system reset
    logic sys_rst;
    assign sys_rst = btn[0];
 
    //how many button presses have we seen so far?
    //wire this up to the LED display
    logic [15:0] btn_count; //use me to keep track of counting
    assign led = btn_count;
 
    //downstream/display variables:
    logic [31:0] val_to_display; //either the spi data or the btn_count data (default)
    logic [6:0] ss_c; //used to grab output cathode signal for 7s leds
 
    // debouncer for the button. we wrote this in lecture together.
    //TODO: make a variable for the debounced
    //button output, and feed it into your edge detector
    logic clean_button;
 
    debouncer btn1_db(
        .clk(clk_100mhz),
        .rst(sys_rst),
        .dirty(btn[1]),
        .clean(clean_button)
    );

    logic last_button;

    always_ff @(posedge clk_100mhz) begin 
        if (sys_rst) begin 
            btn_pulse   <= 1'b0;
        end else begin
            last_button <= clean_button;

            if (clean_button && !last_button) begin
                btn_pulse <= 1'b1;
            end else begin 
                btn_pulse <= 1'b0;
            end 
        end 
    end 

 
    //TODO: write your edge detector for part 1 of the lab here!
 
    //the button-press counter.
    //TODO: finish this during part 1 of the lab
    evt_counter msc(
        .clk(clk_100mhz),
        .rst(sys_rst),
        .evt(btn_pulse),
        .count(btn_count)
    );
 
    //uncomment seven segment module for part 2!
    //
    seven_segment_controller mssc(
     .clk(clk_100mhz),
     .rst(sys_rst),
     .val(val_to_display),
     .cat(ss_c),
     .an({ss0_an, ss1_an})
     );
    //
    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c; //same as above but for lower four digits!

        //NEW CODE TO ADD IN
    //rgb controller instance (from last week!)
 
    logic [7:0] red, green, blue; //8 bit channels to hold color values
    assign val_to_display = {red, 4'h0, green, 4'h0, blue};
 
    rgb_controller mrgbc (.clk(clk_100mhz),
                          .rst(btn[0]),
                          .r_in(red),
                          .g_in(green),
                          .b_in(blue),
                          .r_out(rgb0[0]),
                          .g_out(rgb0[1]),
                          .b_out(rgb0[2]));
 
    parameter ADC_DATA_WIDTH = 17; //MUST CHANGE
    parameter ADC_DATA_CLK_PERIOD = 50; //MUST CHANGE
 
    parameter ADC_READ_PERIOD = 100_000; //read one channel of ADC every millisec
 
    //SPI interface controls
    logic [ADC_DATA_WIDTH-1:0] spi_write_data;
    logic [ADC_DATA_WIDTH-1:0] spi_read_data;
    logic spi_trigger;
    logic spi_read_data_valid;
 
    //built in previous section:
    spi_con
    #(   .DATA_WIDTH(ADC_DATA_WIDTH),
         .DATA_CLK_PERIOD(ADC_DATA_CLK_PERIOD)
     )my_spi_con
     ( .clk(clk_100mhz),
       .rst(sys_rst),
       .data_in(spi_write_data),
       .trigger(spi_trigger),
       .data_out(spi_read_data),
       .data_valid(spi_read_data_valid), //high when output data is present.
       .copi(copi), //(serial dout preferably)
       .cipo(cipo), //(serial din preferably)
       .dclk(dclk),
       .cs(cs)
    );
 
    //counter from week 1. that will count up and we'll use for triggering
    logic [31:0] select_count;
    counter //include your regular counter from week 1 in source!
    select_counter(
        .clk(clk_100mhz),
        .rst(sys_rst),
        .period(ADC_READ_PERIOD),
        .count(select_count)
    );
    //adc_count used for cycling through measuring ADC channel 0, 1, and 2
    logic [1:0] adc_count;
 
    always_ff @(posedge clk_100mhz)begin
        if (spi_read_data_valid)begin//if the SPI has received message back:
            case(adc_count) //update appropriate values based on adc_count
                0: red   <= spi_read_data[9:2];
                1: blue  <= spi_read_data[9:2]; 
                2: green <= spi_read_data[9:2];
                default: ;
            endcase
        end
        
        if (select_count=='d1)begin //once a millisecond select_count==1
            case(adc_count) //look ahead:
                0: begin
                    spi_write_data <= {1'b1, 1'b1, 3'd0, 12'b0};
                end
                1: begin
                    spi_write_data <= {1'b1, 1'b1, 3'd1, 12'b0};
                end
                2: begin
                    spi_write_data <= {1'b1, 1'b1, 3'd2, 12'b0};
                end
                default:begin
                    spi_write_data <= 0;
                end
            endcase
            spi_trigger <= 1; //trigger spi transaction (channel read based on case above)
            adc_count   <= (adc_count == 2)? 0 : adc_count + 1; //keep cycle to 0, 1, 2, 0..
        end else begin
            spi_trigger <= 0;
        end
    end
 
endmodule // top_level
 
`default_nettype wire