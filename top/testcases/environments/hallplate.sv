// model based on https://www.mdpi.com/1424-8220/11/6/6284
`timescale 1ns/10ps

module hallplate #(
    parameter bit MODE = 0 // 0: Voltage biased    1: Current biased
) (
    input  real Tj,
    // for current biased model
    input  real IHall,
    // for voltage biased model
    input  real VDDH,
    input  real VSSH,
    // spinning connections (becareful with overlapping not modelled)
    input  wire [3:0] phases,
    input  wire       phases_update,
    // outputs
    output real Va,
    output real Vb
);

    `define NaN $bitstoreal(64'b1111111111111000000000000000000000000000000000000000000000000000)

    // avoid non overlapping
    wire phases_updated_delayed;
    wire blind;
    wire [3:0] dphases;
    wire [3:0] bphases;

    not  #2 g_dly2     (phases_updated_delayed, phases_update);
    buf  #1 g_dly[3:0] (dphases, phases);
    nand #1 g_blind    (blind, phases_update, phases_updated_delayed);
    and  #1 g_bph[3:0] (bphases, dphases, {4{blind}});

    // core 
    parameter real THICKNESS = 10E-6;
    parameter real RH0       = 5000.0;
    parameter real T_0       = 300.0;

    real B;
    real Rhall;
    real alpha;
    
    assign Rhall = 1/(1.6E-19 * 1E22 * (Tj/T_0)**-1.5);
    assign alpha = 2*0.7*Rhall/(RH0 * THICKNESS); // 2*G*Rhall/RH0/THICKNESS ~ 1/Tesla

    initial
    begin
        B = 5E-3; // Tesla
    end

    // current biased modelling with hall effect
    // as variation of the resistivity
    function automatic real RH12(input real B = 5E-3, input real T = 300);
        return RH0 * (1 + alpha * B) * (T_0/T)**1.5;
    endfunction

    function automatic real RH14(input real B = 5E-3, input real T = 300);
        return RH0 * (1 - alpha * B) * (T_0/T)**1.5;
    endfunction

    function automatic real RH23(input real B = 5E-3, input real T = 300);
        return RH0 * (1 - alpha * B) * (T_0/T)**1.5;
    endfunction
    
    function automatic real RH43(input real B = 5E-3, input real T = 300);
        return RH0 * (1 + alpha * B) * (T_0/T)**1.5;
    endfunction

    function automatic real min(input real VA, input real VB);
        if (VA < VB)
            return VA;
        return VB;
    endfunction


    real RH;
    real Vmid_l;
    real Vmid_r;
    real V1;
    real V2;
    real V3;
    real V4;

    assign RH = bphases[0] ? (RH12(B, Tj) + RH23(B, Tj)) * (RH14(B, Tj) + RH43(B, Tj))/(RH12(B, Tj) + RH23(B, Tj) + RH14(B, Tj) + RH43(B, Tj)) :
                bphases[1] ? (RH23(B, Tj) + RH43(B, Tj)) * (RH12(B, Tj) + RH14(B, Tj))/(RH12(B, Tj) + RH23(B, Tj) + RH14(B, Tj) + RH43(B, Tj)) :
                bphases[2] ? (RH12(B, Tj) + RH23(B, Tj)) * (RH14(B, Tj) + RH43(B, Tj))/(RH12(B, Tj) + RH23(B, Tj) + RH14(B, Tj) + RH43(B, Tj)) :
                bphases[3] ? (RH23(B, Tj) + RH43(B, Tj)) * (RH12(B, Tj) + RH14(B, Tj))/(RH12(B, Tj) + RH23(B, Tj) + RH14(B, Tj) + RH43(B, Tj)) : `NaN;

    assign Vmid_l = bphases[0] ? (V1/RH12(B, Tj) + V3/RH23(B, Tj))/(1/RH12(B, Tj)+1/RH23(B, Tj)) :
                    bphases[1] ? (V2/RH23(B, Tj) + V4/RH43(B, Tj))/(1/RH23(B, Tj)+1/RH43(B, Tj)) :
                    bphases[2] ? (V1/RH14(B, Tj) + V3/RH43(B, Tj))/(1/RH14(B, Tj)+1/RH43(B, Tj)) :
                    bphases[3] ? (V2/RH12(B, Tj) + V4/RH14(B, Tj))/(1/RH12(B, Tj)+1/RH14(B, Tj)) : `NaN;
    
    assign Vmid_r = bphases[0] ? (V1/RH14(B, Tj) + V3/RH43(B, Tj))/(1/RH14(B, Tj)+1/RH43(B, Tj)) :
                    bphases[1] ? (V2/RH12(B, Tj) + V4/RH14(B, Tj))/(1/RH12(B, Tj)+1/RH14(B, Tj)) :
                    bphases[2] ? (V1/RH12(B, Tj) + V3/RH23(B, Tj))/(1/RH12(B, Tj)+1/RH23(B, Tj)) :
                    bphases[3] ? (V2/RH23(B, Tj) + V4/RH43(B, Tj))/(1/RH23(B, Tj)+1/RH43(B, Tj)) : `NaN;


    generate
        if (MODE > 0)
        begin: current_mode
            assign V1 = bphases[0] ? min(IHall * RH, VDDH) :
                        bphases[1] ? Vmid_l                :
                        bphases[2] ? 0.0                   :
                        bphases[3] ? Vmid_r                : `NaN;
            assign V2 = bphases[0] ? Vmid_l                :
                        bphases[1] ? min(IHall * RH, VDDH) :
                        bphases[2] ? Vmid_r                :
                        bphases[3] ? 0.0                   : `NaN;
            assign V3 = bphases[0] ? 0.0                   :
                        bphases[1] ? Vmid_r                :
                        bphases[2] ? min(IHall * RH, VDDH) :
                        bphases[3] ? Vmid_l                : `NaN;
            assign V4 = bphases[0] ? Vmid_r                :
                        bphases[1] ? 0.0                   :
                        bphases[2] ? Vmid_l                :
                        bphases[3] ? min(IHall * RH, VDDH) : `NaN;

        end else
        begin: voltage_mode

            assign V1 = bphases[0] ? VDDH       :
                        bphases[1] ? Vmid_l     :
                        bphases[2] ? VSSH       :
                        bphases[3] ? Vmid_r     : `NaN;
            assign V2 = bphases[0] ? Vmid_l     :
                        bphases[1] ? VDDH       :
                        bphases[2] ? Vmid_r     :
                        bphases[3] ? VSSH       : `NaN;
            assign V3 = bphases[0] ? VSSH       :
                        bphases[1] ? Vmid_r     :
                        bphases[2] ? VDDH       :
                        bphases[3] ? Vmid_l     : `NaN;
            assign V4 = bphases[0] ? Vmid_r     :
                        bphases[1] ? VSSH       :
                        bphases[2] ? Vmid_l     :
                        bphases[3] ? VDDH       : `NaN;

        end
    endgenerate

    assign Va = bphases[0] ? V2 :
                bphases[1] ? V1 :
                bphases[2] ? V4 :
                bphases[3] ? V3 : `NaN;
    assign Vb = bphases[0] ? V4 :
                bphases[1] ? V3 :
                bphases[2] ? V2 :
                bphases[3] ? V1 : `NaN;

endmodule
