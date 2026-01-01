// state of the finite state machine
localparam [3:0] S_RX_IDLE   = 4'd0;
localparam [3:0] S_RX_START  = 4'd1;
localparam [3:0] S_RX_DATA0  = 4'd2;
localparam [3:0] S_RX_DATA1  = 4'd3;
localparam [3:0] S_RX_DATA2  = 4'd4;
localparam [3:0] S_RX_DATA3  = 4'd5;
localparam [3:0] S_RX_DATA4  = 4'd6;
localparam [3:0] S_RX_DATA5  = 4'd7;
localparam [3:0] S_RX_DATA6  = 4'd8;
localparam [3:0] S_RX_DATA7  = 4'd9;
localparam [3:0] S_RX_PARITY = 4'd10;
localparam [3:0] S_RX_STOP0  = 4'd11;
localparam [3:0] S_RX_STOP1  = 4'd12;
