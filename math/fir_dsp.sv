module fir_dsp#(
    parameter integer MULT_NUM = 4,
    parameter integer FIR_N = 32,
    parameter integer COE_WIDTH = 18,
    parameter integer INPUT_WIDTH = 16,
    parameter integer OUTPUT_WIDTH = 16
)(
    input       clk,
    input       rstn,

    output                        s_axis_tready,
    input                         s_axis_tvalid,
    input      [INPUT_WIDTH-1:0]  s_axis_tdata,

    // input                         m_axis_tready,
    output                        m_axis_tvalid,
    output     [OUTPUT_WIDTH-1:0] m_axis_tdata
);

localparam integer ACC_DATA_WIDTH = $clog2((INPUT_WIDTH+COE_WIDTH)*FIR_N);
localparam integer FIR_MULT_TIMES = FIR_N/MULT_NUM;
localparam integer FIR_N_HALF = FIR_N/2;

// fir state
localparam
IDLE = 'h0,
FIR_CAL = 'h1;
logic [0:0] state;
logic data_input_trig;
logic cal_flag;
// status pipeline
localparam integer CFLAG_PIPE_LEN = 4;
logic cflag_pl[CFLAG_PIPE_LEN-1:0];
logic cflag_pl_end;
logic dout_valid;
// data storage & coefficient rom
logic [11:0] mem_w_addr_a;
logic [11:0] mem_r_addr_a_base;
logic [11:0] mem_rw_addr_a[MULT_NUM-1:0];
logic signed [INPUT_WIDTH-1:0] mem_odata_a[MULT_NUM-1:0];
logic [INPUT_WIDTH-1:0] mem_w_addr_b_base;
logic [INPUT_WIDTH-1:0] mem_w_addr_b[MULT_NUM-1:0];
logic signed [INPUT_WIDTH-1:0] mem_odata_b[MULT_NUM-1:0];
logic mem_rsta_busy[MULT_NUM-1:0];
logic [INPUT_WIDTH-2:0] rom_r_addr_base;
logic [INPUT_WIDTH-2:0] rom_r_addr[MULT_NUM-1:0];
logic signed [COE_WIDTH-1:0] rom_odata[MULT_NUM-1:0];
// add & coefficient mult
logic signed [COE_WIDTH-1:0] coe_data_reg[MULT_NUM-1:0];
logic signed [INPUT_WIDTH:1] mem_odata_add[MULT_NUM-1:0];
logic signed [INPUT_WIDTH+COE_WIDTH-1:1] mem_odata_mul[MULT_NUM-1:0];
logic signed [ACC_DATA_WIDTH-1:1] muled_data_acc;
logic signed [OUTPUT_WIDTH-1:1] acced_data;

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
assign s_axis_tready = (state == IDLE) && (mem_rsta_busy[0] == 1'b0);
assign data_input_trig = (s_axis_tvalid == 1'b1) && (state == IDLE) && (mem_rsta_busy[0] == 1'b0);
assign cal_flag = (state == FIR_CAL);

// status pipeline
always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        for(integer i = 0; i < MULT_NUM; i++) begin
            cflag_pl[i] <= 1'b0;
        end
    end else begin
        cflag_pl[0] <= cal_flag;
        for(integer i = 0; i < (CFLAG_PIPE_LEN-2); i++) begin
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
        if(mem_w_addr_a == FIR_N - 1) begin
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
        if(mem_r_addr_a_base - MULT_NUM > FIR_N - 1) begin
            mem_r_addr_a_base <= FIR_N - (MULT_NUM - mem_r_addr_a_base);
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
            if(mem_r_addr_a_base - i > FIR_N - 1) begin
                mem_rw_addr_a[i] = FIR_N - (i - mem_r_addr_a_base);
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
        if(mem_w_addr_b_base + MULT_NUM > FIR_N - 1) begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM - FIR_N;
        end else begin
            mem_w_addr_b_base <= mem_w_addr_b_base + MULT_NUM;
        end
    end else begin
        mem_w_addr_b_base <= mem_w_addr_a + 1'b1;
    end
end
always_comb begin
    for(integer i = 0; i < MULT_NUM; i++) begin
        if(mem_w_addr_b_base + i > FIR_N - 1) begin
            mem_w_addr_b[i] = mem_w_addr_b_base + i - FIR_N;
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
    .addra(mem_rw_addr_a[j]),  // input wire [11 : 0] addra
    .dina(s_axis_tdata),    // input wire [15 : 0] dina
    .douta(mem_odata_a[j]),  // output wire [15 : 0] douta

    .clkb(clk),    // input wire clkb
    .rstb(~rstn),            // input wire rstb
    .web(1'b0),      // input wire [0 : 0] web
    .addrb(mem_w_addr_b[j]),  // input wire [11 : 0] addrb
    .dinb(16'b0),    // input wire [15 : 0] dinb
    .doutb(mem_odata_b[j]),  // output wire [15 : 0] doutb

    .rsta_busy(mem_rsta_busy[j]),  // output wire rsta_busy
    .rstb_busy()  // output wire rstb_busy
);

dist_mem_gen_fir dist_mem_gen_fir_inst (
    .clk(clk),    // input wire clk
    .a(rom_r_addr[j]),   // input wire [10 : 0] a
    .qspo(rom_odata[j])  // output wire [17 : 0] spo
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

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        muled_data_acc <= 'sb0;
    end else if(cflag_pl[2] == 1'b1) begin
        automatic logic signed [ACC_DATA_WIDTH-1:0] sum_temp;
        sum_temp = 'sb0;
        for (integer i = 0; i < MULT_NUM; i++) begin
            sum_temp = sum_temp + mem_odata_mul[i];
        end
        muled_data_acc <= muled_data_acc + sum_temp;
    end else begin
        muled_data_acc <= 'sb0;
    end
end

always_ff@(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        acced_data <= 'sb0;
    end else if(cflag_pl_end == 1'b1) begin
        acced_data <= muled_data_acc >>> (ACC_DATA_WIDTH - OUTPUT_WIDTH);
    end
end
assign m_axis_tdata = acced_data;

endmodule
