`default_nettype none
`timescale 1ns/10ps

module spi_driver #(
  parameter integer DATA_WIDTH = 'd8,
  parameter integer CRC_POLY   = 32'h0000_002F,
  parameter integer CRC_INIT   = 32'h0000_00FF,
  parameter integer CRC_FINAL  = 32'h0000_00FF

) (
  output reg sclk,
  output reg mosi,
  output reg csb
);

  realtime period;
  logic [1:0] mode;

  initial
  begin
    sclk = 1'b1;
    csb  = 1'b1;
    mosi = 1'b0;
    mode = 2'b11;
    period = 100ns;
  end

  task SendFrame(
    input int rxln = 'd2,
    input int txln = 'd3,
    input bit fullduplex = 0
  );
    int b;
    sclk = mode[1];
    csb  = 1'b0;
    #(10ns);
  
    for(int i = 0; i < rxln; i++)
    begin
      b = $urandom() % 2**DATA_WIDTH;
      for(int j = 0; j < DATA_WIDTH; j++)
      begin
        sclk = ~mode[1];
        #(3ns);
        if ( mode[0]) mosi = b[j];
        #(period * 0.5 - 3ns);
        if (!mode[0]) mosi = b[j];
        sclk = ~sclk;
        #(period * 0.5);
      end
    end

    for(int i = 0; i < txln - rxln * fullduplex; i++)
    begin
      b = 0;
      for(int j = 0; j < DATA_WIDTH; j++)
      begin
        sclk = mode[1];
        #(3ns);
        mosi = b[j];
        #(period * 0.5 - 3ns);
        sclk = ~sclk;
        #(period * 0.5);
      end
    end
    
    sclk = mode[1];
    #(10ns);
    csb = 1'b1;

  endtask


endmodule

`default_nettype wire
