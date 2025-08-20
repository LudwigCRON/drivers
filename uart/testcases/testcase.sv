
`timescale 1ns/100ps

module testcase;

    wire [7:0] uart_rx_data;
    wire       uart_rx_new_it;
    wire       uart_rx_par_it;
    wire       uart_rx_frm_it;
    wire       urx;

    reg        clk;
    reg        rstb;

    int        i;

    wire VDD;
    wire VSS;

    assign VDD = 1'b1;
    assign VSS = 1'b0;

    always forever
    begin
        clk = 1'b1;
        #(drv.PERIOD * 0.1);
        clk = 1'b0;
        #(drv.PERIOD * 0.1);
    end

    uart_cfg cfg();

    uart_driver drv (
        .VDD       (VDD),
        .VSS       (VSS),
        .URX       (1'b1),
        .UTX       (urx),
        .PULLUP_EN (1'b1)
    );

    uart rx (
        .clk             (clk),
        .rstb            (rstb),
        .atpg_rst_ctrl   (1'b0),
        .cfg_clk_div     (9'd4),
        .cfg_has_parity  (cfg.has_parity),
        .cfg_odd_parity  (cfg.odd_parity),
        .cfg_extend_stop (cfg.extend_stop),
        .cfg_lsb_first   (cfg.lsb_first),
        .cfg_word        (cfg.word),
        .uart_rx_data    (uart_rx_data),
        .uart_rx_new_it  (uart_rx_new_it),
        .uart_rx_par_it  (uart_rx_par_it),
        .uart_rx_frm_it  (uart_rx_frm_it),
        .ms_urx          (urx)
    );

    initial
    begin: timeout
        #(10ms);
        $error("Unexpected Timeout!");
        $finish(2);
    end

    initial
    begin: scenario
        $dumpfile("waves.fst");
        $dumpvars(0);

        rstb = 1'b0;
        #(10us);
        rstb = 1'b1;

        #(drv.PERIOD);

        drv.SendByte(8'hCA);
        drv.SendByte(8'h53);
        #(30us);
        drv.LSB_FIRST = 1;
        cfg.lsb_first = 1'b1;
        drv.SendByte(8'hCA);
        drv.SendByte(8'h53);

        #(10us);

        drv.tx_buffer[0] = 8'h80;
        drv.tx_buffer[1] = 8'h50;
        drv.tx_buffer[2] = 8'h41;
        drv.tx_buffer[3] = 8'hF8;
        i = 0;
        fork
            begin
                drv.SendFrame('d4);
            end
            begin
                repeat(4)
                begin
                    @(posedge clk) #1;
                    while (!uart_rx_new_it)
                    begin
                        @(posedge clk) #1;
                    end
                    @(posedge clk) #1;
                    if (drv.tx_buffer[i] !== uart_rx_data[7:0])
                        $error("Expected %04X Get %04X", drv.tx_buffer[i], uart_rx_data[7:0]);
                    i++;
                end
            end
        join

        drv.ReceiveFrame('d2);
        
        #(10us);

        $finish(0);

    end

endmodule