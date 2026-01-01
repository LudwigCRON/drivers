// Basic Test Controller
module tap (
	input  wire prim_gclk,
	input  wire prim_rstb,
	// tap interface
	input  wire trstb,
	input  wire tck,
	input  wire tdi,
	output wire tdo,
	output wire tde,
	// oscillator delay test
	input  wire texe_done,
	// scan chain interface
	input  wire tscan_end,
	output wire tscan_start,
	// modes
	output reg  tscan_enable,
	output reg  tscan_exe,
	output wire tapp_active
);

	parameter integer ENTRY_WINDOW = 'd30;
	
	localparam [2:0] S_TST_INIT = 3'b001;
	localparam [2:0] S_TST_KEY  = 3'b011;
	localparam [2:0] S_TST_CMD  = 3'b111;
	localparam [2:0] S_TST_SCAN = 3'b110;
	localparam [2:0] S_TST_EXE  = 3'b100;
	localparam [2:0] S_APP      = 3'b000;

	localparam [7:0] KEY = 8'h96;
	localparam [2:0] MODE_IDDQ  = 3'b010;
	localparam [2:0] MODE_STUCK = 3'b101;
	localparam [2:0] MODE_DELAY = 3'b110;
	
	// dummy tap
	reg  [7:0] cmd;
	wire       cmd_filled;

	always @(negedge tck, negedge trstb)
	begin
		if (!trstb)
			cmd <= 8'h00;
		else if ((!cmd_filled && (state == S_TST_CMD)) || (state == S_TST_KEY) || (state == S_TST_INIT))
			cmd <= {cmd[6:0], tdi};
		else
			cmd <= cmd;
	end


	// finite state machine for control
	reg [2:0] state;
	reg [2:0] next_state;
	reg [4:0] counter;
	wire      scan_filled;
	
	always @(negedge tck, negedge trstb)
	begin
		if (!trstb)
			state <= S_TST_INIT;
		else
			state <= next_state;
	end

	always @(*)
	begin
		case(state)
			S_TST_INIT : next_state = S_TST_KEY;
			S_TST_KEY  : next_state = (cmd_filled && (cmd[7:0] == KEY       )) ? S_TST_CMD  : S_TST_KEY;
			S_TST_CMD  : next_state = (cmd_filled && (cmd[2:0] == MODE_IDDQ )) ? S_TST_SCAN : 
			                          (cmd_filled && (cmd[2:0] == MODE_STUCK)) ? S_TST_SCAN :
			                          (cmd_filled && (cmd[2:0] == MODE_DELAY)) ? S_TST_SCAN : S_TST_CMD;
			S_TST_SCAN : next_state = (scan_filled) ? S_TST_EXE  : S_TST_SCAN;
			S_TST_EXE  : next_state = (texe_done  ) ? S_TST_SCAN : S_TST_EXE;
			S_APP      : next_state = S_APP;
			default    : next_state = S_APP;
		endcase
	end

	always @(negedge tck, negedge trstb)
	begin
		if (!trstb)
			counter <= 5'd0;
		else if (state != next_state)
			counter <= 5'd0;
		else if (state[1] || state[0]) // KEY + CMD + SCAN + EXE
			counter <= counter + 5'd1;
		else
			counter <= 5'd0;
	end

	assign cmd_filled  = &counter[2:0];
	assign scan_filled = (counter >= cmd[7:3]) & (cmd[2:0] != MODE_IDDQ );

	// glitch free control signals
	always @(negedge tck, negedge trstb)
	begin
		if (!trstb)
		begin
			tscan_enable <= 1'b0;
			tscan_exe    <= 1'b0;
		end else
		begin
			tscan_enable <= (next_state == S_TST_SCAN);
			tscan_exe    <= (next_state == S_TST_EXE );
		end
	end

	// window for app active
	reg [4:0] window_counter;
	reg       window_elapsed;

	always @(posedge prim_gclk, negedge prim_rstb)
	begin
		if (!prim_rstb)
		begin
			window_counter <= 'd0;
			window_elapsed  <= 1'b0;
		end else
		begin
			window_counter <= window_counter + ((~&window_counter) ? 'd1 : 'd0);
			window_elapsed <= (window_counter > ENTRY_WINDOW) && (state == S_TST_INIT);
		end
	end

	assign tapp_active = (next_state == S_APP) | window_elapsed;

	// mux
	assign tde = tscan_enable;
	assign tdo = tscan_enable & tscan_end;
	assign tscan_start = tscan_enable & tdi;
	
endmodule
