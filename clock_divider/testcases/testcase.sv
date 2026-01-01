`resetall
`timescale 1ns/10ps

module testcase;

    event check_gclk;

    reg  clk;
    reg  rstb;
    reg  dis;
    int  div;
    wire gclk;

    always forever
    begin
        clk = 1'b1;
        #5;
        clk = 1'b0;
        #5;
    end
    
    clock_divider #(
        .MIN_RATIO   	(1  ),
        .MAX_RATIO   	(64 )
    ) dut (
        .clk    (clk  ),
        .rstb   (rstb ),
        .div 	(div  ),
        .dis 	(dis  ),
        .gclk   (gclk )
    );
    

    initial
    begin
        $dumpvars();
        #(100ms);
        $fatal(0, "Unexpected timeout");
    end

    initial
    begin: scenario
        // reset
        rstb = 1'b0;
        dis = 1'b0;
        div = 'd0;

        repeat(50) @(posedge clk);

        // disable
        rstb = 1'b1;
        dis  = 1'b1;

        repeat(50) @(posedge clk);

        div = 'd3;

        repeat(50) @(posedge clk);

        div = 'd4;

        repeat(50) @(posedge clk);

        // check random
        $display("Check random division");
        dis = 1'b0;
        repeat(64)
        begin
            div = $urandom_range(64, 1);
            $display("  - DIV = %3d", div);
            repeat(3) @(posedge gclk);
            ->check_gclk;
            #10; // let some time for check
        end

        $finish(0);
    end

    // frequency ratio
    realtime t_start;
    realtime t_stop;
    realtime t_fall;
    realtime period;
    realtime duty_cycle;

    always @(posedge gclk)
    begin
        t_stop = $realtime();
        period = t_stop - t_start;
        duty_cycle = (t_fall - t_start) / period;
        t_start = t_stop;
    end

    always @(negedge gclk)
    begin
        t_fall = $realtime();
    end

    always @(check_gclk)
    begin
        // check frequency
        if ((period < 10 * div - 2) || (period > 10 * div + 2))
            $error("Wrong generated frequency for DIV=%3d. Get [%.3f] Expected [%.3f]", div, period, 10 * div);
        // check duty cycle
        if ((duty_cycle < 0.49) || (duty_cycle > 0.51))
            $error("Wrong duty cycle for DIV=%3d. Get [%.3f] Expected [0.5]", div, duty_cycle);
    end


endmodule