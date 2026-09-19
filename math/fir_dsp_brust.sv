module fir_dsp_brust#(
    parameter integer FIR_TAP = 64,
    parameter integer COE_WIDTH = 24,
    parameter integer DML_LEN = 22,
    parameter integer DATA_WIDTH = 16
)(
    input       clk,
    input       rstn,

    output                        s_axis_tready,
    input                         s_axis_tvalid,
    input      [DATA_WIDTH-1:0]   s_axis_tdata,

    // input                         m_axis_tready,
    output                        m_axis_tvalid,
    output     [DATA_WIDTH-1:0]   m_axis_tdata
);

localparam integer FIR_N_HALF = FIR_TAP / 2;
localparam integer FIR_ACC_TIME = 4;
localparam integer MULT_NUM = 32;
localparam integer FIR_ACC_LEN = ($clog2(MULT_NUM) + 2 - 1) / 2;
localparam integer ACC_STAGE0 = (MULT_NUM + FIR_ACC_TIME - 1) / FIR_ACC_TIME;
localparam integer ACC_STAGE1 = (ACC_STAGE0 + FIR_ACC_TIME - 1) / FIR_ACC_TIME;

// fir state
localparam
IDLE = 'h0,
FIR_CAL = 'h1;
logic [0:0] state;
logic data_input_trig;
logic cal_flag;
logic cal_end_flag;
// status pipeline
localparam integer PIPE_LEN = 2 + FIR_ACC_LEN;
logic cflag_pl[PIPE_LEN-1:0];
logic cal_end_pl[PIPE_LEN:0];
logic pl_acc_trig;
logic pl_end_trig;
logic dout_valid;
// data storage & coefficient rom
localparam integer RW_ADDR_WIDTH = $clog2(FIR_TAP);
logic [RW_ADDR_WIDTH-1:0] mem_w_addr_a;
logic [RW_ADDR_WIDTH-1:0] mem_r_addr_a_base;
logic [RW_ADDR_WIDTH-1:0] mem_rw_addr_a[MULT_NUM-1:0];
logic signed [DATA_WIDTH-1:0] mem_odata_a[MULT_NUM-1:0];
logic [RW_ADDR_WIDTH-1:0] mem_w_addr_b_base;
logic [RW_ADDR_WIDTH-1:0] mem_w_addr_b[MULT_NUM-1:0];
logic signed [DATA_WIDTH-1:0] mem_odata_b[MULT_NUM-1:0];
logic [RW_ADDR_WIDTH-2:0] rom_r_addr_base;
logic [RW_ADDR_WIDTH-2:0] rom_r_addr[MULT_NUM-1:0];
logic signed [COE_WIDTH-1:0] rom_odata[MULT_NUM-1:0];
// coefficient mult
localparam integer ADDED_WIDTH = DATA_WIDTH + 1;
localparam integer MUL_WIDTH = ADDED_WIDTH + COE_WIDTH;
logic signed [COE_WIDTH-1:0] coe_data_reg[MULT_NUM-1:0];
logic signed [ADDED_WIDTH-1:0] mem_odata_add[MULT_NUM-1:0];
logic signed [MUL_WIDTH-1:0] mem_odata_mul[MULT_NUM-1:0];
// data acc
localparam integer ACC_WIDTH_INC = $clog2(FIR_ACC_TIME);
localparam integer ACC_WIDTH_END = DATA_WIDTH + COE_WIDTH + $clog2(FIR_TAP);
localparam logic signed [DATA_WIDTH-1:0] SHIFT_DATA_MAX = {1'b0, {(DATA_WIDTH-1){1'b1}}};
localparam logic signed [DATA_WIDTH-1:0] SHIFT_DATA_MIN = {1'b1, {(DATA_WIDTH-1){1'b0}}};
logic signed [MUL_WIDTH+ACC_WIDTH_INC-1:0] muled_data_acc0[ACC_STAGE0-1:0];
logic signed [MUL_WIDTH+ACC_WIDTH_INC*2-1:0] muled_data_acc1[ACC_STAGE1-1:0];
logic signed [ACC_WIDTH_END-1:0] muled_data_acc_end[1:0];
logic data_acc_sel;
logic signed [ACC_WIDTH_END-1:0] scaled_data;

// fir state
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        state <= IDLE;
    end else begin
        case(state)
        IDLE: begin
            if(s_axis_tvalid == 1'b1)begin
                state <= FIR_CAL;
            end
        end
        FIR_CAL: begin
            if(cal_end_flag == 1'b1) begin
                if(s_axis_tvalid == 1'b0) begin
                    state <= IDLE;
                end
            end
        end
        default: state <= IDLE;
        endcase
    end
end
assign s_axis_tready = (state == IDLE) || (cal_end_flag == 1'b1);
assign data_input_trig = (rstn == 1'b1) && (s_axis_tvalid == 1'b1) && (s_axis_tready == 1'b1);
assign cal_flag = (state == FIR_CAL);
assign cal_end_flag = (rom_r_addr_base == FIR_N_HALF - MULT_NUM);

// status pipeline
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        for(integer i = 0; i < PIPE_LEN; i++) begin
            cflag_pl[i] <= 1'b0;
        end
    end else begin
        cflag_pl[0] <= cal_flag;
        for(integer i = 0; i < PIPE_LEN - 1; i++) begin
            cflag_pl[i+1] <= cflag_pl[i];
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        for(integer i = 0; i < PIPE_LEN + 1; i++) begin
            cal_end_pl[i] <= 1'b0;
        end
    end else begin
        cal_end_pl[0] <= cal_end_flag;
        for(integer i = 0; i < PIPE_LEN; i++) begin
            cal_end_pl[i+1] <= cal_end_pl[i];
        end
    end
end
assign pl_acc_trig = ~cal_end_pl[PIPE_LEN-2] & cal_end_pl[PIPE_LEN-1];
assign pl_end_trig = ~cal_end_pl[PIPE_LEN-1] & cal_end_pl[PIPE_LEN];
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        dout_valid <= 1'b0;
    end else begin
        dout_valid <= pl_end_trig;
    end
end
assign m_axis_tvalid = dout_valid;

// data storage & coefficient rom
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_w_addr_a <= 'b0;
    end else if(data_input_trig == 1'b1) begin
        if(mem_w_addr_a == FIR_TAP - 1) begin
            mem_w_addr_a <= 'b0;
        end else begin
            mem_w_addr_a <= mem_w_addr_a + 1'b1;
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_r_addr_a_base <= 'b0;
    end else if(data_input_trig == 1'b1) begin
        if(mem_w_addr_a == FIR_TAP - 1) begin
            mem_r_addr_a_base <= 'b0;
        end else begin
            mem_r_addr_a_base <= mem_w_addr_a + 1'b1;
        end
    end else if(cal_flag == 1'b1) begin
        if(mem_r_addr_a_base < MULT_NUM) begin
            mem_r_addr_a_base <= FIR_TAP - (MULT_NUM - mem_r_addr_a_base);
        end else begin
            mem_r_addr_a_base <= mem_r_addr_a_base - MULT_NUM;
        end
    end
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        if(data_input_trig == 1'b1) begin
            mem_rw_addr_a[i] = mem_w_addr_a;
        end else begin
            if(mem_r_addr_a_base < i) begin
                mem_rw_addr_a[i] = FIR_TAP - (i - mem_r_addr_a_base);
            end else begin
                mem_rw_addr_a[i] = mem_r_addr_a_base - i;
            end
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_w_addr_b_base <= 'b0;
    end else if(data_input_trig == 1'b1) begin
        if(mem_w_addr_a == FIR_TAP - 1) begin
            mem_w_addr_b_base <= 'b1;
        end else if(mem_w_addr_a == FIR_TAP - 2) begin
            mem_w_addr_b_base <= 'b0;
        end else begin
            mem_w_addr_b_base <= mem_w_addr_a + 'h2;
        end
    end else if(cal_flag == 1'b1) begin
        if(mem_w_addr_b_base + MULT_NUM > FIR_TAP - 1) begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM - FIR_TAP;
        end else begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM;
        end
    end
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        if(mem_w_addr_b_base + i > FIR_TAP - 1) begin
            mem_w_addr_b[i] = mem_w_addr_b_base + i - FIR_TAP;
        end else begin
            mem_w_addr_b[i] = mem_w_addr_b_base + i;
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_r_addr_base <= 'b0;
    end else if(cal_flag == 1'b1) begin
        if(cal_end_flag == 1'b1) begin
            rom_r_addr_base <= 'b0;
        end else begin
            rom_r_addr_base <= rom_r_addr_base + MULT_NUM;
        end
    end 
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        rom_r_addr[i] = rom_r_addr_base + i;
    end
end

generate
for(genvar j = 0; j < MULT_NUM; j++) begin
blk_mem_gen_fir blk_mem_gen_fir_inst (
    .clka(clk),    // input wire clka
    .wea(data_input_trig),      // input wire [0 : 0] wea
    .addra(mem_rw_addr_a[j]),  // input wire [RW_ADDR_WIDTH-1 : 0] addra
    .dina(s_axis_tdata),    // input wire [DATA_WIDTH-1 : 0] dina
    .douta(mem_odata_a[j]),  // output wire [DATA_WIDTH-1 : 0] douta

    .clkb(clk),    // input wire clkb
    .web(1'b0),      // input wire [0 : 0] web
    .addrb(mem_w_addr_b[j]),  // input wire [RW_ADDR_WIDTH-1 : 0] addrb
    .dinb('b0),    // input wire [DATA_WIDTH-1 : 0] dinb
    .doutb(mem_odata_b[j])  // output wire [DATA_WIDTH-1 : 0] doutb
);

dist_mem_gen_fir dist_mem_gen_fir_inst (
    .clk(clk),    // input wire clk
    .a(rom_r_addr[j]),   // input wire [RW_ADDR_WIDTH-2 : 0] a
    .qspo(rom_odata[j])  // output wire [COE_WIDTH-1 : 0] qspo
);
end
endgenerate

// add & coefficient mult
generate
for(genvar k = 0; k < MULT_NUM; k++) begin
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        coe_data_reg[k] <= 'sb0;
    end else if(cflag_pl[0] == 1'b1) begin
        coe_data_reg[k] <= rom_odata[k];
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_odata_add[k] <= 'sb0;
    end else if(cflag_pl[0] == 1'b1) begin
        mem_odata_add[k] <= $signed({mem_odata_a[k][DATA_WIDTH-1], mem_odata_a[k]}) + $signed({mem_odata_b[k][DATA_WIDTH-1], mem_odata_b[k]});
    end
end
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_odata_mul[k] <= 'sb0;
    end else if(cflag_pl[1] == 1'b1) begin
        mem_odata_mul[k] <= mem_odata_add[k] * coe_data_reg[k];
    end
end
end
endgenerate

// data acc
generate
for(genvar q = 0; q < ACC_STAGE0; q++) begin
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        muled_data_acc0[q] <= 'sb0;
    end else if(cflag_pl[2] == 1'b1) begin
        automatic logic signed [MUL_WIDTH+ACC_WIDTH_INC-1:0] sum_temp;
        sum_temp = 'sb0;
        for (integer i = 0; i < FIR_ACC_TIME; i++) begin
            sum_temp = sum_temp + mem_odata_mul[i+q*FIR_ACC_TIME];
        end
        muled_data_acc0[q] <= sum_temp;
    end
end
end
endgenerate
generate
for(genvar p = 0; p < ACC_STAGE1; p++) begin
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        muled_data_acc1[p] <= 'sb0;
    end else if(cflag_pl[3] == 1'b1) begin
        automatic logic signed [MUL_WIDTH+ACC_WIDTH_INC*2-1:0] sum_temp;
        sum_temp = 'sb0;
        for (integer i = 0; i < FIR_ACC_TIME; i++) begin
            sum_temp = sum_temp + muled_data_acc0[i+p*FIR_ACC_TIME];
        end
        muled_data_acc1[p] <= sum_temp;
    end
end
end
endgenerate
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        for(integer i = 0; i < 2; i++) begin
            muled_data_acc_end[i] <= 'sb0;
        end
    end else if(cflag_pl[4] == 1'b1) begin
        automatic logic signed [ACC_WIDTH_END-1:0] sum_temp;
        sum_temp = 'sb0;
        for (integer i = 0; i < ACC_STAGE1; i++) begin
            sum_temp = sum_temp + muled_data_acc1[i];
        end
        muled_data_acc_end[data_acc_sel] <= muled_data_acc_end[data_acc_sel] + sum_temp;
        muled_data_acc_end[~data_acc_sel] <= 'sb0;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        data_acc_sel <= 1'b0;
    end else if(pl_acc_trig == 1'b1) begin
        data_acc_sel <= ~data_acc_sel;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        scaled_data <= 'sb0;
    end else if(pl_end_trig == 1'b1) begin
        scaled_data <= muled_data_acc_end[~data_acc_sel] >>> DML_LEN;
    end
end
assign m_axis_tdata =
(scaled_data > SHIFT_DATA_MAX) ? SHIFT_DATA_MAX :
(scaled_data < SHIFT_DATA_MIN) ? SHIFT_DATA_MIN :
scaled_data[DATA_WIDTH-1:0];

endmodule
