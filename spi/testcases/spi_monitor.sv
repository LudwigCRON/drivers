`default_nettype none

module spi_monitor #(
  parameter integer DATA_WIDTH = 'd8,
  parameter integer CRC_POLY   = 32'h0000_002F,
  parameter integer CRC_INIT   = 32'h0000_00FF,
  parameter integer CRC_FINAL  = 32'h0000_00FF
) (
  input  wire  sclk,
  input  wire  mosi,
  input  wire  miso,
  input  wire  csb
);

  logic  has_crc;
  string cmd;
  int    cmd_id;

  string CMD_DESC[256];
  int    RX_CRC_POS[256];
  int    TX_CRC_POS[256];

  initial
  begin
    CMD_DESC[8'h10]   = "Start Single Measurment";
    RX_CRC_POS[8'h10] = 3;
    TX_CRC_POS[8'h10] = 3 + 2;

    CMD_DESC[8'h20]   = "Start Burst Measurment";
    RX_CRC_POS[8'h20] = 3;
    TX_CRC_POS[8'h20] = 3 + 2;

    CMD_DESC[8'h30]   = "Start Wakeup On Change";
    RX_CRC_POS[8'h30] = 3;
    TX_CRC_POS[8'h30] = 3 + 2;

    CMD_DESC[8'h40]   = "Read Measurement";
    RX_CRC_POS[8'h40] = 3;
    TX_CRC_POS[8'h40] = 1 + 3;

    CMD_DESC[8'h50]   = "Write Register";
    RX_CRC_POS[8'h50] = 3;
    TX_CRC_POS[8'h50] = 4 + 2;

    CMD_DESC[8'h60]   = "Read Register";
    RX_CRC_POS[8'h60] = 2;
    TX_CRC_POS[8'h60] = 2 + 2;

    CMD_DESC[8'hF0]   = "Reset";
    RX_CRC_POS[8'hF0] = 1;
    TX_CRC_POS[8'hF0] = 1 + 2;
  end


  task UpdateCmd();
    cmd_id = int'(rx_buffer[0]);
    cmd = "UNKNOWN";
    if (CMD_DESC[cmd_id] > 0)
      cmd = CMD_DESC[cmd_id];
  endtask

  typedef struct packed {
    bit [1:0] mode;
    bit [2:0] counter;
    bit       error;
    bit       warning;
    bit       drdy;
  } st_status;

  st_status expected_status;
  st_status status;


  logic [DATA_WIDTH-1:0] rx_buffer[$];
  logic [DATA_WIDTH-1:0] tx_buffer[$];

  // initialization
  initial
  begin
    has_crc = 0;
    expected_status = 8'h02; // WARN_RST
  end

  // detect communication mode

  // buffer handling
  // - automatic clearing at new frame
  
  always @(negedge csb)
  begin
    flush_buffer();
  end

  // store received data
  reg [DATA_WIDTH-1:0] rx_shft;
  reg [DATA_WIDTH-1:0] tx_shft;
  reg [DATA_WIDTH-1:0] proc_shft;

  always @(negedge csb)
  begin
    proc_shft[7:0] = 8'h01;
  end

  always @(posedge sclk)
  begin
    proc_shft[7:0] = {proc_shft[6:0], proc_shft[7]};
    rx_shft[7:0]   = {rx_shft[6:0], mosi};
    tx_shft[7:0]   = {tx_shft[6:0], miso};
    if (proc_shft[7])
    begin
      rx_buffer.push_back(rx_shft);
      tx_buffer.push_back(tx_shft);
      UpdateCmd();
    end
  end

  always @(posedge csb)
  begin
    check_valid_cmd();
    check_status();
    if (has_crc)
      check_crc();
  end

  // utility functions
  task flush_buffer();
    rx_buffer = '{};
    tx_buffer = '{};
  endtask

  task check_crc();
    int crc_rx_pos;
    int crc_tx_pos;
    int crc;
    // check rx crc
    crc_rx_pos = RX_CRC_POS[cmd_id];
    if (crc_rx_pos > 'd0 && crc_rx_pos < rx_buffer.size())
    begin
      crc = CRC_INIT;
      for(int i = 0; i < crc_rx_pos; i++)
      begin
        crc = crc ^ (rx_buffer[i] & CRC_POLY);
      end
      crc = crc ^ CRC_FINAL;
      if (rx_buffer[crc_rx_pos] != crc)
        $warning("Incorrect CRC received. Expect [%04X] Get [%04X]", crc, rx_buffer[crc_rx_pos]);
    end
    // check tx crc
    crc_tx_pos = TX_CRC_POS[cmd_id];
    if (crc_tx_pos > 'd0 && crc_tx_pos < tx_buffer.size())
    begin
      crc = CRC_INIT;
      for(int i = 0; i < crc_tx_pos; i++)
      begin
        crc = crc ^ (tx_buffer[i] & CRC_POLY);
      end
      crc = crc ^ CRC_FINAL;
      if (tx_buffer[crc_tx_pos] != crc)
        $warning("Incorrect CRC transmitted. Expect [%04X] Get [%04X]", crc, tx_buffer[crc_tx_pos]);
    end
  endtask

  task check_status();
    if (expected_status != status)
    begin
      $warning("Expected status [%04X] Get [%04X]", expected_status, status);
    end
  endtask

  task check_valid_cmd();
    if (cmd == "UNKNOWN")
      $warning("Unsupported command");
  endtask

endmodule

`default_nettype wire
