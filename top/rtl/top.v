`default_nettype none

module top (
    // supply system
    input  wire        ms_osc,
    input  wire        ms_hporb,
    // tap interface
    input  wire        ms_trstb,
	input  wire        ms_tck,
	input  wire        ms_tdi,
	output wire        ms_tdo,
	output wire        ms_tde,
    // adc interface
    input  wire        ms_adc_eoc,
    input  wire [11:0] ms_adc_data,
    output wire        ms_adc_soc,
    output wire        ms_adc_clk,
    output wire [ 3:0] ms_afe_sel,
    output wire [ 3:0] ms_afe_phase,
    output wire        ms_afe_phase_update,
    // uart
    input  wire        ms_urx,
    output wire        ms_utx
);

    wire [ 6:0] prim_div;
    wire        prim_dis;
    wire        prim_clk;
    wire        prim_gclk;
    wire        prim_rstb;
    wire        prim_app_active;

    wire [ 6:0] uart_div;
    wire        uart_dis;
    wire        uart_clk;
    wire        uart_gclk;
    wire        uart_rstb;
    wire        uart_app_active;

    wire        tscan_start;
    wire        tscan_end;
    wire        tscan_exe;
    wire        tscan_enable;
    wire        tapp_active;
    wire        tprim_burst_done;
    wire        tuart_burst_done;
    wire        texe_done;

    wire [ 2:0] meas_state;
    wire [ 3:0] meas_phase;
    wire [11:0] meas_data;
    wire        meas_data_p;
    wire        meas_eoc_p;
    wire        meas_eop;

    assign prim_div = 'd0;
    assign prim_dis = 1'b0;

    assign uart_div = 'd3;
    assign uart_dis = 1'b0;


    // clock generation
    clock_divider #(
        .MIN_RATIO   	(1  ),
        .MAX_RATIO   	(64 )
    ) prim_clk_div (
        .clk    (ms_osc   ),
        .rstb   (ms_hporb ),
        .div 	(prim_div ),
        .dis 	(prim_dis ),
        .gclk   (prim_gclk),
        .grstb  (prim_rstb)
    );

    clock_divider #(
        .MIN_RATIO   	(1  ),
        .MAX_RATIO   	(64 )
    ) uart_clk_div (
        .clk    (ms_osc   ),
        .rstb   (ms_hporb ),
        .div 	(uart_div ),
        .dis 	(uart_dis ),
        .gclk   (uart_gclk),
        .grstb  (uart_rstb)
    );

    // tap interface
    tap tap (
        .prim_gclk     (prim_gclk),
        .prim_rstb    (prim_rstb),
        // tap interface
        .trstb        (ms_trstb    ),
        .tck          (ms_tck      ),
        .tdi          (ms_tdi      ),
        .tdo          (ms_tdo      ),
        .tde          (ms_tde      ),
        // scan chain interface
        .tscan_end    (tscan_end   ),
        .tscan_start  (tscan_start ),
        // opcg
        .texe_done    (texe_done   ),
        // modes
        .tscan_enable (tscan_enable),
        .tscan_exe    (tscan_exe   ),
        .tapp_active  (tapp_active )
    );

    opcg prim_burst (
        .tck            (ms_tck          ),
        .trstb          (ms_trstb        ),
        .tapp_active    (tapp_active     ),
        .tscan_exe      (tscan_exe       ),
        .texe_done      (tprim_burst_done),
        .gclk           (prim_gclk       ),
        .gclk_rstb      (prim_rstb       ),
        .gclk_app_active(prim_app_active ),
        .clk            (prim_clk        )
    );

    opcg uart_burst (
        .tck            (ms_tck          ),
        .trstb          (ms_trstb        ),
        .tapp_active    (tapp_active     ),
        .tscan_exe      (tscan_exe       ),
        .texe_done      (tuart_burst_done),
        .gclk           (uart_gclk       ),
        .gclk_rstb      (uart_rstb       ),
        .gclk_app_active(uart_app_active ),
        .clk            (uart_clk        )
    );

    assign texe_done = tprim_burst_done & tuart_burst_done;

    // conversion control
    ana_ctrl ana_ctrl (
        .prim_clk            (prim_clk    ),
        .prim_rstb           (prim_rstb   ),
        .atpg                (1'b0        ),
        // control
        .trig                (1'b1        ),
        // adc interface
        .ms_adc_eoc          (ms_adc_eoc  ),
        .ms_adc_soc          (ms_adc_soc  ),
        .ms_adc_clk          (ms_adc_clk  ),
        // analog front end
        .ms_afe_sel          (ms_afe_sel  ),
        .ms_afe_phase        (ms_afe_phase),
        .ms_afe_phase_update (ms_afe_phase_update),
        // digital processing
        .meas_state          (meas_state  ),
        .meas_eoc_p          (meas_eoc_p  ),
        .meas_eop            (meas_eop    )
    );

    // post processing
    dsp dsp (
        .prim_clk          (prim_clk),
        .prim_rstb         (prim_rstb),
        .enable            (1'b1),
        .offset_tref       (8'h00),
        .offset_oref       (8'h23),
        .offset_gain       (8'h40),
        .sensitivity_tref  (8'h00),
        .sensitivity_oref  (8'h00),
        .sensitivity_gain  (8'h40),
        .ms_adc_data       (ms_adc_data),
        .meas_state        (meas_state),
        .meas_phase        (meas_phase),
        .meas_eoc_p        (meas_eoc_p),
        .meas_eop          (meas_eop),
        .meas_data         (meas_data),
        .meas_data_p       (meas_data_p)
    );

endmodule

`default_nettype wire
