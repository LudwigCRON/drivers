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

    initial
    begin: scenario
        $dumpvars(0);

        $display("INFO: Ramping up to 3.3V");
        `TB.PowerRamp(3.3, 100us);
        #(100us);

        $display("INFO: Enter Stuck mode");
        `TAP_MASTER.EnterAtpg(LENGTH, `TAP_MASTER.MODE_STUCK);
        // add 2 for resync of pulse generation
        repeat (LENGTH + 2)
            `TAP_MASTER.SendBit($urandom() % 2);

        repeat(8)
        begin
            // measure
            #(10us);
            // scan out result while scanin
            repeat (LENGTH + 4)
                `TAP_MASTER.SendBit(1'b0);
        end

        #(100us);

        $finish(0);
    end

endmodule
