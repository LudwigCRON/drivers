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
        
        `CHIP.HPA.B = 5E-3;
        `CHIP.HPB.B = 5E-3;
        repeat(10)
        begin
            `CHIP.Tj = 233.15;
            repeat(10)
            begin
                #(30us);
                `CHIP.Tj += 13.5;
            end
            `CHIP.HPA.B += 5E-3;
            `CHIP.HPB.B += 5E-3;
        end

        #(100us);
        
        $finish(0);
    end

endmodule
