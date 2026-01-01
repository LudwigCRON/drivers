
// prefer a module for verilog-ams compatibility
module uart_cfg;

    reg has_parity;
    reg odd_parity;
    reg extend_stop;
    reg lsb_first;
    reg word;

    initial
    begin
        has_parity  = 1'b0;
        odd_parity  = 1'b0;
        extend_stop = 1'b0;
        lsb_first   = 1'b0;
        word        = 1'b0;
    end

    task Randomize();
        has_parity  = $urandom_range(0, 1);
        odd_parity  = $urandom_range(0, 1);
        extend_stop = $urandom_range(0, 1);
        lsb_first   = $urandom_range(0, 1);
        word        = $urandom_range(0, 1);
    endtask

endmodule