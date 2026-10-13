`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module pong (
        input wire pixel_clk,
        input wire rst,
        input wire [1:0] control,
        input wire [3:0] puck_speed,
        input wire [3:0] paddle_speed,
        input wire new_frame,
        input wire [10:0] h_count,
        input wire [9:0] v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    //use these params!
    localparam PADDLE_WIDTH = 16;
    localparam PADDLE_HEIGHT = 128;
    localparam PUCK_WIDTH = 128;
    localparam PUCK_HEIGHT = 128;
    localparam GAME_WIDTH = 1280;
    localparam GAME_HEIGHT = 720;

    logic [10:0] puck_x, paddle_x; //puck x location, paddle x location
    logic [9:0] puck_y, paddle_y; //puck y location, paddle y location
    logic [7:0] puck_r,puck_g,puck_b; //puck red, green, blue (from block sprite)
    logic [7:0] paddle_r,paddle_g,paddle_b; //paddle colors from its block sprite)

    logic dir_x, dir_y; //use for direction of movement: 1 going positive, 0 going negative

	logic [10:0] x_puck_min, x_puck_max, x_paddle_min, x_paddle_max;
	logic [9:0] y_puck_min, y_puck_max, y_paddle_min, y_paddle_max;

	assign x_paddle_min = 0;
	assign x_paddle_max = PADDLE_WIDTH - 1;
	assign x_puck_min 	= puck_x; 
	assign x_puck_max 	= puck_x + PUCK_WIDTH - 1;
	assign y_paddle_min = paddle_y; 
	assign y_paddle_max = paddle_y + PADDLE_HEIGHT - 1;
	assign y_puck_min	= puck_y;
	assign y_puck_max 	= puck_y + PUCK_HEIGHT - 1;

    logic up, down; //up down from buttons
    logic game_over; //signal to indicate game over (0 on game reset, 1 during play)
    assign up = control[1]; //up control
    assign down = control[0]; //down control

    block_sprite #(.WIDTH(PADDLE_WIDTH), .HEIGHT(PADDLE_HEIGHT))
    paddle(
        .h_count(h_count),
        .v_count(v_count),
        .x(paddle_x),
        .y(paddle_y),
        .pixel_red(paddle_r),
        .pixel_green(paddle_g),
        .pixel_blue(paddle_b)
    );

    block_sprite #(.WIDTH(PUCK_WIDTH), .HEIGHT(PUCK_HEIGHT))
    puck(
      .h_count(h_count),
      .v_count(v_count),
      .x(puck_x),
      .y(puck_y),
      .pixel_red(puck_r),
      .pixel_green(puck_g),
      .pixel_blue(puck_b)
    );

	logic [15:0] rndm;

    // 1280 x 720
    // 1650 x 750 

    assign pixel_red = puck_r | paddle_r; //merge color contributions from puck and paddle
    assign pixel_green =  puck_g | paddle_g; //merge color contribuations from puck and paddle
    assign pixel_blue = puck_b | paddle_b; //merge color contributsion from puck and paddle

    logic puck_overlap; //one bit signal indicating if puck and paddle overlap
    //this signal should be one when puck is red in the video included in lab.
    //make signal be derived combinationally. you will need to figure this out
    //remember numbers are not signed here...so there's no such thing as negative

	assign puck_overlap = !(puck_y + PUCK_HEIGHT < paddle_y || paddle_y + PADDLE_HEIGHT < puck_y);

	logic last_rst;
	logic rst_pulse;
	always_ff @(posedge pixel_clk) begin 
		last_rst <= rst;
	end 

	assign rst_pulse = rst && !last_rst;

	lfsr_16 lfsr (
		.clk (pixel_clk),
		.rst (rst_pulse),
		.seed (16'h45A1), 	
		.q (rndm)
	);

    always_ff @(posedge pixel_clk)begin
        if (rst)begin
            paddle_x <= 0; 
			paddle_y <= (GAME_HEIGHT - PADDLE_HEIGHT) / 2;

			// start puck in the center horizontally
			puck_x <= rndm[8:0]; 

			// rndm[8:0] gives a range of 0-511, our maximum safe Y is 
			// GAME_HEIGHT - PUCK_HEIGHT (720 - 128 = 592), this fits perfectly 
			puck_y <= rndm[8:0]; 

			// sse the LFSR for pseudo-random starting directions
			dir_x <= rndm[0];
			dir_y <= rndm[1];
			
			game_over <= 1'b0;
          end else begin
            if (~game_over)begin
				if (new_frame) begin 
					// movement in the x
					if (up) begin
						if (y_paddle_min >= paddle_speed) begin 
							paddle_y <= paddle_y - paddle_speed;
						end  
					end else if (down) begin 
						if (y_paddle_max + paddle_speed <= GAME_HEIGHT - 1) begin 
							paddle_y <= paddle_y + paddle_speed;
						end 
					end 

					if (dir_x) begin 
						if (x_puck_max + puck_speed <= GAME_WIDTH) begin 
							puck_x 	<= puck_x + puck_speed;
						end else begin 
							puck_x 	<= puck_x - puck_speed;
							dir_x 	<= ~dir_x;  
						end 
					end else begin 
						if (x_puck_min <= puck_speed && !puck_overlap) begin 
							game_over <= 1'b1;
						end else if (x_puck_min <= puck_speed + PADDLE_WIDTH - 1 && puck_overlap) begin 
							dir_x	<= ~dir_x;
							puck_x  <= puck_x + puck_speed;
						end else begin 
							puck_x 	<= puck_x - puck_speed;
						end 
					end 

					// movement in the y 
					if (dir_y) begin
						if (y_puck_max + puck_speed <= GAME_HEIGHT - 1) begin 
							puck_y	<= puck_y + puck_speed;
						end else begin 
							puck_y 	<= puck_y - puck_speed;
							dir_y	<= 1'b0;
						end 
					end else begin 
						if (y_puck_min >= puck_speed) begin 
							puck_y 	<= puck_y - puck_speed;
						end else begin
							puck_y 	<= puck_y + puck_speed;
							dir_y 	<= 1'b1;
						end 
					end 
				end 
            end
        end
    end
endmodule
`default_nettype wire