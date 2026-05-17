module dac8164 (
    input wire sys_clk, sys_rst_n,
    input wire en_w,
    input wire [2:0] waddr,
    input wire [13:0] wdata,
    input wire load,
    output wire ready,

    output wire en_n, ldac,
    output reg ss_n,
    output wire sck,
    output wire mosi
);

// delay cnt
localparam
DELAY_SS = 4'd10,
DELAY_SSN = 4'd1;

// addr sel state
localparam
DATA = 3'h0,
CH = 3'h1,
LMOD = 3'h2,
POWER = 3'h3,
PDM = 3'h4,
ADDR = 3'h5;

// state matchine
localparam
IDLE = 3'd0,
CS_ACTIVE = 3'd1,
TRANSFER = 3'd2,
CS_DEACTIVE = 3'd3,
DONE = 3'd4;

// sck & flag
wire en;
reg div_clk;
reg ss_n_flag;

// wire & reg
reg [4:0] data_cnt;
wire data_done_flag;
reg [2:0] state;
wire delay_ss_flag;
reg rst_flag, sck_flag;
reg [3:0] delay_cnt;
reg [23:0] data_send;

// addr data
reg [13:0] data;
reg [1:0] ch, load_mod, pd_mode, addr_sel;
reg power;

// addr sel
always @(posedge en_w or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        data <= 14'd0;
        ch <= 2'd0;
        load_mod <= 2'b0;
        power <= 1'b1;
        pd_mode <= 2'b11;
        addr_sel <= 2'h0;
    end
    else if(ready == 1'b1) begin
        case(waddr)
        DATA: data <= wdata[13:0];
        CH: ch <= wdata[1:0];
        LMOD: load_mod <= wdata[1:0];
        POWER: power <= wdata[0];
        PDM: pd_mode <= wdata[1:0];
        ADDR: addr_sel <= wdata[1:0];
        endcase
    end
end

// sck gen
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    div_clk <= 1'b0;
    else
    div_clk <= ~div_clk; // 2 div
end

always @(posedge sys_clk or negedge rst_flag) begin
    if(!rst_flag)
    sck_flag <= 1'b0;
    else if(state == TRANSFER)
    sck_flag <= 1'b1;
end

assign sck = ((state != TRANSFER) || (sck_flag != 1'b1)) ? 1'b0 : (data_done_flag != 1'b1) ? div_clk : 1'b0;

// ready flag
assign ready = (!sys_rst_n) ? 1'b0 : (state == IDLE) ? 1'b1 : 1'b0;

always @(posedge sys_clk) begin
    if(!ss_n)
    ss_n_flag <= 1'b1;
    else
    ss_n_flag <= 1'b0;
end

assign data_cnt_reset = ((!ss_n) && (ss_n_flag == 1'b0)) ? 1'b1 : 1'b0;

always @(posedge sck or posedge data_cnt_reset) begin
    if(data_cnt_reset)
    data_cnt <= 5'd24;
    else
    data_cnt <= data_cnt - 5'd1;
end

// en ctrl
assign en = (waddr == DATA) ? en_w : 1'b0;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    rst_flag <= 1'b0;
    else if(en == 1'b1)
    rst_flag <= 1'b1;
    else if((state == DONE) && (delay_ss_flag == 1'b1))
    rst_flag <= 1'b0;
end

// data transfer finished flag
assign data_done_flag = ((data_cnt == 5'd0) && (sck == 1'b0)) ? 1'b1 : 1'b0;

// DELAY_SS max flag
assign delay_ss_flag = (delay_cnt >= (DELAY_SS - 4'd1)) ? 1'b1 : 1'b0;

// delay ctrl
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    delay_cnt <= 4'b0;
    else begin
        case(state)
        IDLE: delay_cnt <= 4'd0;
        CS_ACTIVE: delay_cnt <= delay_cnt + 4'd1;
        TRANSFER: delay_cnt <= delay_cnt;
        CS_DEACTIVE: delay_cnt <= delay_cnt - 4'd1;
        DONE: begin
            if(delay_ss_flag != 1'b1)
            delay_cnt <= delay_cnt + 4'd1;
        end
        default: delay_cnt <= 4'd0;
        endcase
    end
end

// state matchine
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        state <= IDLE;
        ss_n <= 1'b1;
    end
    else begin
        case(state)
        IDLE: begin
            if(rst_flag == 1'b1) begin
                state <= CS_ACTIVE;
                ss_n <= 1'b0;
            end
        end
        CS_ACTIVE: begin
            if(delay_cnt == (DELAY_SSN - 4'd1))
            state <= TRANSFER;
        end
        TRANSFER: begin
            if(data_done_flag == 1'b1)
            state <= CS_DEACTIVE;
        end
        CS_DEACTIVE: begin
            if(delay_cnt == 4'd1) begin
                state <= DONE;
                ss_n <= 1'b1;
            end
        end
        DONE: begin
            if(delay_ss_flag == 1'b1)
            state <= IDLE;
        end
        default: begin
            state <= IDLE;
            ss_n <= 1'b1;
        end
        endcase
    end
end

// external load
assign ldac = (ready == 1'b1) ? load : 1'b0;

// data send
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    data_send <= 24'b0;
    else if(power != 1'b1)
    data_send <= {addr_sel, load_mod, 1'b0, ch, 1'b0, data, 2'b0};
    else begin
        if(pd_mode != 2'b0)
        data_send <= {addr_sel, load_mod, 1'b0, ch, 1'b1, pd_mode, 12'b0, 2'b0};
        else
        data_send <= {addr_sel, load_mod, 1'b0, ch, 1'b1, 2'b11, 12'b0, 2'b0};
    end
end

assign mosi = (state != TRANSFER) ? 1'b0 : (data_cnt < 5'd24) ? data_send[data_cnt] : 1'b0;

// en_n
assign en_n = ~sys_rst_n;

endmodule

// top module
// dac8164 dac8164_inst0 (
//     .sys_clk(sys_clk),
//     .sys_rst_n(sys_rst_n),
//     .en_w(en_w),
//     .waddr(waddr),
//     .wdata(wdata),
//     .load(load),
//     .ready(ready),

//     .en_n(en_n),
//     .ldac(ldac),
//     .ss_n(ss_n),
//     .sck(sck),
//     .mosi(mosi)
// );