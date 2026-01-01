
`timescale 1ns/100ps

module testcase;

    reg         tck;
    reg         trstb;
    reg         tdi;
    wire        tdo;
    wire        tde;

    wire        texe_done;
    wire        tscan_enable;
    wire        tscan_end;
    wire        tscan_start;
    int         datain;
    reg  [11:0] dummy_scanchain;

    reg         osc0;
    reg         osc1;
    reg         hporb;
    reg         osc0_rstb;
    reg         osc1_rstb;
    wire        clk0;
    wire        clk1;

    tap_master master (
        .tck   (tck),
        .tdi   (tdi),
        .tdo   (tdo),
        .trstb (trstb)
    );

    tap tap (
        // tap interface
        .trstb        (trstb      ),
        .tck          (tck        ),
        .tdi          (tdi        ),
        .tdo          (tdo        ),
        .tde          (tde        ),
        // scan chain interface
        .tscan_end    (tscan_end  ),
        .tscan_start  (tscan_start),
        // opcg
        .texe_done    (texe_done0 & texe_done1),
        // modes
        .tscan_enable (tscan_enable),
        .tscan_exe    (tscan_exe   ),
        .tapp_active  (tapp_active )
    );

    opcg opcg0 (
        .tck             (tck            ),
        .trstb           (trstb          ),
        .tscan_exe       (tscan_exe      ),
        .texe_done       (texe_done0     ),
        .tapp_active     (tapp_active    ),
        .gclk            (osc0           ),
        .gclk_rstb       (osc0_rstb      ),
        .gclk_app_active (osc0_app_active),
        .clk             (clk0)
    );

    opcg opcg1 (
        .tck             (tck            ),
        .trstb           (trstb          ),
        .tscan_exe       (tscan_exe      ),
        .texe_done       (texe_done1     ),
        .tapp_active     (tapp_active    ),
        .gclk            (osc1           ),
        .gclk_rstb       (osc1_rstb      ),
        .gclk_app_active (osc1_app_active),
        .clk             (clk1)
    );

    always forever
    begin
        osc0 = 1'b1;
        #(190ns);
        osc0 = 1'b0;
        #(190ns);
    end

    always forever
    begin
        osc1 = 1'b1;
        #(19ns);
        osc1 = 1'b0;
        #(19ns);
    end

    // ideally should be 3 DFFs
    always @(posedge osc0, negedge hporb)
    begin
        if (!hporb)
            osc0_rstb <= 1'b0;
        else
            osc0_rstb <= 1'b1;
    end

    always @(posedge osc1, negedge hporb)
    begin
        if (!hporb)
            osc1_rstb <= 1'b0;
        else
            osc1_rstb <= 1'b1;
    end

    always @(posedge clk0)
    begin
        if (tscan_enable)
            dummy_scanchain <= {dummy_scanchain[10:0], tscan_start};
    end

    assign tscan_end = dummy_scanchain[11];

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

        hporb = 1'b0;

        #(5us);

        hporb = 1'b1;

        #(5us);

        $display("STEP: Reset the tap interface");
        master.Reset();
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be reset in exe phase");
        if (tscan_enable != 1'b0)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is the default value: 0
        if (tdo || tde)
            $error("Expect nothing to be sent while in reset");

        #(10us);

        $display("STEP: Set an incorrect key after reset");
        master.SetKey(8'hA5);
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be in exe phase");
        if (tscan_enable != 1'b0)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is still the default value: 0
        if (tdo || tde)
            $error("Expect nothing to be sent while in reset");

        $display("STEP: Send a correct key after a wrong one");
        master.SendByte(8'h96);
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be in exe phase");
        if (tscan_enable != 1'b0)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is still the default value: 0
        if (tdo || tde)
            $error("Expect nothing to be sent while in reset");

        $display("STEP: Set a correct key after reset");
        master.SetKey(8'h96);
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be in exe phase");
        if (tscan_enable != 1'b0)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is still the default value: 0
        if (tdo || tde)
            $error("Expect nothing to be sent while in reset");

        #(10us);

        $display("STEP: Enter in IDDq mode ready to stream");
        master.EnterAtpg('d4, master.MODE_IDDQ);
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be in exe phase");
        if (tscan_enable != 1'b1)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is still the default value: 0
        if (!tde)
            $error("Expect ready to stream data out");
        // check content of the scan chain
        if (dummy_scanchain[11:0] != 11'hXXXX)
            $error("Expected the scan chain not to contain any bits");

        $display("STEP: Stream a pattern an IDDq");
        datain = 16'hBEEF;
        for(int i = 5; i > 0; i--)
        begin
            master.SendBit(datain[10+i]);
        end
        // check flags provided to other digital blocks
        if (tscan_exe != 1'b0)
            $error("Expected not to be in exe phase");
        if (tscan_enable != 1'b1)
            $error("Expected not to be reset in scan phase");
        if (tapp_active != 1'b0)
            $error("Expected to be reset in initialization mode not in application");
        // check tdo is still the default value: 0
        if (!tde)
            $error("Expect streaming data out");
        // check content of the scan chain
        if (dummy_scanchain[11:0] != 12'hXX7)
            $error("Expected the scan chain to be 0xXX7");
        
        #(1us);

        for(int i = 7; i > 0; i--)
        begin
            master.SendBit(datain[3+i]);
            // check flags provided to other digital blocks
            if (tscan_exe != 1'b0)
                $error("Expected not to be in exe phase");
            if (tscan_enable != 1'b1)
                $error("Expected not to be reset in scan phase");
            if (tapp_active != 1'b0)
                $error("Expected to be reset in initialization mode not in application");
            // check tdo is still the default value: 0
            if (!tde)
                $error("Expect to be sending bit stream");
        end
        // check content of the scan chain
        if (dummy_scanchain[11:0] != 12'hBEE)
            $error("Expected the scan chain to be 0xBEE");


        #(10us);

        master.EnterAtpg('d11, master.MODE_STUCK);
        datain = 16'hC0CA;
        for(int i = 11; i > 0; i--)
        begin
            master.SendBit(datain[i]);
        end

        repeat(40) master.SendBit(1'b0);

        #(10us);

        master.EnterAtpg('d14, master.MODE_DELAY);
        datain = 16'hDEAD;
        for(int i = 11; i > 0; i--)
        begin
            master.SendBit(datain[4+i]);
        end

        #(10us);

        $finish(0);

    end

endmodule