`resetall
`timescale 1ns/100ps

`define TB           testcase.testbench
`define CHIP         `TB.chip
`define DIG          `CHIP.digital
`define TAP_MASTER   `TB.tap_master

module testcase;

    parameter integer LENGTH = 'd10;

    testbench testbench();

    initial
    begin: timeout
        #(100ms);
        $fatal(0, "Unexpected timeout!");
    end

    real VINDA, VINDB;

    always @(negedge `CHIP.ms_afe_phase_update)
    begin
        VINDA = `CHIP.VHALLAP - `CHIP.VHALLAN;
        VINDB = `CHIP.VHALLBP - `CHIP.VHALLBN;
    end

    initial
    begin: scenario
        $dumpvars(0);

        $display("INFO: Ramping up to 3.3V");
        `TB.PowerRamp(3.3, 100us);
        #(100us);
        
        `CHIP.HPA.B = 20E-3;
        `CHIP.HPB.B = 20E-3;
        `CHIP.Tj = 233.15;
        repeat(60)
        begin
            #(30us);
            `CHIP.Tj += 135/60;
        end

        #(100us);
        
        $finish(0);
    end

endmodule
