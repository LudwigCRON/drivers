`default_nettype none

module wut #(
    parameter integer WIDTH = 'd9
) (
    // digital power domain
    input  wire             prim_clk,
    input  wire             prim_rstb,

    input  wire [WIDTH-1:0] wut_limit,

    input  wire             wut_disable,
    input  wire             wut_start_req,
    output wire             wut_start_ack,
    output reg              wut_trig_it
);

    localparam [1:0] S_IDLE = 2'b00;
    localparam [1:0] S_INCR = 2'b01;
    localparam [1:0] S_DONE = 2'b11;

    reg [      1:0] current_state;

    reg [WIDTH-1:0] counter;
    wire            counter_done;
    wire            counter_incr;
    wire            counter_stop;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
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

    assign counter_done = ((counter + 'd1) >= wut_limit);
    assign counter_incr = current_state[0] | (!current_state[0] & wut_start_req);
    assign counter_stop = ~counter_incr | wut_disable;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            current_state <= S_IDLE;
        end else
        begin
            case(current_state)
                S_IDLE : current_state <= (!wut_disable && wut_start_req && !counter_done) ? S_INCR :
                                          (!wut_disable && wut_start_req &&  counter_done) ? S_DONE : S_IDLE;
                S_INCR : current_state <= (counter_done  ||  counter_stop) ? S_DONE : S_INCR; 
                default: current_state <= S_IDLE;
            endcase
        end
    end

    assign wut_start_ack = current_state[0];
    assign wut_trig_it   = current_state[1];

endmodule

`default_nettype wire
