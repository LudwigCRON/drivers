`define_nettype none

module wut #(
    parameter integer WIDTH = 'd9;
) (
    // digital power domain
    input  wire             perm_clk,
    input  wire             perm_rstb,

    input  wire [WIDTH-1:0] perm_wut_limit,

    input  wire             perm_wut_disable,
    input  wire             perm_wut_start_req,
    output reg              perm_wut_start_ack,
    output reg              perm_wut_trig_it
);

    reg [WIDTH-1:0] counter;
    wire            counter_done;
    wire            counter_incr;
    wire            counter_stop;

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            counter <= 'd0;
        end else if (counter_stop)
        begin
            counter <= 'd0;
        end else if (counter_incr)
        begin
            counter <= counter + 'd1;
        end else
        begin
            counter <= counter;
        end
    end

    assign counter_done = (counter >= perm_wut_limit);
    assign counter_incr = (perm_wut_start_req & !perm_wut_start_ack) | (counter > 'd0);
    assign counter_stop = counter_done | perm_wut_disable;

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_wut_start_ack <= 1'd0;
            perm_wut_trig_it   <= 1'b0;
        end else if (counter_stop)
        begin
            perm_wut_start_ack <= 1'd0;
            perm_wut_trig_it   <= 1'b0;
        end else if (counter_incr)
        begin
            perm_wut_start_ack <= 1'b1;
            perm_wut_trig_it   <= 1'b0;
        end else
        begin
            perm_wut_start_ack <= 1'b0;
            perm_wut_trig_it   <= counter_done;
        end
    end

endmodule

`define_nettype wire
