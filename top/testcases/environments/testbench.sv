`timescale 1ns/100ps

module testbench;

    real VDD;
    real VSS;
    wire TCK;
    wire TDI;
    wire TDO;
    wire TRSTB;
    wire URX;
    wire UTX;

    chip chip (
        .VDD   (VDD),
        .VSS   (VSS),
        .TCK   (TCK),
        .TDI   (TDI),
        .TDO   (TDO),
        .TRSTB (TRSTB),
        .URX   (URX),
        .UTX   (UTX)
    );

    // tap_master
    tap_master tap_master (
        .tck   (TCK),
        .tdi   (TDI),
        .tdo   (TDO),
        .trstb (TRSTB)
    );

    // uart master

    // useful task
    task PowerRamp(
        input real     target_vdd = 3.3,
        input realtime t_slope = 100us
    );
        real step;
        real dbg;
        bit stop;
        stop = 0;
        step = (target_vdd - VDD + VSS) / t_slope * 10ns;
        while (!stop)
        begin
            VDD += step;
            #10ns;
            dbg = VDD - VSS - target_vdd;
            stop = absr(dbg) < absr(step);
        end
    endtask

    task PowerOff(
        input realtime t_slope = 100us
    );
        PowerRamp(0.0, t_slope);
    endtask

    task PowerOn(
        input real     target_vdd = 3.3,
        input realtime t_slope = 100us
    );
        PowerRamp(target_vdd, t_slope);
    endtask

    function automatic real absr(
        input real value
    );
        if (value < 0.0)
            return -1.0 * value;
        return value;
    endfunction

endmodule