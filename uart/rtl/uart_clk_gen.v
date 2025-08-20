`default_nettype none

module uart_clk_gen (
	input  wire        clk,
	input  wire        rstb,

	// configuration
	input  wire [ 8:0] cfg_clk_div,
	input  wire        cfg_enable,

	// from rx
	input  wire        uart_start,

	// generated clock and reset
	output wire        uart_ce,
	output wire        uart_mid
);

	wire       next_uart_ce;
	wire [8:0] new_div;
	reg  [8:0] cnt;

	assign new_div[8:2] = cfg_clk_div[8:2];
	assign new_div[1:0] = {2{~|cfg_clk_div[8:2]}} | cfg_clk_div[1:0];

	always @(posedge clk, negedge rstb)
	begin
		if (!rstb)
			cnt[8:0] <= 9'd0;
		else if (!cfg_enable || next_uart_ce)
			cnt[8:0] <= 9'd0;
		else if (uart_start)
            cnt[8:0] <= {1'b0, new_div[8:1]};
        else
            cnt[8:0] <= cnt[8:0] + 9'd1; 
	end

	// compensate the latency of the fir
	// for the clock enable signals
	reg [2:0] fir_ce;
	reg [2:0] fir_mid;

	assign next_uart_ce = (cnt[8:0] == new_div[8:0]);
	always @(posedge clk, negedge rstb)
	begin
		if (!rstb)
		begin
			fir_ce  <= 3'd0;
			fir_mid <= 3'd0; 
		end else
		begin
			fir_ce  <= {fir_ce[1:0], next_uart_ce};
			fir_mid <= {fir_mid[1:0], (cnt[8:0] == new_div[8:1])};
		end
	end

	assign uart_ce = fir_ce[1];
	assign uart_mid = fir_mid[1];

endmodule

`default_nettype wire