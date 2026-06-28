`timescale 1ns/1ns

module testbench;

    logic prim_clk;
    logic prim_rstb;

    logic [8:0] wut_limit;
    logic       wut_disable;
    logic       wut_start_req;
    logic       wut_start_ack;
    logic       wut_trig_it;


    always forever
    begin
        prim_clk = 0;
        #5;
        prim_clk = 1;
        #5;
    end

    wut wut (
        .prim_clk          (prim_clk),
        .prim_rstb         (prim_rstb),
        .wut_limit         (wut_limit),
        .wut_disable       (wut_disable),
        .wut_start_req     (wut_start_req),
        .wut_start_ack     (wut_start_ack),
        .wut_trig_it       (wut_trig_it)
    );

    task Reset();
        prim_rstb = 0;
        wut_disable = 0;
        wut_start_req = 0;
        wut_limit = 0;
        #10;
        repeat(2) @(posedge prim_clk);
        #1 prim_rstb = 1;
    endtask

    task Run(
        input bit enable = 0,
        input int value = 0,
        input bit will_abort = 0
    );
        int count;
        @(posedge prim_clk) #1;
        count = 0;
        wut_limit = value;
        wut_disable = !enable;
        fork
            begin
                wut_start_req = 1;
                while(!wut_start_ack && count < 'd10_000)
                    @(posedge prim_clk);
                wut_start_req = 0;
            end
            begin
                while(!wut_trig_it && count < 'd10_000)
                    @(posedge prim_clk) count += 1;
            end
        join
        if ( wut_disable && !will_abort && count != 'd10_000)
            $error("ERROR: WUT did not reach timeout when disabled");
        if (!wut_disable && count == 'd10_000)
            $error("ERROR: WUT timedout without trigger generation!");
        if (!wut_disable && count != wut_limit + 1)
            $error("ERROR: WUT incorrect timing by %1d clock cycles", $signed(wut_limit - count + 1));
    endtask

    task Random(
        input bit enable = 0
    );
        Run(enable, $urandom());
    endtask

endmodule
