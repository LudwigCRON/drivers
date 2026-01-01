`default_nettype none

module uart (
	// platform and asic integration
	input  wire        clk,
	input  wire        rstb,
	input  wire        atpg_rst_ctrl,

	// configuration
	input  wire [ 8:0] cfg_clk_div,
	input  wire        cfg_enable,
	input  wire        cfg_has_parity,
	input  wire        cfg_odd_parity,
	input  wire        cfg_extend_stop,
	input  wire        cfg_lsb_first,
	input  wire        cfg_word,

	// standard interface for high level
	input  wire [ 7:0] uart_tx_data,
	input  wire        uart_tx_empty_it,
	output wire [ 7:0] uart_rx_data,
	output wire        uart_rx_new_it,
	output wire        uart_rx_par_it,
	output wire        uart_rx_frm_it,

	// for use with extension hw
	output wire        uart_ce,

	// IOs
	input  wire        ms_urx,
	output wire        ms_utx
);

	wire uart_mid;
	wire uart_start;

	// fifo tx (optional)

	// fifo rx (optional)

	// clock gen
	uart_clk_gen clk_gen (
		.clk          (clk),
		.rstb         (rstb),
		// configuration
		.cfg_clk_div  (cfg_clk_div),
		.cfg_enable   (cfg_enable),
		// from receiver
		.uart_start   (uart_start),
		// generated clock and reset
		.uart_ce      (uart_ce),
		.uart_mid     (uart_mid)
	);

	// tx

	// rx
	uart_rx rx (
		.clk             (clk),
		.rstb            (rstb),
		.uart_ce         (uart_ce),
		.uart_mid        (uart_mid),
		.uart_start      (uart_start),
		// configuration
		.cfg_has_parity  (cfg_has_parity),
		.cfg_odd_parity  (cfg_odd_parity),
		.cfg_extend_stop (cfg_extend_stop),
		.cfg_lsb_first   (cfg_lsb_first),
		.cfg_word        (cfg_word),
		// interface to digital
		.uart_rx_data    (uart_rx_data),
		.uart_rx_new_it  (uart_rx_new_it),
		.uart_rx_par_it  (uart_rx_par_it),
		.uart_rx_frm_it  (uart_rx_frm_it),
		// interface to IO
		.ms_urx          (ms_urx)
	);

endmodule
