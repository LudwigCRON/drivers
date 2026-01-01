`default_nettype none

module CLOCK_MIXER (
    input  wire   A,
    input  wire   B,
    input  wire   C,
    output wire   O
);

    // if there is a balanced gate existing in the
    // technology use this one
    or g_mix(O, A, B, C);

endmodule

module clock_divider #(
    parameter integer MIN_RATIO = 'd1,
    parameter integer MAX_RATIO = 'd2,
    // hidden parameter
    parameter integer RANGE_WIDTH = $clog2(MAX_RATIO - MIN_RATIO + 1) + 'd1
) (
    input  wire                   clk,
    input  wire                   rstb,
    input  wire [RANGE_WIDTH-1:0] div,
    input  wire                   dis, // low power consideration with default enabled (reset)
    output wire                   gclk,
    output wire                   grstb
);

    wire                   toggle;
    reg                    bypass_latched;
    wire                   clk_b; // bypassed clock
    reg                    clk_r;
    reg                    clk_f;  
    reg  [RANGE_WIDTH-2:0] counter;

    // control logic
    wire                   bypass;
    wire                   stop_div;

    assign bypass = ~|div[RANGE_WIDTH-1:1];
    assign stop_div = bypass | dis;

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            counter <= 'd0;
        else if (toggle)
            counter <= ({RANGE_WIDTH-1{~stop_div}} & div[RANGE_WIDTH-1:1]) + (div[0] & clk_r); // divide by 2
        else
            counter <= counter - 'd1;
    end

    assign toggle = ~|counter[RANGE_WIDTH-2:1];

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            clk_r <= 1'b0;
        else if (toggle)
            clk_r <= ~(clk_r | stop_div);
        else
            clk_r <= clk_r;
    end

    always @(negedge clk, negedge rstb)
    begin
        if (!rstb)
            clk_f <= 1'b0;
        else
            clk_f <= clk_r & div[0];
    end

    always @(*)
    begin
        if(!clk)
        begin
            bypass_latched = bypass;
        end
    end

    assign clk_b = bypass_latched & clk;

    // to ease constraints gives a name to a pin for each clock path
    // need to define 2 generated clocks: one for clk_b to gclk (undivided)
    // and another one for clk_r | clk_f to gclk (divided)
    CLOCK_MIXER g_mix (.O(gclk), .A(clk_r), .B(clk_f), .C(clk_b));

    // resynchronized the reset
    reg [3:0] sync_rstb;

    always @(posedge gclk, negedge rstb)
    begin
        if (!rstb)
        begin
            sync_rstb <= 4'h0;
        end else
        begin
            sync_rstb <= {sync_rstb[2:0], 1'b1};
        end
    end

    assign grstb = sync_rstb[3];

endmodule

`default_nettype wire
