`default_nettype none

module uart_rx (
    input  wire       clk,
    input  wire       rstb,

    input  wire       uart_ce,
    input  wire       uart_mid,
    output wire       uart_start,

    input  wire       cfg_has_parity,
    input  wire       cfg_odd_parity,
    input  wire       cfg_extend_stop,
    input  wire       cfg_lsb_first,
    input  wire       cfg_word,

    output reg  [7:0] uart_rx_data,
    output wire       uart_rx_new_it,
    output wire       uart_rx_par_it,
    output wire       uart_rx_frm_it,

    input  wire       ms_urx
);

    `include "uart_encoding.vh"

    reg [2:0] fir;
    wire      urx_fall;
    reg       urx_filt;

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            fir[2:0] <= 3'b000;
        else
            fir[2:0] <= {fir[1:0], ms_urx};
    end

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            urx_filt <= 1'b0;
        else
            urx_filt <= (fir[2] & fir[1]) |
                        (fir[2] & fir[0]) |
                        (fir[1] & fir[0]);
    end

    assign urx_fall = fir[2] & !fir[1] & !fir[0];

    reg       word_msb;
    reg [3:0] rx_state;
    reg [3:0] next_rx_state;

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            rx_state[3:0] <= S_RX_IDLE;
        else if (urx_fall && rx_state == S_RX_IDLE)
            rx_state[3:0] <= S_RX_START;
        else if (uart_ce)
            rx_state[3:0] <= next_rx_state[3:0];
    end

    always @(*)
    begin
        case(rx_state[3:0])
            S_RX_IDLE  : next_rx_state = (urx_fall) ? S_RX_START : S_RX_IDLE;
            S_RX_START : next_rx_state = S_RX_DATA0;
            S_RX_DATA0 : next_rx_state = S_RX_DATA1;
            S_RX_DATA1 : next_rx_state = S_RX_DATA2;
            S_RX_DATA2 : next_rx_state = S_RX_DATA3;
            S_RX_DATA3 : next_rx_state = S_RX_DATA4;
            S_RX_DATA4 : next_rx_state = S_RX_DATA5;
            S_RX_DATA5 : next_rx_state = S_RX_DATA6;
            S_RX_DATA6 : next_rx_state = S_RX_DATA7;
            S_RX_DATA7 : next_rx_state = (cfg_word && !word_msb) ? S_RX_DATA0  :
                                         (cfg_has_parity       ) ? S_RX_PARITY : S_RX_STOP0;
            S_RX_PARITY: next_rx_state = S_RX_STOP0;
            S_RX_STOP0 : next_rx_state = (cfg_extend_stop      ) ? S_RX_STOP1  :
                                         (urx_fall) ? S_RX_START : S_RX_IDLE;
            S_RX_STOP1 : next_rx_state = (urx_fall) ? S_RX_START : S_RX_IDLE;
            default    : next_rx_state = S_RX_IDLE;
        endcase
    end

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            word_msb <= 1'b0;
        else if (uart_ce)
            if (rx_state == S_RX_IDLE)
                word_msb <= 1'b0;
            else if (rx_state == S_RX_DATA7)
                word_msb <= ~word_msb;
    end

    assign uart_start = urx_fall & (rx_state == S_RX_IDLE);


    assign uart_rx_new_it = (rx_state == S_RX_DATA7) & uart_mid;
    assign uart_rx_frm_it = ((rx_state == S_RX_STOP0) | (rx_state == S_RX_STOP1)) & !fir[0] & uart_mid;
    assign uart_rx_par_it = (rx_state == S_RX_PARITY) & (^rx_data ^ urx_filt ^ cfg_odd_parity) & cfg_has_parity & uart_mid;

    reg [7:0] rx_data;
    wire rx_shift;

    assign rx_shift = (rx_state >= S_RX_DATA0) && (rx_state <= S_RX_DATA7);

    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            rx_data[7:0] <= 8'h00;
        else if (uart_mid && rx_shift)
            rx_data[7:0] <= {rx_data[6:0], urx_filt};
    end
    
    always @(posedge clk, negedge rstb)
    begin
        if (!rstb)
            uart_rx_data[7:0] <= 8'h00;
        else if (uart_mid && (rx_state == S_RX_DATA7))
            uart_rx_data[7:0] <= {
                (cfg_lsb_first) ? urx_filt   : rx_data[6],
                (cfg_lsb_first) ? rx_data[0] : rx_data[5],
                (cfg_lsb_first) ? rx_data[1] : rx_data[4],
                (cfg_lsb_first) ? rx_data[2] : rx_data[3],
                (cfg_lsb_first) ? rx_data[3] : rx_data[2],
                (cfg_lsb_first) ? rx_data[4] : rx_data[1],
                (cfg_lsb_first) ? rx_data[5] : rx_data[0],
                (cfg_lsb_first) ? rx_data[6] : urx_filt
            };
    end

endmodule

`default_nettype wire
