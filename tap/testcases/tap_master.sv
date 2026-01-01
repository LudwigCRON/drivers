
`timescale 1ns/10ps

module tap_master (
	input  wire tdo,
	input  wire tde,
	output reg  tdi,
	output reg  tck,
	output reg  trstb
);

	localparam [7:0] KEY        = 8'h96;
	localparam [2:0] MODE_IDDQ  = 3'b010;
	localparam [2:0] MODE_STUCK = 3'b101;
	localparam [2:0] MODE_DELAY = 3'b110;

	int period; // ns

	initial
	begin
		#0;
		tdi    = 1'b0;
		tck    = 1'b0;
		trstb  = 1'b0;
		period = 100;
	end

	task SendBit(
		input bit b = 1'b0
	);
		tdi  = b;
		#(4ns);
		tck  = 1'b1;
		#(period * 0.5ns);
		tck  = 1'b0;
		#(period * 0.5ns - 4ns);
	endtask

	task SendByte(
		input [7:0] b = 8'd0
	);
		SendBit(b[7]);
		SendBit(b[6]);
		SendBit(b[5]);
		SendBit(b[4]);
		SendBit(b[3]);
		SendBit(b[2]);
		SendBit(b[1]);
		SendBit(b[0]);
	endtask

	task Reset();
		trstb = 1'b0;
		SendBit(1'b0);
		SendBit(1'b0);
		SendBit(1'b0);
		SendBit(1'b0);
		trstb = 1'b1;
	endtask

	task SetKey(
		input [7:0] key = 8'h96
	);
		Reset();
		SendByte(key);
		SendBit(1'b0);
	endtask

	task EnterAtpg(
		input [4:0] length = 5'd1,
		input [2:0] mode   = 3'd0
	);
		Reset();
		SendByte(KEY);
		SendByte({length[4:0], mode[2:0]});
		SendBit(1'b0);
	endtask

endmodule