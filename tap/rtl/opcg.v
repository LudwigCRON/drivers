
module opcg (
    input  wire tck,
    input  wire trstb,
    input  wire tapp_active,
    input  wire tscan_exe,
    output wire texe_done,
    input  wire gclk,
    input  wire gclk_rstb,
    output wire gclk_app_active,
    output wire clk
);

    localparam [2:0] S_INIT = 3'b000; // application
    localparam [2:0] S_SCAN = 3'b001; // scan
    localparam [2:0] S_GAP0 = 3'b011; // transition
    localparam [2:0] S_OSC0 = 3'b111; // first pulse
    localparam [2:0] S_OSC1 = 3'b110; // second pulse
    localparam [2:0] S_GAP1 = 3'b100; // transition 1
    localparam [2:0] S_GAP2 = 3'b101; // transition 2
    localparam [2:0] S_APPL = 3'b010; // application

    reg [2:0] scan_exe_resync;
    reg [1:0] exe_done_resync;
    reg [1:0] in_app_resync;
    reg [2:0] state;

    always @(posedge gclk, negedge gclk_rstb)
    begin
        if (!gclk_rstb)
            in_app_resync <= 2'b00;
        else
            in_app_resync <= {in_app_resync[0], tapp_active};
    end

    assign gclk_app_active = in_app_resync[1];

    always @(posedge gclk, negedge gclk_rstb)
    begin
        if (!gclk_rstb)
            scan_exe_resync <= 3'b000;
        else
            scan_exe_resync <= {scan_exe_resync[1:0], tscan_exe};
    end

    always @(posedge gclk, negedge gclk_rstb)
    begin
        if (!gclk_rstb)
            state <= S_INIT;
        else
            case(state)
                S_INIT : state <= (in_app_resync[1]   ) ? S_APPL : S_SCAN;
                S_SCAN : state <= (scan_exe_resync[2] ) ? S_GAP0 : 
                                  (in_app_resync[1]   ) ? S_INIT : S_SCAN;
                S_GAP0 : state <= S_OSC0;
                S_OSC0 : state <= S_OSC1;
                S_OSC1 : state <= S_GAP1;
                S_GAP1 : state <= S_GAP2;
                S_GAP2 : state <= (!scan_exe_resync[2]) ? S_SCAN : S_GAP2;
                S_APPL : state <= (in_app_resync[1]   ) ? S_APPL : S_INIT;
                default: state <= S_INIT;
            endcase
    end

    always @(posedge tck, negedge trstb)
    begin
        if (!trstb)
            exe_done_resync <= 2'b00;
        else
            exe_done_resync <= {exe_done_resync[0], (state == S_GAP2)};
    end

    assign texe_done = exe_done_resync[1];

    reg pulse_enable;
    reg tck_enable;

    always @(*)
    begin
        if (!gclk)
        begin
            pulse_enable = (state == S_OSC0) | (state == S_OSC1) | (state == S_APPL);
        end
    end

    always @(*)
    begin
        if (!tck)
        begin
            tck_enable = (state == S_SCAN);
        end
    end

    assign clk = (tck_enable & tck) | (pulse_enable & gclk);

endmodule
