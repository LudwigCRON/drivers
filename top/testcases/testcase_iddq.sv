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

        $display("INFO: Enter Iddq mode");
        `TAP_MASTER.EnterAtpg(LENGTH, `TAP_MASTER.MODE_IDDQ);
        repeat (LENGTH)
            `TAP_MASTER.SendBit($urandom() % 2);

        #(100us);
        
        $finish(0);
    end

endmodule
