`default_nettype none

module dsp (
    input  wire        prim_clk,
    input  wire        prim_rstb,
    input  wire        enable,
    input  wire [ 7:0] offset_tref,
    input  wire [ 7:0] offset_oref,
    input  wire [ 7:0] offset_gain,
    input  wire [ 7:0] sensitivity_tref,
    input  wire [ 7:0] sensitivity_oref,
    input  wire [ 7:0] sensitivity_gain,
    input  wire [11:0] ms_adc_data,
    input  wire [ 2:0] meas_state,
    input  wire [ 3:0] meas_phase,
    input  wire        meas_eoc_p,
    input  wire        meas_eop,
    output wire [11:0] meas_data,
    output wire        meas_data_p
);

    localparam [1:0] OP_ADD = 2'b00;
    localparam [1:0] OP_SUB = 2'b01;
    localparam [1:0] OP_MUL = 2'b10;
    localparam [1:0] OP_LOD = 2'b11;

    reg [11:0] reg_accu;
    reg [ 9:0] reg_temp;
    reg [ 9:0] reg_vdd;
    reg [ 9:0] reg_offset;
    reg [ 9:0] reg_sensitivity;
    reg [11:0] reg_x;
    reg [11:0] reg_y;
    reg [11:0] reg_z;
    reg [14:0] alu_a;
    reg [11:0] alu_b;
    reg [19:0] alu_q;
    reg [ 2:0] alu_op;
    reg [ 7:0] reg_select;

    always @(*)
    begin
        case(alu_op)
            OP_ADD : alu_q = alu_a + alu_b;
            OP_SUB : alu_q = alu_a - alu_b;
            OP_MUL : alu_q = alu_a * alu_b;
            default: alu_q = alu_a;
        endcase
    end

    localparam [3:0] S_MEA_IDLE = 4'b0000;
    localparam [3:0] S_MEA_AVGM = 4'b0001;
    localparam [3:0] S_MEA_AVGF = 4'b0010;
    localparam [3:0] S_MAG_OFF0 = 4'b0100; // butterfly - (temp - tref)
    localparam [3:0] S_MAG_OFF1 = 4'b0101; // butterfly - gain * (temp - tref)
    localparam [3:0] S_MAG_OFF2 = 4'b0110; // butterfly - Offset = gain * (temp - tref) + oref
    localparam [3:0] S_MAG_SEN0 = 4'b1000; // butterfly - (temp - tref)
    localparam [3:0] S_MAG_SEN1 = 4'b1001; // butterfly - gain * (temp - tref)
    localparam [3:0] S_MAG_SEN2 = 4'b1010; // butterfly - Sensitivity = gain * (temp - tref) + oref
    localparam [3:0] S_ENV_TEMP = 4'b1100;
    localparam [3:0] S_ENV_VDDD = 4'b1101;
    localparam [3:0] S_MAG_COM0 = 4'b1110; // Sensitivity * AVG
    localparam [3:0] S_MAG_COM1 = 4'b1111; // Sensitivity * AVG - Offset

    localparam [2:0] S_INIT  = 3'b000;
    localparam [2:0] S_ENV_T = 3'b001;
    localparam [2:0] S_MAG_X = 3'b011;
    localparam [2:0] S_MAG_Y = 3'b111;
    localparam [2:0] S_MAG_Z = 3'b110;
    localparam [2:0] S_ENV_V = 3'b100;

    reg [3:0] dsp_state;
    reg [2:0] meas_state_delayed;

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
            meas_state_delayed <= S_INIT;
        else if (meas_eoc_p || meas_eop)
            meas_state_delayed <= meas_state;
    end

    always @(posedge prim_clk, negedge prim_rstb)
    begin
        if (!prim_rstb)
        begin
            dsp_state <= S_MEA_IDLE;
        end else if (enable)
        begin
            case(dsp_state)
                S_MEA_IDLE: dsp_state <= (meas_eoc_p) ? S_MEA_AVGM :
                                         (meas_eop  ) ? S_MEA_AVGF : S_MEA_IDLE;
                S_MEA_AVGM: dsp_state <= (meas_eoc_p && meas_phase[0]) ? S_MAG_OFF0 :
                                         (meas_eoc_p && meas_phase[1]) ? S_MAG_SEN0 : S_MEA_IDLE;
                S_MEA_AVGF: dsp_state <= (meas_state_delayed == S_ENV_T) ? S_ENV_TEMP :
                                         (meas_state_delayed == S_ENV_V) ? S_ENV_VDDD : S_MAG_COM0;
                S_MAG_OFF0: dsp_state <= S_MAG_OFF1;
                S_MAG_OFF1: dsp_state <= S_MAG_OFF2;
                S_MAG_OFF2: dsp_state <= S_MEA_IDLE;
                S_MAG_SEN0: dsp_state <= S_MAG_SEN1;
                S_MAG_SEN1: dsp_state <= S_MAG_SEN2;
                S_MAG_SEN2: dsp_state <= S_MEA_IDLE;
                S_ENV_TEMP: dsp_state <= S_MEA_IDLE;
                S_ENV_VDDD: dsp_state <= S_MEA_IDLE;
                S_MAG_COM0: dsp_state <= S_MAG_COM1;
                S_MAG_COM1: dsp_state <= S_MEA_IDLE;
                default   : dsp_state <= S_MEA_IDLE;
            endcase
        end
    end

    always @(*)
    begin
        case(dsp_state)
            S_MEA_AVGM: begin 
                alu_op = (meas_phase[1]) ? OP_SUB : OP_ADD;
                alu_a = $signed(reg_accu);
                alu_b = $signed(ms_adc_data);
                reg_select = 8'h01;
            end
            S_MEA_AVGF: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_accu);
                alu_b = $signed(ms_adc_data);
                reg_select = 8'h01;
            end
            S_MAG_OFF0: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_temp);
                alu_b = $signed(offset_tref);
                reg_select = 8'h01;
            end
            S_MAG_OFF1: begin 
                alu_op = OP_MUL;
                alu_a = $signed(reg_accu);
                alu_b = $signed(offset_gain);
                reg_select = 8'h01;
            end
            S_MAG_OFF2: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_accu);
                alu_b = $signed(offset_oref);
                reg_select = 8'h02;
            end
            S_MAG_SEN0: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_temp);
                alu_b = $signed(sensitivity_tref);
                reg_select = 8'h01;
            end
            S_MAG_SEN1: begin 
                alu_op = OP_MUL;
                alu_a = $signed(reg_accu);
                alu_b = $signed(sensitivity_gain);
                reg_select = 8'h01;
            end
            S_MAG_SEN2: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_accu);
                alu_b = $signed(sensitivity_oref);
                reg_select = 8'h04;
            end
            S_ENV_TEMP: begin 
                alu_op = OP_LOD;
                alu_a = 'd0;
                alu_b = 'd0;
                reg_select = 8'h00;
            end
            S_ENV_VDDD: begin 
                alu_op = OP_LOD;
                alu_a = 'd0;
                alu_b = 'd0;
                reg_select = 8'h00;
            end
            S_MAG_COM0: begin 
                alu_op = OP_MUL;
                alu_a = $signed(reg_accu);
                alu_b = $signed(reg_sensitivity);
                reg_select = 8'h01;
            end
            S_MAG_COM1: begin 
                alu_op = OP_SUB;
                alu_a = $signed(reg_accu);
                alu_b = $signed(reg_offset);
                reg_select = {(meas_state_delayed == S_MAG_Z),(meas_state_delayed == S_MAG_Y),(meas_state_delayed == S_MAG_X), 4'h0};
            end
            default   : begin alu_op = OP_LOD; alu_a = 'd0; alu_b = 'd0; reg_select = 6'b000000; end // NOP for IDLE
        endcase
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd1)
            reg_accu <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd2)
            reg_offset <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd4)
            reg_sensitivity <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd8)
            reg_temp <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd16)
            reg_x <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd32)
            reg_y <= alu_q; 
    end

    always @(posedge prim_clk)
    begin
        if (reg_select == 'd64)
            reg_z <= alu_q; 
    end
    

endmodule

`default_nettype wire
