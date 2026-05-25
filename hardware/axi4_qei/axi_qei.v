module axi_qei #(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_LEN = 4,

    parameter integer AXI_QEI_DEFAULT_SET_CNT = 8,
    parameter integer AXI_QEI_CNT_WIDTH = 16
)(
    input           clk,
    input           rstn,

    input   [AXI_ADDR_LEN - 1:0]   waddr,
    input   [AXI_ADDR_LEN - 1:0]   raddr,
    input   [AXI_DATA_WIDTH - 1:0]  wdata,
    input           wr_en,
    input           rd_en,
    input   [3:0]   wstrb,
    output  [AXI_DATA_WIDTH - 1:0]  rdata,

    input           qei0,
    input           qei1,
    
    output          axi_qei_interrupt
);

localparam DEBOUNCE_DELAY_MAX = 16'd65535; // 100M clk
localparam integer AXI_QEI_DEBOUNCE_WIDTH = 4;

// axi state
localparam
AXI_QEI_CNT_SET = 4'h0,
AXI_QEI_CNT = 4'h1,
AXI_QEI_DEBOUNCE = 4'h2,
AXI_QEI_POLARITY = 4'h3,
AXI_QEI_PENDING = 4'h4;

// global value
reg    [AXI_DATA_WIDTH - 1:0]  axi_rdata;
reg    [AXI_QEI_CNT_WIDTH - 1:0]  qei_cnt_set;
reg    [AXI_QEI_CNT_WIDTH - 1:0]  qei_cnt;
reg    [AXI_QEI_DEBOUNCE_WIDTH - 1:0]  qei_debounce_set;
reg           qei_pending_clr;
reg           qei_pending;
reg           qei_pre_polarity;
reg           qei_polarity;
reg           qei0_dy;
reg           qei1_dy;
wire          qei0_up_trig;
reg    [AXI_QEI_DEBOUNCE_WIDTH - 1:0]  qei_debounce_times;
reg    [AXI_QEI_DEBOUNCE_WIDTH - 1:0]  qei_debounce_cnt;
reg    [15:0]  qei_debounce_cnt_delay;
reg           qei_debounce_cnt_flag;
reg           qei_cnt_trig;

// read
always @(*) begin
    case(raddr)
        AXI_QEI_CNT_SET: axi_rdata = {16'b0, qei_cnt_set};
        AXI_QEI_CNT: axi_rdata = {16'b0, qei_cnt};
        AXI_QEI_DEBOUNCE: axi_rdata = {28'b0, qei_debounce_set};
        AXI_QEI_POLARITY: axi_rdata = {31'b0, qei_polarity};
        AXI_QEI_PENDING: axi_rdata = {31'b0, qei_pending};
        default: axi_rdata = 32'b0;
    endcase
end

assign rdata = axi_rdata;

// write
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_cnt_set <= AXI_QEI_DEFAULT_SET_CNT;
        qei_debounce_set <= 'b0;
        qei_pending_clr <= 1'b0;
    end
    else if(wr_en == 1'b1) begin
        case(waddr)
        AXI_QEI_CNT_SET: qei_cnt_set <= wdata[AXI_QEI_CNT_WIDTH - 1:0];
        AXI_QEI_DEBOUNCE: qei_debounce_set <= wdata[AXI_QEI_DEBOUNCE_WIDTH - 1:0];
        AXI_QEI_PENDING: qei_pending_clr <= wdata[0:0];
        endcase
    end
    else begin
        qei_pending_clr <= 1'b0;
    end
end

// qei signal detect
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei0_dy <= 1'b0;
        qei1_dy <= 1'b0;
    end
    else begin
        qei0_dy <= qei0;
        qei1_dy <= qei1;
    end
end

assign qei0_up_trig = qei0 & ~qei0_dy;

// qei debounce
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_debounce_cnt_flag <= 1'b0;
    end
    else if(qei0_up_trig == 1'b1) begin
        qei_debounce_cnt_flag <= 1'b1;
    end
    else if(qei_debounce_times == qei_debounce_set) begin
        qei_debounce_cnt_flag <= 1'b0;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_debounce_cnt_delay <= 'b0;
    end
    else if(qei_debounce_cnt_flag == 1'b1) begin
        if(qei_debounce_cnt_delay == DEBOUNCE_DELAY_MAX) begin
            qei_debounce_cnt_delay <= 'b0;
        end
        else begin
            qei_debounce_cnt_delay <= qei_debounce_cnt_delay + 1'b1;
        end
    end
    else begin
        qei_debounce_cnt_delay <= 'b0;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_debounce_times <= 'b0;
        qei_debounce_cnt <= 'b0;
    end
    else if((qei_debounce_times == qei_debounce_set) && (qei_debounce_set > 'b0)) begin
        qei_debounce_times <= 'b0;
        qei_debounce_cnt <= 'b0;
    end
    else if(qei_debounce_cnt_delay == DEBOUNCE_DELAY_MAX) begin
        qei_debounce_times <= qei_debounce_times + 1'b1;

        if(qei0_dy == 1'b1) begin
            qei_debounce_cnt <= qei_debounce_cnt + 1'b1;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_cnt_trig <= 1'b0;
    end
    else if(qei_debounce_set == 'b0) begin
        qei_cnt_trig <= qei0_up_trig; 
    end
    else if((qei_debounce_times == qei_debounce_set) && (qei_debounce_cnt == qei_debounce_set)) begin
        qei_cnt_trig <= 1'b1;
    end
    else begin
        qei_cnt_trig <= 1'b0;
    end
end

// qei polarity
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_pre_polarity <= 1'b0;
    end
    else if((qei0_up_trig == 1'b1) && (qei_debounce_cnt_flag == 1'b0)) begin
        qei_pre_polarity <= qei1_dy;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_polarity <= 1'b0;
    end
    else if(qei_cnt_trig == 1'b1) begin
        qei_polarity <= (qei_debounce_set == 'b0) ? qei1_dy : qei_pre_polarity;
    end
end

// qei interrupt
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_cnt <= 'b0;
    end
    else if(qei_cnt_trig == 1'b1) begin
        if(qei_cnt + 1'b1 >= qei_cnt_set) begin
            qei_cnt <= 'b0;
        end
        else begin
            qei_cnt <= qei_cnt + 1'b1;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        qei_pending <= 1'b0;
    end
    else if((qei_cnt_trig == 1'b1) && (qei_cnt + 1'b1 >= qei_cnt_set)) begin
        qei_pending <= 1'b1;
    end
    else if(qei_pending_clr == 1'b1) begin
        qei_pending <= 1'b0;
    end
end

assign axi_qei_interrupt = qei_pending;

endmodule
