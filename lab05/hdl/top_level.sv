`timescale 1ns / 1ps
`default_nettype none

module top_level
    (
        input wire          clk_100mhz,
        output logic [15:0] led,
        // camera bus
        input wire [7:0]    camera_d, // 8 parallel data wires
        output logic        cam_xclk, // XC driving camera
        input wire          cam_h_sync, // camera h_sync wire
        input wire          cam_v_sync, // camera v_sync wire
        input wire          cam_pclk, // camera pixel clock
        inout wire          i2c_scl, // i2c inout clock
        inout wire          i2c_sda, // i2c inout data
        input wire [15:0]   sw,
        input wire [3:0]    btn,
        output logic [2:0]  rgb0,
        output logic [2:0]  rgb1,
        // seven segment
        output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
        output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
        output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
        output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
        // hdmi port
        output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
        output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
        output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
    );
    // Filename defining the commands we send to the camera on startup
    localparam CAMERA_SETTINGS_FILE = "rom.mem";
    // IF your camera feed comes out upside-down, download the alternate
    // memory file from the checkoff site, and replace "rom.mem" here
    // with "rom_vflip.mem".

    // shut up those RGBs
    assign rgb1 = 0;

    // Clock and Reset Signals
    logic          sys_rst_camera;
    logic          sys_rst_pixel;

    logic          clk_camera;
    logic          clk_pixel;
    logic          clk_5x;
    logic          clk_xc;

    logic clk_camera_locked;

    logic          clk_100_passthrough;

    // clocking wizards to generate the clock speeds we need for our different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
    cw_hdmi_clk_wiz wizard_hdmi(
        .sysclk(clk_100_passthrough),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0)
    );

    cw_fast_clk_wiz wizard_migcam(
        .clk_in1(clk_100mhz),
        .clk_camera(clk_camera),
        .locked(clk_camera_locked),
        .clk_xc(clk_xc),
        .clk_100(clk_100_passthrough),
        .reset(0)
    );

    // assign camera's xclk to pmod port: drive the operating clock of the camera!
    // this port also is specifically set to high drive by the XDC file.
    assign cam_xclk = clk_xc;
    //assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
    //assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic


    // video signal generator signals
    logic           h_sync_hdmi;
    logic           v_sync_hdmi;
    logic [10:0]    h_count_hdmi;
    logic [9:0]     v_count_hdmi;
    logic           active_draw_hdmi;
    logic           new_frame_hdmi;
    logic [5:0]     frame_count_hdmi;

    // ps3  8-cycle pipeline
    logic [10:0] h_count_pipe [0:7];
    logic [9:0]  v_count_pipe [0:7];

    logic [7:0] h_sync_pipe;
    logic [7:0] v_sync_pipe;
    logic [7:0] active_draw_pipe;
    logic [7:0] new_frame_pipe;

    always_ff @(posedge clk_pixel) begin
        h_count_pipe[0] <= h_count_hdmi;
        v_count_pipe[0] <= v_count_hdmi;

        h_sync_pipe[0]     <= h_sync_hdmi;
        v_sync_pipe[0]     <= v_sync_hdmi;
        active_draw_pipe[0] <= active_draw_hdmi;
        new_frame_pipe[0]   <= new_frame_hdmi;

        for (int i = 1; i < 8; i = i + 1) begin
            h_count_pipe[i] <= h_count_pipe[i-1];
            v_count_pipe[i] <= v_count_pipe[i-1];
        end

        for (int i = 1; i < 8; i = i + 1) begin
            h_sync_pipe[i] <= h_sync_pipe[i-1];
            v_sync_pipe[i] <= v_sync_pipe[i-1];
            active_draw_pipe[i] <= active_draw_pipe[i-1];
            new_frame_pipe[i] <= new_frame_pipe[i-1];
        end
    end

    // rgb output values
    logic [7:0]     red,green,blue;

    // ** Handling input from the camera **

    // synchronizers to prevent metastability
    logic [7:0]     camera_d_buf [1:0];
    logic           cam_h_sync_buf [1:0];
    logic           cam_v_sync_buf [1:0];
    logic           cam_pclk_buf [1:0];

    logic           sys_rst_camera_buf [1:0];
    logic           sys_rst_pixel_buf [1:0];

    always_ff @(posedge clk_pixel )begin
        sys_rst_pixel_buf <= {btn[0], sys_rst_pixel_buf[1]};
    end
    assign sys_rst_pixel = sys_rst_pixel_buf[0];

    always_ff @(posedge clk_camera) begin
        camera_d_buf <= {camera_d, camera_d_buf[1]};
        cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
        cam_h_sync_buf <= {cam_h_sync, cam_h_sync_buf[1]};
        cam_v_sync_buf <= {cam_v_sync, cam_v_sync_buf[1]};
        sys_rst_camera_buf <= {btn[0], sys_rst_camera_buf[1]};
    end

    assign sys_rst_camera = sys_rst_camera_buf[0] || !clk_camera_locked;

    logic [10:0]    camera_h_count;
    logic [9:0]     camera_v_count;
    logic [15:0]    camera_pixel;
    logic           camera_valid;

    // your pixel_reconstruct module, from the exercise!
    // hook it up to buffered inputs.
    pixel_reconstruct(
        .clk(clk_camera),
        .rst(sys_rst_camera),
        .camera_pclk(cam_pclk_buf[0]),
        .camera_h_sync(cam_h_sync_buf[0]),
        .camera_v_sync(cam_v_sync_buf[0]),
        .camera_data(camera_d_buf[0]),

        .pixel_valid(camera_valid),
        .pixel_h_count(camera_h_count),
        .pixel_v_count(camera_v_count),
        .pixel_data(camera_pixel)
    );



    //two-port BRAM used to hold image from camera.
    //The camera is producing video at 720p and 30fps, but we can't store all of that
    //we're going to down-sample by a factor of 4 in both dimensions
    //so we have 320 by 180.  this is kinda a bummer, but we'll fix it
    //in future weeks by using off-chip DRAM.
    //even with the down-sample, because our camera is producing data at 30fps
    //and  our display is running at 720p at 60 fps, there's no hope to have the
    //production and consumption of inew_frameormation be synchronized in this system.
    //even if we could line it up once, the clocks of both systems will drift over time
    //so to avoid this sync issue, we use a conew_framelict-resolution device...the frame buffer
    //instead we use a frame buffer as a go-between. The camera sends pixels in at
    //its own rate, and we pull them out for display at the 720p rate/requirement
    //this avoids the whole sync issue. It will however result in artifacts when you
    //introduce fast motion in front of the camera. These lines/tears in the image
    //are the result of unsynced frame-rewriting happening while displaying. It won't
    //matter for slow movement
    localparam FB_DEPTH = 320*180;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer

    logic valid_camera_mem; //used to enable writing pixel data to frame buffer
    logic [15:0] camera_mem; //used to pass pixel data into frame buffer


    //TO DO in camera part 1:
    always_ff @(posedge clk_camera)begin
        //create logic to handle wriiting of camera.
        //we want to down sample the data from the camera by a factor of four in both
        //the x and y dimensions! TO DO

        valid_camera_mem <= 1'b0;

        if (camera_valid && camera_h_count[1:0] == 2'b0 && camera_v_count[1:0] == 2'b0) begin 
            addra            <= camera_v_count[9:2] * 320 + camera_h_count[10:2];
            camera_mem       <= camera_pixel;
            valid_camera_mem <= 1'b1;
        end 
    end


    logic [15:0] frame_buff_raw; //data out of frame buffer (565)
    logic [FB_SIZE-1:0] addrb; //used to lookup address in memory for reading from buffer
    logic good_addrb; //used to indicate within valid frame for scaling

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), //each entry in this memory is 16 bits
        .RAM_DEPTH(FB_DEPTH)) //there are 320*180 or 57600 entries for full frame
    frame_buffer (
        .addra(addra), //pixels are stored using this math
        .clka(clk_camera),
        .wea(valid_camera_mem),
        .dina(camera_mem),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst_camera),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst_pixel),
        .regceb(1'b1),
        .doutb(frame_buff_raw)
    );

    //TO DO in camera part 1:
    // Scale pixel coordinates from HDMI to the frame buffer to grab the right pixel
    //scaling logic!!! You need to complete!!! We want 1X, 2X, and 4X!
    always_ff @(posedge clk_pixel) begin
        good_addrb    <= 1'b0;
        if (btn[1])begin //1X scaling from frame buffer
           addrb      <= v_count_hdmi * 320 + h_count_hdmi;
           good_addrb <= (v_count_hdmi < 180 && h_count_hdmi < 320);
        end else if (!sw[0])begin //2X scaling from frame buffer
           addrb      <= v_count_hdmi[9:1] * 320 + h_count_hdmi[10:1];
           good_addrb <= (v_count_hdmi < 180*2 && h_count_hdmi < 320*2);
        end else begin //4X scaling from frame buffer
           addrb      <= v_count_hdmi[9:2] * 320 + h_count_hdmi[10:2];
           good_addrb <= (v_count_hdmi < 180*4 && h_count_hdmi < 320*4);
        end
    end

    logic good_addrb_d1, good_addrb_d2;

    always_ff @(posedge clk_pixel) begin
        good_addrb_d1 <= good_addrb;
        good_addrb_d2 <= good_addrb_d1;
    end

    //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel) begin
        fb_red   <= good_addrb_d2 ? {frame_buff_raw[15:11], 3'b0} : 8'b0;

        fb_green <= good_addrb_d2 ? {frame_buff_raw[10:5], 2'b0} : 8'b0;

        fb_blue  <= good_addrb_d2 ? {frame_buff_raw[4:0], 3'b0} : 8'b0;
    end
    // Pixel Processing pre-HDMI output

    // RGB to YCrCb

    // PS1 and PS2
    logic [23:0] fb_rgb_pipe [0:3];

    always_ff @(posedge clk_pixel) begin
        fb_rgb_pipe[0] <= {fb_red, fb_green, fb_blue};

        for (int i = 1; i < 4; i = i + 1) begin
            fb_rgb_pipe[i] <= fb_rgb_pipe[i-1];
        end
    end

    //output of rgb to ycrcb conversion (10 bits due to module):
    logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
    //bottom 8 of y, cr, cb conversions:
    logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
    //Convert RGB of full pixel to YCrCb
    //See lecture 07 for YCrCb discussion.
    //Module has a 3 cycle latency
    rgb_to_ycrcb rgbtoycrcb_m(
        .clk(clk_pixel),
        .r(fb_red),
        .g(fb_green),
        .b(fb_blue),
        .y(y_full),
        .cr(cr_full),
        .cb(cb_full)
    );

    //take lower 8 of full outputs.
    // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
    assign y = y_full[7:0];
    assign cr = {!cr_full[7],cr_full[6:0]};
    assign cb = {!cb_full[7],cb_full[6:0]};

    //channel select module (select which of six color channels to mask):
    logic [2:0] channel_sel;
    logic [7:0] selected_channel; //selected channels
    //selected_channel could contain any of the six color channels depend on selection

    //threshold module (apply masking threshold):
    logic [7:0] lower_threshold;
    logic [7:0] upper_threshold;
    logic mask; //Whether or not thresholded pixel is 1 or 0

    //Center of Mass variables (tally all mask=1 pixels for a frame and calculate their center of mass)
    logic [10:0] x_com, x_com_calc; //long term x_com and output from module, resp
    logic [9:0] y_com, y_com_calc; //long term y_com and output from module, resp
    logic new_com; //used to know when to update x_com and y_com ...

    // ps5 selected channel, 1 cycle
    logic [7:0] selected_channel_ps5;

    // ps6 luminance, 1 cycle
    logic [7:0] y_ps6;

    always_ff @(posedge clk_pixel) begin
        selected_channel_ps5 <= selected_channel;
        y_ps6 <= y;
    end

    assign channel_sel = sw[3:1];
    // * 3'b000: green
    // * 3'b001: red
    // * 3'b010: blue
    // * 3'b011: not valid
    // * 3'b100: y (luminance)
    // * 3'b101: Cr (Chroma Red)
    // * 3'b110: Cb (Chroma Blue)
    // * 3'b111: not valid
    //Channel Select: Takes in the full RGB and YCrCb inew_frameormation and
    // chooses one of them to output as an 8 bit value
    channel_select mcs(
        .select(channel_sel),
        // fix for PS1
        .r(fb_rgb_pipe[2][23:16]),
        .g(fb_rgb_pipe[2][15:8]),
        .b(fb_rgb_pipe[2][7:0]),
        .y(y),
        .cr(cr),
        .cb(cb),
        .selected_channel(selected_channel)
    );

    //threshold values used to determine what value  passes:
    assign lower_threshold = {sw[11:8],4'b0};
    assign upper_threshold = {sw[15:12],4'b0};

    //Thresholder: Takes in the full selected channedl and
    //based on upper and lower bounds provides a binary mask bit
    // * 1 if selected channel is within the bounds (inclusive)
    // * 0 if selected channel is not within the bounds
    threshold mt(
       .clk(clk_pixel),
       .rst(sys_rst_pixel),
       .pixel(selected_channel),
       .lower_bound(lower_threshold),
       .upper_bound(upper_threshold),
       .mask(mask) //single bit if pixel within mask.
    );


    logic [6:0] ss_c;
    //modified version of seven segment display for showing
    // thresholds and selected channel
    // special customized version
    lab05_ssc mssc(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .lower_threshold(lower_threshold),
        .upper_threshold(upper_threshold),
        .channel_select(channel_sel),
        .cathode(ss_c),
        .anode({ss0_an, ss1_an})
    );
    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c; //same as above but for lower four digits!

    //Center of Mass Calculation: (you need to do)
    //using x_com_calc and y_com_calc values
    //Center of Mass:
    center_of_mass com_m(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        // changes for PS3
        .pixel_x(h_count_pipe[7]),
        .pixel_y(v_count_pipe[7]),
        .pixel_valid(mask),
        .calculate(new_frame_pipe[7]),
        .com_x(x_com_calc),
        .com_y(y_com_calc),
        .com_valid(new_com)
    );
    //grab logic for above
    //update center of mass x_com, y_com based on new_com signal
    always_ff @(posedge clk_pixel)begin
        if (sys_rst_pixel)begin
            x_com <= 0;
            y_com <= 0;
        end if(new_com)begin
            x_com <= x_com_calc;
            y_com <= y_com_calc;
        end
    end

    //image_sprite output:
    logic [7:0] img_red, img_green, img_blue;

    // TODO: image sprite using hdmi h_count/v_count, x_com y_com to draw image or nothing
    //bring in an instance of your popcat image sprite! remember the correct mem files too!

    image_sprite_2 #(
        .WIDTH(256),
        .HEIGHT(256)
    ) popcat (
        .pixel_clk(clk_pixel),
        .rst(sys_rst_pixel),

        .x(x_com - 11'd128),
        .y(y_com - 10'd128),

        .h_count(h_count_hdmi),
        .v_count(v_count_hdmi),

        .pop(1'b0),

        .pixel_red(img_red),
        .pixel_green(img_green),
        .pixel_blue(img_blue)
    );

    //crosshair output:
    logic [7:0] ch_red, ch_green, ch_blue;

    //Create Crosshair patter on center of mass:
    //0 cycle latency
    //TODO: Should be using output of (PS3)
    always_comb begin
        ch_red   = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
        ch_green = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
        ch_blue  = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
    end


    // PS8: crosshair delayed 8 cycles
    logic [23:0] crosshair_pipe [0:7];

    // PS9: sprite delayed 4 cycles
    logic [23:0] sprite_pipe [0:3];

    always_ff @(posedge clk_pixel) begin

        crosshair_pipe[0] <= {ch_red, ch_green, ch_blue};

        for (int i = 1; i < 8; i = i + 1) begin
            crosshair_pipe[i] <= crosshair_pipe[i-1];
        end

        sprite_pipe[0] <= {img_red, img_green, img_blue};

        for (int i = 1; i < 4; i = i + 1) begin
            sprite_pipe[i] <= sprite_pipe[i-1];
        end

    end


    // HDMI video signal generator
    video_sig_gen vsg(
        .pixel_clk(clk_pixel),
        .rst(sys_rst_pixel),
        .h_count(h_count_hdmi),
        .v_count(v_count_hdmi),
        .v_sync(v_sync_hdmi),
        .h_sync(h_sync_hdmi),
        .new_frame(new_frame_hdmi),
        .active_draw(active_draw_hdmi),
        .frame_count(frame_count_hdmi)
    );


    // Video Mux: select from the different display modes based on switch values
    //used with switches for display selections
    logic [1:0] background_choice;
    logic [1:0] target_choice;

    assign background_choice = sw[5:4];
    assign target_choice =  sw[7:6];

    //choose what background from the camera:
    // * 'b00:  normal camera out
    // * 'b01:  selected channel image in grayscale
    // * 'b10:  masked pixel (all on if 1, all off if 0)
    // * 'b11:  chroma channel with mask overtop as magenta
    //
    //then choose what to use with center of mass:
    // * 'b00: nothing
    // * 'b01: crosshair
    // * 'b10: sprite on top
    // * 'b11: nothing


    video_mux mvm(
        .background_choice(background_choice),
        .target_choice(target_choice),

        // ps2: 4 cycles after framebuffer RGB
        .camera_pixel(fb_rgb_pipe[3]),

        // ps6: 1 cycle
        .camera_y_channel(y_ps6),

        // ps5: 1 cycle
        .selected_channel(selected_channel_ps5),

        // ps4: 0 additional cycles
        .thresholded_pixel(mask),

        // ps8: 8 cycles
        .crosshair(crosshair_pipe[7]),

        // ps9: 4 cycles
        .com_sprite_pixel(sprite_pipe[3]),

        .muxed_pixel({red, green, blue})
    );

    // HDMI Output: just like before!

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic       tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control[0] = horizontal sync signal
    //  * control[1] = vertical sync signal

    tmds_encoder tmds_red(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(red),
        .control(2'b0),
        .video_enable(active_draw_pipe[7]),
        .tmds(tmds_10b[2])
    );
    tmds_encoder tmds_green(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(green),
        .control(2'b0),
        .video_enable(active_draw_pipe[7]),
        .tmds(tmds_10b[1])
    );
    tmds_encoder tmds_blue(
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .video_data(blue),
        .control({v_sync_pipe[7], h_sync_pipe[7]}),
        .video_enable(active_draw_pipe[7]),
        .tmds(tmds_10b[0])
    );


    //three tmds_serializers (blue, green, red):
    //MISSING: two more serializers for the green and blue tmds signals.
    tmds_serializer red_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2])
    );
    tmds_serializer green_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1])
    );
    tmds_serializer blue_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst_pixel),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0])
    );

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

    // Nothing To Touch Down Here:
    // register writes to the camera

    // The OV5640 has an I2C bus connected to the board, which is used
    // for setting all the hardware settings (gain, white balance,
    // compression, image quality, etc) needed to start the camera up.
    // We've taken care of setting these all these values for you:
    // "rom.mem" holds a sequence of bytes to be sent over I2C to get
    // the camera up and running, and we've written a design that sends
    // them just after a reset completes.

    // If the camera is not giving data, press your reset button.

    logic  busy, bus_active;
    logic  cr_init_valid, cr_init_ready;

    logic request_config;
  
    localparam DELAY_CLOCK_CYCLES = 200_000_000 * 1;
    logic [$clog2(DELAY_CLOCK_CYCLES):0] count_delay;

    logic [1:0] camera_setup_btn_buf;
    
    always_ff @(posedge clk_camera) begin
        
        // synchronizer buffers for btn[2]
        camera_setup_btn_buf <= {btn[2], camera_setup_btn_buf[1]};

        // baby state machine; delay 1 second after button press, then inititate I2C command sequence
        if (sys_rst_camera) begin
            request_config <= 1'b0;
            cr_init_valid  <= 1'b0;
            count_delay <= 'b0;
        end else if (camera_setup_btn_buf[0]) begin // when btn[2] gets pressed
            request_config <= 1'b1;
            cr_init_valid  <= 1'b0;
            count_delay <= 'b0;
        end else if (request_config) begin
            if (count_delay >= DELAY_CLOCK_CYCLES) begin
                cr_init_valid  <= 1'b1;
                request_config <= 1'b0;
                count_delay <= 'b0;
            end else begin
                count_delay <= count_delay + 1;
            end
        end else if (cr_init_valid && cr_init_ready) begin
            cr_init_valid <= 1'b0;
            count_delay <= 'b0;
        end
    end

    logic [23:0] bram_dout;
    logic [7:0]  bram_addr;

    // ROM holding pre-built camera settings to send
    xilinx_single_port_ram_read_first
    #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(CAMERA_SETTINGS_FILE)
    ) registers
    (
        .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),     // Clock
        .wea(1'b0),            // Write enable
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
    );

    logic [23:0] registers_dout;
    logic [7:0]  registers_addr;
    assign registers_dout = bram_dout;
    assign bram_addr = registers_addr;

    logic       con_scl_i, con_scl_o, con_scl_t;
    logic       con_sda_i, con_sda_o, con_sda_t;

    // NOTE these also have pullup specified in the xdc file!
    // access our inouts properly as tri-state pins
    IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
    IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

    // provided module to send data BRAM -> I2C
    camera_registers crw
    (   .clk_in(clk_camera),
        .rst_in(sys_rst_camera),
        .init_valid(cr_init_valid),
        .init_ready(cr_init_ready),
        .scl_i(con_scl_i),
        .scl_o(con_scl_o),
        .scl_t(con_scl_t),
        .sda_i(con_sda_i),
        .sda_o(con_sda_o),
        .sda_t(con_sda_t),
        .bram_dout(registers_dout),
        .bram_addr(registers_addr)
    );
    // a handful of debug signals for writing to registers

    assign rgb0[0] = crw.bus_active;
    assign rgb0[2] = ~clk_camera_locked;
    assign rgb0[1] = 0;
  
    assign led[0] = cam_h_sync_buf[0];
    assign led[1] = cam_v_sync_buf[0];
    assign led[2] = cam_pclk_buf[0];
    assign led[3] = cr_init_valid;
    assign led[4] = cr_init_ready;
    assign led[15:5] = 0;
endmodule // top_level


`default_nettype wire

