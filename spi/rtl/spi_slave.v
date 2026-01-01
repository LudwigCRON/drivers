`default_nettype none

module spi_slave #(
    parameter integer DATA_WIDTH = 'd8
) (
    input  wire        clk,
    input  wire        rstb,
    input  wire        atpg,
    input  wire        atpg_rst_control,

    // configuration
    input  wire        cfg_enable,
    input  wire        cfg_lsb_first,
    input  wire [ 1:0] cfg_mode,

    // standard interface for high level
    input  wire [ 7:0] spi_slave_tx_data,
    input  wire        spi_slave_tx_empty_it,
    output wire [ 7:0] spi_slave_rx_data,
    output wire        spi_slave_rx_new_it,
    output wire        spi_slave_rx_par_it,
    output wire        spi_slave_rx_frm_it,

    // IOs
    input  wire        ms_csb,
    input  wire        ms_sclk,
    input  wire        ms_mosi,
    output wire        ms_miso
);

    // clock and reset generation
    reg  spi_gclk;
    wire spi_clk;
    wire spi_rstb;

    wire [3:0] spi_mode_gclk;
    reg  [1:0] spi_cfg_mode;
    reg        spi_cfg_lsb_first;

    reg  [8:0] shift_register;
    reg  [7:0] rx_data;
    reg  [2:0] counter;

    always @(posedge spi_clk, negedge spi_rstb)
    begin
        if (!spi_rstb)
        begin
            spi_cfg_mode[1:0] <= 2'b00;
            spi_cfg_lsb_first <= 1'b0;
        end else if (ms_csb)
            spi_cfg_mode[1:0] <= cfg_mode[1:0];
            spi_cfg_lsb_first <= cfg_lsb_first;
    end

    assign spi_mode_gclk[0] =  ms_sclk; // sample rising edge, send falling edge
    assign spi_mode_gclk[1] = ~ms_sclk; // sample falling edge, send rising edge
    assign spi_mode_gclk[2] = ~ms_sclk; // sample falling edge, send rising edge
    assign spi_mode_gclk[3] =  ms_sclk; // sample rising edge, send falling edge

    always @(*)
    begin
        case(spi_cfg_mode)
            2'b00: spi_gclk = spi_mode_gclk[0];
            2'b01: spi_gclk = spi_mode_gclk[1];
            2'b10: spi_gclk = spi_mode_gclk[2];
            2'b11: spi_gclk = spi_mode_gclk[3];
        endcase
    end

    assign spi_clk  = (atpg) ? clk : spi_gclk;
    assign spi_rstb = (rstb & ~ms_csb) | atpg_rst_control;

    // shift register
    always @(posedge spi_clk, negedge spi_rstb)
    begin
        if (!spi_rstb)
            shift_register[8:0] <= 9'd0;
        else if (counter[2:0] == 'd7)
            shift_register[8:0] <= {
                spi_slave_tx_data[0],
                spi_slave_tx_data[1],
                spi_slave_tx_data[2],
                spi_slave_tx_data[3],
                spi_slave_tx_data[4],
                spi_slave_tx_data[5],
                spi_slave_tx_data[6],
                spi_slave_tx_data[7], ms_mosi};
        else
            shift_register[8:0] <= {shift_register[7:0], ms_mosi};
    end

    assign ms_miso = shift_register[8];

    always @(posedge spi_clk, negedge spi_rstb)
    begin
        if (!spi_rstb)
            counter[2:0] <= 3'h0;
        else if (cfg_enable)
            counter[2:0] <= counter[2:0] + 3'd1;
    end

    always @(posedge spi_clk, negedge spi_rstb)
    begin
        if (!spi_rstb)
            rx_data[7:0] <= 8'h00;
        else if (counter[2:0] == 3'h7)
            rx_data[7:0] <= {shift_register[6:0], ms_mosi};
    end

    assign spi_slave_rx_data   = rx_data;

    handshake_2states #(.L(2)) resync_rx_it (
        .src_clk    (spi_clk),
        .src_rstb   (rstb),
        .src_req_it (counter[2:0] == 3'd7),
        .src_ack_it (),
        .dst_clk    (clk),
        .dst_rstb   (rstb),
        .dst_req_it (spi_slave_rx_new_it),
        .dst_ack_it (spi_slave_rx_new_it)  // hors end of dma access
    );

endmodule


`default_nettype wire

