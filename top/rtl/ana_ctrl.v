`default_nettype none

module ana_ctrl (
    input  wire       prim_clk,
    input  wire       prim_rstb,
    input  wire       atpg,
    // control
    input  wire       trig,
    // adc interface
    input  wire       ms_adc_eoc,
    output wire       ms_adc_soc,
    output wire       ms_adc_clk,
    // analog front end
    output wire [3:0] ms_afe_sel,
    output wire [3:0] ms_afe_phase,
    output wire       ms_afe_phase_update,
    // digital post proc
    output reg  [2:0] meas_state,
    output reg  [3:0] meas_phase,
    output wire       meas_eoc_p,
    output wire       meas_eop
);

    localparam [2:0] S_INIT  = 3'b000;
    localparam [2:0] S_ENV_T = 3'b001;
    localparam [2:0] S_MAG_X = 3'b011;
    localparam [2:0] S_MAG_Y = 3'b111;
    localparam [2:0] S_MAG_Z = 3'b110;
    localparam [2:0] S_ENV_V = 3'b100;

    reg [3:0] counter;
    reg [1:0] sync_eoc;
    reg [3:0] afe_sel;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            meas_state <= S_INIT;
        end else
        begin
            case(meas_state)
                S_INIT : meas_state <= (trig    ) ? S_ENV_T : S_INIT;
                S_ENV_T: meas_state <= (meas_eop) ? S_MAG_X : S_ENV_T;
                S_MAG_X: meas_state <= (meas_eop) ? S_MAG_Y : S_MAG_X;
                S_MAG_Y: meas_state <= (meas_eop) ? S_MAG_Z : S_MAG_Y;
                S_MAG_Z: meas_state <= (meas_eop) ? S_ENV_V : S_MAG_Z;
                S_ENV_V: meas_state <= (meas_eop) ? S_INIT  : S_ENV_V;
                default: meas_state <= S_INIT;
            endcase
        end 
    end

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            meas_phase <= 4'b0000;
        end else if ((meas_state == S_INIT) && trig)
        begin
            meas_phase <= 4'b0001;
        end else
        begin
            meas_phase <= (meas_eoc_p || meas_eop) ? {meas_phase[2:0], meas_phase[3]} : meas_phase;
        end
    end

    reg phase_update;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            phase_update <= 1'b0;
        end else
        begin
            phase_update <= ((meas_state == S_INIT) & trig) | meas_eoc_p | meas_eop;
        end
    end

    assign ms_afe_phase = meas_phase & {4{~atpg}};
    assign ms_afe_phase_update = phase_update & ~atpg;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            sync_eoc <= 2'b11;
        end else
        begin
            sync_eoc <= {sync_eoc[0], ms_adc_eoc};
        end
    end

    assign meas_eop   = sync_eoc[0] & !sync_eoc[1] &  meas_phase[3];
    assign meas_eoc_p = sync_eoc[0] & !sync_eoc[1] & !meas_phase[3];

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            counter <= 'd0;
        end else if (counter == 'd0)
        begin
            counter <= 'd15; // conversion time
        end else
        begin
            counter <= counter - 'd1;
        end
    end

    always @(*)
    begin
        case(meas_state)
            S_ENV_V: afe_sel = 4'd1;
            S_ENV_T: afe_sel = 4'd2;
            S_MAG_X: afe_sel = 4'd4;
            S_MAG_Y: afe_sel = 4'd5;
            S_MAG_Z: afe_sel = 4'd6;
            default: afe_sel = 4'd0;
        endcase
    end

    assign ms_afe_sel = afe_sel & {4{~atpg}};
    assign ms_adc_soc = (counter[3:0] == 'd9) & ~atpg;
    assign ms_adc_clk = prim_clk;

endmodule

`default_nettype wire
