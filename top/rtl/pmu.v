`define_nettype none

module pmu #(
    parameter integer CNT_WIDTH       = 'd8,
    parameter integer NB_ENABLE       = 'd8,
    parameter integer EN_MASK_SLEEP   = 'h01,
    parameter integer EN_MASK_STANDBY = 'h03,
    parameter integer EN_MASK_ACTIVE  = 'h07,
    parameter integer EN_MASK_MEASURE = 'h0F
) (
    // digital power domain handshakes
    input  wire                 prim_rstb,

    input  wire                 prim_sleep_req,
    input  wire                 prim_stdby_req,
    input  wire                 prim_active_req,
    input  wire                 prim_measure_req,

    output wire                 prim_sleep_ack,
    output wire                 prim_stdby_ack,
    output wire                 prim_active_ack,
    output wire                 prim_measure_ack,

    // second power domain
    output wire                 perm_clk,
    output wire                 perm_rstb,

    output reg  [          1:0] perm_power_mode,
    output reg  [NB_ENABLE-1:0] perm_power_en,

    // settling time handling
    input  wire [CNT_WIDTH-1:0] perm_standby_to_active_limit,
    input  wire [CNT_WIDTH-1:0] perm_active_to_standby_limit,

    // cpu handling (software should disable interrupts before halt instruction)
    input  wire                 prim_cpu_halted,

    // wake up timer
    output wire                 perm_wut_start_req,
    input  wire                 perm_wut_start_ack,
    input  wire                 perm_wut_it
);

    // only 1 bit changing at a time
    localparam [1:0] S_DEEP_SLEEP = 2'b11;
    localparam [1:0] S_STANDBY    = 2'b10;
    localparam [1:0] S_ACTIVE     = 2'b00;
    localparam [1:0] S_MEASURE    = 2'b01;

    reg [1:0] perm_next_power_mode;

    // levelshifter
    wire perm_sleep_pre_req;
    wire perm_stdby_pre_req;
    wire perm_active_pre_req;
    wire perm_measure_pre_req;
    wire perm_cpu_halted;

    and g_lvlshft_sleep_ack   (prim_sleep_ack, perm_sleep_ack, prim_rstb, perm_rstb);
    and g_lvlshft_stdby_ack   (prim_stdby_ack, perm_stdby_ack, prim_rstb, perm_rstb);
    and g_lvlshft_active_ack  (prim_active_ack, perm_active_ack, prim_rstb, perm_rstb);
    and g_lvlshft_measure_ack (prim_measure_ack, perm_measure_ack, prim_rstb, perm_rstb);

    and g_lvlshft_cpu_halted  (perm_cpu_halted, prim_cpu_halted, prim_rstb, perm_rstb);
    and g_lvlshft_sleep_req   (perm_sleep_pre_req, prim_sleep_req, !perm_cpu_halted, prim_rstb, perm_rstb);
    and g_lvlshft_stdby_req   (perm_stdby_pre_req, prim_stdby_req, !perm_cpu_halted, prim_rstb, perm_rstb);
    and g_lvlshft_active_req  (perm_active_pre_req, prim_active_req, prim_rstb, perm_rstb);
    and g_lvlshft_measure_req (perm_measure_pre_req, prim_measure_req, prim_rstb, perm_rstb);

    // perm power domain resync and handshakes
    reg [1:0] perm_sleep_req;
    reg [1:0] perm_stdby_req;
    reg [1:0] perm_active_req;
    reg [1:0] perm_measure_req;

    reg [CNT_WIDTH-1:0] perm_counter;
    wire                perm_counter_incr;
    wire                perm_counter_done;

    reg       perm_wut_mem;

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_wut_mem <= 1'b0;
        end else if (perm_wut_it)
        begin
            perm_wut_mem <= 1'b1;
        end else if (perm_measure_ack)
        begin
            perm_wut_mem <= 1'b0;
        end else
        begin
            perm_wut_mem <= perm_wut_mem;
        end
    end

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_sleep_req <= 2'b00;
            perm_stdby_req <= 2'b00;
            perm_active_req <= 2'b00;
            perm_measure_req <= 2'b00;
        end else
        begin
            perm_sleep_req <= {perm_sleep_req[0], perm_sleep_pre_req};
            perm_stdby_req <= {perm_stdby_req[0], perm_stdby_pre_req};
            perm_active_req <= {perm_active_req[0], perm_active_pre_req};
            perm_measure_req <= {perm_measure_req[0], perm_wut_mem | perm_measure_pre_req};
        end
    end

    assign perm_sleep_ack = (perm_power_mode == S_DEEP_SLEEP);
    assign perm_stdby_ack = (perm_power_mode == S_STANDBY);
    assign perm_active_ack = (perm_power_mode == S_ACTIVE);
    assign perm_measure_ack = (perm_power_mode == S_MEASURE);

    wire perm_ds_to_stby;
    wire perm_stby_to_ds;
    wire perm_stby_to_ac;
    wire perm_ac_to_stby;
    wire perm_ac_to_meas;
    wire perm_meas_to_ac;

    assign perm_ds_to_stby = perm_stby_req | perm_active_req | perm_measure_req;
    assign perm_stby_to_ds = perm_sleep_req;
    assign perm_stby_to_ac = perm_active_req | perm_measure_req;
    assign perm_ac_to_stby = perm_sleep_req | perm_stby_req;
    assign perm_ac_to_meas = perm_measure_req;
    assign perm_meas_to_ac = perm_sleep_req | perm_stby_req | perm_active_req;

    // perm power domain finite state machine
    always @(*)
    begin
        case(power_mode)
            S_DEEP_SLEEP : perm_next_power_mode = (perm_ds_to_stby ) ? S_STANDBY    : S_DEEP_SLEEP;
            S_STANDBY    : perm_next_power_mode = (perm_stby_to_ac ) ? S_ACTIVE     :
                                                  (perm_stby_to_ds ) ? S_DEEP_SLEEP : S_STANDBY;
            S_ACTIVE     : perm_next_power_mode = (perm_ac_to_meas ) ? S_MEASURE    :
                                                  (perm_ac_to_stby ) ? S_STANDBY    : S_ACTIVE;
            S_MEASURE    : perm_next_power_mode = (perm_meas_to_ac ) ? S_ACTIVE     : S_MEASURE;
            default      : perm_next_power_mode = S_ACTIVE;
        endcase
    end

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_power_mode <= S_ACTIVE;
        end else
        begin
            perm_power_mode <= perm_next_power_mode;
        end
    end

    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_power_en <= EN_MASK_ACTIVE;
        end else
        begin
            case(power_mode)
                S_DEEP_SLEEP : perm_power_en <= (perm_ds_to_stby                     ) ? EN_MASK_STANDBY    : EN_MASK_SLEEP;
                S_STANDBY    : perm_power_en <= (perm_stby_to_ac && perm_counter_done) ? EN_MASK_ACTIVE     :
                                                (perm_stby_to_ds                     ) ? EN_MASK_SLEEP      : EN_MASK_STANDBY;
                S_ACTIVE     : perm_power_en <= (perm_ac_to_meas                     ) ? EN_MASK_MEASURE    :
                                                (perm_ac_to_stby && perm_counter_done) ? EN_MASK_STANDBY    : EN_MASK_ACTIVE;
                S_MEASURE    : perm_power_en <= (perm_meas_to_ac                     ) ? EN_MASK_ACTIVE     : EN_MASK_MEASURE;
                default      : perm_power_en <= EN_MASK_ACTIVE;
            endcase
        end
    end

    // handle settling time in perm power domain
    always @(posedge perm_clk, negedge perm_rstb)
    begin
        if (!perm_rstb)
        begin
            perm_counter <= 'd0;
        end else if (perm_counter_incr)
        begin
            perm_counter <= perm_counter + 'd1;
        end else if (perm_counter_done)
        begin
            perm_counter <= 'd0;
        end
    end

    assign perm_counter_incr = perm_stby_to_ac | perm_ac_to_stby | (perm_counter > 'd0);
    assign perm_counter_done = perm_counter >= (perm_stby_to_ac ? perm_standby_to_active_limit : perm_active_to_standby_limit);


    // handle perm power domain wake up timer
    assign perm_wut_start_req = (perm_power_mode == S_STANDBY) & !perm_wut_start_ack;


endmodule

`define_nettype wire
