`timescale 1ns/10ps

module chip (
    input  real       VDD,
    input  real       VSS,
    input  wire       TCK,
    input  wire       TDI,
    output wire       TDO,
    input  wire       TRSTB,
    input  wire       URX,
    output wire       UTX
);

    real Tj = 300.0;

    // supply system modelling
    real VDDD;
    wire PORB;
    wire hporb;
    always forever
    begin
        #10;
        if (VDD - VSS > 1.2)
            VDDD = (VDD - VSS) * 1.5 / 3.3 + VSS;
        else
            VDDD = VDD;
    end

    assign PORB = (VDD - VSS > 2.8) ? 1'b1 : 1'b0;
    assign hporb = (VDDD - VSS > 1.2) ? 1'b1 :  1'b0;

    
    // oscillator modelling
    reg ms_osc;
    always forever
    begin
        ms_osc = 1'b0;
        #25;
        if (ms_hporb) ms_osc = 1'b1;
        #25;
    end

    // signal path
    // hall plates
    wire [3:0] ms_afe_phase;
    wire       ms_afe_phase_update;

    real VHALLAP, VHALLAN;
    real VHALLBP, VHALLBN;

    hallplate #(
        .MODE (0) // 0: Voltage biased    1: Current biased
    ) HPA (
        .Tj            (Tj),
        // for current biased model
        .IHall         (500E-6),
        // for voltage biased model
        .VDDH          (VDD),
        .VSSH          (VSS),
        // spinning connections (becareful with overlapping not modelled)
        .phases        (ms_afe_phase),
        .phases_update (ms_afe_phase_update),
        // outputs
        .Va            (VHALLAP),
        .Vb            (VHALLAN)
    );

    hallplate #(
        .MODE (1) // 0: Voltage biased    1: Current biased
    ) HPB (
        .Tj            (Tj),
        // for current biased model
        .IHall         (500E-6),
        // for voltage biased model
        .VDDH          (VDD),
        .VSSH          (VSS),
        // spinning connections (becareful with overlapping not modelled)
        .phases        (ms_afe_phase),
        .phases_update (ms_afe_phase_update),
        // outputs
        .Va            (VHALLBP),
        .Vb            (VHALLBN)
    );

    // temperature
    real VTEMPP, VTEMPN;

    assign VTEMPN = VSS;
    assign VTEMPP = 1.7E-3 * (Tj - 300) + 0.6;

    // mux sel
    wire [3:0] ms_afe_sel;

    always @(*)
    begin
        case(ms_afe_sel)
            'd1: begin VINP = (VDD + VSS) * 0.25; VINN = VSS; end
            'd2: begin VINP = VTEMPP; VINN = VTEMPN; end
            'd4: begin VINP = VHALLAP; VINN = VHALLAN; end
            'd5: begin VINP = VHALLBP; VINN = VHALLBN; end
            'd6: begin VINP = (VHALLAP + VHALLBP) * 0.5; VINN = (VHALLAN + VHALLBN) * 0.5; end
            default: begin VINP = (VDD + VSS) * 0.5; VINN = (VDD + VSS) * 0.5; end
        endcase
    end

    // adc
    real VINP;
    real VINN;
    real VREF;

    assign VREF = VDD;

    wire       ms_adc_soc;
    reg        ms_adc_eoc;
    reg [10:0] adc_state;
    reg [11:0] ms_adc_data;

    always @(negedge ms_adc_clk, negedge ms_hporb)
    begin
        if (!ms_hporb)
            ms_adc_eoc <= 1'b0;
        else if (ms_adc_soc)
            ms_adc_eoc <= 1'b0;
        else if (adc_state == 'd1)
        begin
            ms_adc_eoc <= 1'b1;
            ms_adc_data <= 4095 * (VINP - VINN) / VREF;
        end
    end

    always @(negedge ms_adc_clk, negedge ms_hporb)
    begin
        if (!ms_hporb)
            adc_state <= 'd0;
        else if (ms_adc_soc)
            adc_state <= 1 << 10;
        else
            adc_state <= adc_state >> 1;
    end
    
    // levelshifters
    and g_lvlshft_hporb (ms_hporb, hporb, PORB);
    and g_lvlshft_trstb (ms_trstb, TRSTB, PORB);
    and g_lvlshft_tck   (ms_tck, TCK, PORB);
    and g_lvlshft_tdi   (ms_tdi, TDI, PORB);

    and g_lvlshft_tdo   (TDO, ms_tdo, PORB);


    top digital (
        // supply system
        .ms_osc              (ms_osc             ),
        .ms_hporb            (ms_hporb           ),
        // tap interface
        .ms_trstb            (ms_trstb           ),
        .ms_tck              (ms_tck             ),
        .ms_tdi              (ms_tdi             ),
        .ms_tdo              (ms_tdo             ),
        .ms_tde              (                   ),
        // adc interface
        .ms_adc_eoc          (ms_adc_eoc         ),
        .ms_adc_data         (ms_adc_data        ),
        .ms_adc_soc          (ms_adc_soc         ),
        .ms_adc_clk          (ms_adc_clk         ),
        .ms_afe_sel          (ms_afe_sel         ),
        .ms_afe_phase        (ms_afe_phase       ),
        .ms_afe_phase_update (ms_afe_phase_update),
        // uart
        .ms_urx              (        ),
        .ms_utx              (        )
    );


endmodule