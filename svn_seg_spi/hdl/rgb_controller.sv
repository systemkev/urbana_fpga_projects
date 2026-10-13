module rgb_controller (
    input logic       clk,
    input logic       rst,
    input logic [7:0] r_in,
    input logic [7:0] g_in,
    input logic [7:0] b_in,

    output logic r_out,
    output logic g_out,
    output logic b_out
);

    pwm u_pwm_red (
        .clk     (clk),
        .rst     (rst),
        .dc_in   (r_in),
        .sig_out (r_out)
    );

    pwm u_pwm_green (
        .clk     (clk),
        .rst     (rst),
        .dc_in   (g_in),
        .sig_out (g_out)
    );

    pwm u_pwm_blue (
        .clk     (clk),
        .rst     (rst),
        .dc_in   (b_in),
        .sig_out (b_out)
    );

endmodule 