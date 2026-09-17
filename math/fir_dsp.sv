module fir_dsp#(
    parameter integer FIR_TAP = 128,
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
// status pipeline
localparam integer CFLAG_PIPE_LEN = 3 + FIR_ACC_LEN;
logic cflag_pl[CFLAG_PIPE_LEN-1:0];
logic cflag_pl_end;
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
logic mem_rsta_busy[MULT_NUM-1:0];
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
logic signed [ACC_WIDTH_END-1:0] muled_data_acc_end;
logic signed [ACC_WIDTH_END-1:0] scaled_data;

// fir state
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        state <= IDLE;
    end else begin
        case(state)
        IDLE: begin
            if((s_axis_tvalid == 1'b1) && (mem_rsta_busy[0] == 1'b0))begin
                state <= FIR_CAL;
            end
        end
        FIR_CAL: begin
            if(rom_r_addr_base == FIR_N_HALF - MULT_NUM) begin
                state <= IDLE;
            end
        end
        default: state <= IDLE;
        endcase
    end
end
assign s_axis_tready = (rstn == 1'b1) && (state == IDLE) && (mem_rsta_busy[0] == 1'b0);
assign data_input_trig = (rstn == 1'b1) && (s_axis_tvalid == 1'b1) && (state == IDLE) && (mem_rsta_busy[0] == 1'b0);
assign cal_flag = (state == FIR_CAL);

// status pipeline
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        for(integer i = 0; i < CFLAG_PIPE_LEN; i++) begin
            cflag_pl[i] <= 1'b0;
        end
    end else begin
        cflag_pl[0] <= cal_flag;
        for(integer i = 0; i < CFLAG_PIPE_LEN - 1; i++) begin
            cflag_pl[i+1] <= cflag_pl[i];
        end
    end
end

assign cflag_pl_end = ~cflag_pl[CFLAG_PIPE_LEN-2] & cflag_pl[CFLAG_PIPE_LEN-1];
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        dout_valid <= 1'b0;
    end else begin
        dout_valid <= cflag_pl_end;
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
    end else if(cal_flag == 1'b1) begin
        if(mem_r_addr_a_base - MULT_NUM > FIR_TAP - 1) begin
            mem_r_addr_a_base <= FIR_TAP - (MULT_NUM - mem_r_addr_a_base);
        end else begin
            mem_r_addr_a_base <= mem_r_addr_a_base - MULT_NUM;
        end
    end else begin
        mem_r_addr_a_base <= mem_w_addr_a;
    end
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        if(cal_flag == 1'b1) begin
            if(mem_r_addr_a_base - i > FIR_TAP - 1) begin
                mem_rw_addr_a[i] = FIR_TAP - (i - mem_r_addr_a_base);
            end else begin
                mem_rw_addr_a[i] = mem_r_addr_a_base - i;
            end
        end else begin
            mem_rw_addr_a[i] = mem_w_addr_a;
        end
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        mem_w_addr_b_base <= 'b0;
    end else if(cal_flag == 1'b1) begin
        if(mem_w_addr_b_base + MULT_NUM > FIR_TAP - 1) begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM - FIR_TAP;
        end else begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM;
        end
    end else begin
        mem_w_addr_b_base <= mem_w_addr_a + 1'b1;
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
        rom_r_addr_base <= rom_r_addr_base + MULT_NUM;
    end else begin
        rom_r_addr_base <= 'b0;
    end
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        if(cal_flag == 1'b1) begin
            rom_r_addr[i] = rom_r_addr_base + i;
        end else begin
            rom_r_addr[i] = 'b0;
        end
    end
end

generate
for(genvar j = 0; j < MULT_NUM; j++) begin
blk_mem_gen_fir blk_mem_gen_fir_inst (
    .clka(clk),    // input wire clka
    .rsta(~rstn),            // input wire rsta
    .wea(data_input_trig),      // input wire [0 : 0] wea
    .addra(mem_rw_addr_a[j]),  // input wire [6 : 0] addra
    .dina(s_axis_tdata),    // input wire [15 : 0] dina
    .douta(mem_odata_a[j]),  // output wire [15 : 0] douta

    .clkb(clk),    // input wire clkb
    .rstb(~rstn),            // input wire rstb
    .web(1'b0),      // input wire [0 : 0] web
    .addrb(mem_w_addr_b[j]),  // input wire [6 : 0] addrb
    .dinb(16'b0),    // input wire [15 : 0] dinb
    .doutb(mem_odata_b[j]),  // output wire [15 : 0] doutb

    .rsta_busy(mem_rsta_busy[j]),  // output wire rsta_busy
    .rstb_busy()  // output wire rstb_busy
);

dist_mem_gen_fir dist_mem_gen_fir_inst (
    .clk(clk),    // input wire clk
    .a(rom_r_addr[j]),   // input wire [5 : 0] a
    .qspo(rom_odata[j])  // output wire [23 : 0] spo
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
        mem_odata_add[k] <= mem_odata_a[k] + mem_odata_b[k];
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
    end else begin
        muled_data_acc0[q] <= 'sb0;
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
    end else begin
        muled_data_acc1[p] <= 'sb0;
    end
end
end
endgenerate
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        muled_data_acc_end <= 'sb0;
    end else if(cflag_pl[4] == 1'b1) begin
        automatic logic signed [ACC_WIDTH_END-1:0] sum_temp;
        sum_temp = 'sb0;
        for (integer i = 0; i < ACC_STAGE1; i++) begin
            sum_temp = sum_temp + muled_data_acc1[i];
        end
        muled_data_acc_end <= muled_data_acc_end + sum_temp;
    end else begin
        muled_data_acc_end <= 'sb0;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        scaled_data <= 'sb0;
    end else if(cflag_pl_end == 1'b1) begin
        scaled_data <= muled_data_acc_end >>> DML_LEN;
    end
end
assign m_axis_tdata =
(scaled_data > SHIFT_DATA_MAX) ? SHIFT_DATA_MAX :
(scaled_data < SHIFT_DATA_MIN) ? SHIFT_DATA_MIN :
scaled_data[DATA_WIDTH-1:0];

endmodule
