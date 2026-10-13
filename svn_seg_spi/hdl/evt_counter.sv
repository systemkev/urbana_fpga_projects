`default_nettype none
module evt_counter
    (   input wire          clk,
        input wire          rst,
        input wire          evt,
        output logic[15:0]  count
    );
    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 16'b0;
        end else begin
            count <= (evt)? count + 1 : count;
        end
    end
endmodule
`default_nettype wire