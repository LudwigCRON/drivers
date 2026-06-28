`resetall
`timescale 1ns/1ns

`define TB           testcase.testbench

module testcase;

    int i;

    testbench testbench();

    initial
    begin: timeout
        #(100ms);
        $fatal(0, "Unexpected timeout!");
    end

    initial
    begin: scenario
        $dumpvars(0);

        $display("INFO: Reset");
        `TB.Reset();

        $display("INFO: Ramp test");
        i = 0;
        repeat(128)
        begin
            `TB.Run(1, i);
            i++;
        end

        $display("INFO: Abort test");
        fork
            begin
                `TB.Run(1, 20, 1);
            end
            begin
                repeat(8) @(posedge `TB.prim_clk) #1;
                `TB.wut_disable = 1;
                @(posedge `TB.prim_clk) #1;
                if (!`TB.wut_trig_it)
                    $error("ERROR: expected a trigger to be generated on abort");
            end
        join

        $display("INFO: Randomized test");
        repeat(128)
        begin
            `TB.Random(1);
            #(1us);
        end       

        $display("INFO: Randomized test with disable");
        repeat(16)
        begin
            `TB.Random(0);
            #(1us);
        end
        
        $finish(0);
    end

endmodule
