`timescale 1ns/10ps

module testcase;

  wire sclk;
  wire mosi;
  wire miso;
  wire csb;

  reg  clk;
  reg  rstb;
  reg  cfg_enable;

  always forever
  begin
    clk = 1'b1;
    #(125ns);
    clk = 1'b0;
    #(125ns);
  end

  spi_monitor #(
    .DATA_WIDTH('d8)
  ) monitor (
    .sclk  (sclk),
    .mosi  (mosi),
    .miso  (miso),
    .csb   (csb)
  );

  spi_driver #(
    .DATA_WIDTH('d8)
  ) driver (
    .sclk  (sclk),
    .mosi  (mosi),
    .csb   (csb)
  );

  spi_slave #(
    .DATA_WIDTH('d8)
  ) dut (
    .clk                   (clk),
    .rstb                  (rstb),
    .atpg                  (1'b0),
    .atpg_rst_control      (1'b0),
    // configuration
    .cfg_enable            (cfg_enable),
    .cfg_lsb_first         (1'b0),
    .cfg_mode              (driver.mode),
    // standard interface for high level
    .spi_slave_tx_data     ('h0002),
    .spi_slave_tx_empty_it (),
    .spi_slave_rx_data     (),
    .spi_slave_rx_new_it   (),
    .spi_slave_rx_par_it   (),
    .spi_slave_rx_frm_it   (),
      // IOs
    .ms_csb                (csb),
    .ms_sclk               (sclk),
    .ms_mosi               (mosi),
    .ms_miso               (miso)
  );


  task PowerUp();
    rstb = 1'b0;
    repeat(4) @(posedge clk);
    rstb = 1'b1;
  endtask

  initial
  begin
    $dumpfile("waves.fst");
    $dumpvars(0);
  end


  initial
  begin
    cfg_enable = 1'b0;
    PowerUp();
    #(100ns);
    driver.SendFrame(2, 2, 0);
    #(1us);
    driver.SendFrame(2, 2, 1);
    #(1us);
    driver.SendFrame(3, 5);

    cfg_enable = 1'b1;
    #(100ns);
    driver.SendFrame(2, 2, 0);
    #(1us);
    driver.SendFrame(2, 2, 1);
    #(1us);
    driver.SendFrame(3, 5);
  
    $finish(0);
  end


endmodule
