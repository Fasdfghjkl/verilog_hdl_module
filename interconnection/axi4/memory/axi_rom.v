module axi_rom #(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_LEN = 4,
    parameter integer ROM_WIDTH = 16,
    parameter integer ROM_ADDR_LEN = 12
)(
    input           clk,
    input           rstn,

    input   [AXI_ADDR_LEN - 1:0]   waddr,
    input   [AXI_ADDR_LEN - 1:0]   raddr,
    input   [AXI_DATA_WIDTH - 1:0]  wdata,
    input           wr_en,
    input   [3:0]   wstrb,
    output  [AXI_DATA_WIDTH - 1:0]  rdata,

    input           user_rd_valid,
    output          rom_clk,
    output  [ROM_ADDR_LEN - 1:0]  rom_addr,
    input   [ROM_WIDTH - 1:0]  rom_rdata,
    output  [ROM_WIDTH - 1:0]  rom_wdata,
    output          rom_rw
);

// axi state
localparam
AXI_RW = 4'h0,
AXI_RW_BASE_ADDR = 4'h1,
AXI_RW_TRIG = 4'h2;

// state matchine
localparam  ROM_RD = 1'b0;
localparam  ROM_WT = 1'b1;
reg           rom_rw_state;

// global value
reg    [AXI_DATA_WIDTH - 1:0]  axi_rdata;
reg    [ROM_ADDR_LEN - 1:0]  rom_rd_addr;
reg           rom_wt_en;
reg    [ROM_ADDR_LEN - 1:0]  rom_wt_addr_buf;
reg    [ROM_ADDR_LEN - 1:0]  rom_wt_addr;
reg    [ROM_ADDR_LEN - 1:0]  rom_rw_base_addr;
reg    [ROM_WIDTH - 1:0]  rom_wdata_buf;

// read
always @(*) begin
    case(raddr)
        AXI_RW: axi_rdata = {31'b0, rom_rw_state};
        AXI_RW_BASE_ADDR: axi_rdata = {16'h0, rom_rw_base_addr};
        AXI_RW_TRIG: axi_rdata = {16'b0, rom_rdata};
        default: axi_rdata = 32'b0;
    endcase
end

assign rdata = axi_rdata;

// write
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_rw_state <= ROM_RD;
        rom_rw_base_addr <= 'h0;
        rom_wdata_buf <= 'b0;
    end
    else if(wr_en == 1'b1) begin
        case(waddr)
        AXI_RW: rom_rw_state <= wdata[0:0];
        AXI_RW_BASE_ADDR: rom_rw_base_addr <= wdata[ROM_ADDR_LEN - 1:0];
        AXI_RW_TRIG: rom_wdata_buf <= wdata[ROM_WIDTH - 1:0];
        endcase
    end
end

assign rom_wdata = rom_wdata_buf;

// rw logic
assign rom_clk = clk;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_rd_addr <= 'h0;
    end
    else if(user_rd_valid == 1'b1) begin
        if(raddr == AXI_RW) begin
            rom_rd_addr <= rom_rw_base_addr;
        end
        else if(raddr == AXI_RW_TRIG) begin
            rom_rd_addr <= rom_rd_addr + 1'h1;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_wt_en <= 1'b0;
    end
    else begin
        if(wr_en == 1'b1 && waddr == AXI_RW_TRIG) begin
            rom_wt_en <= 1'b1;
        end
        else begin
            rom_wt_en <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_wt_addr_buf <= 'h0;
    end
    else if(wr_en == 1'b1) begin
        if(waddr == AXI_RW) begin
            rom_wt_addr_buf <= rom_rw_base_addr;
        end
        else if(waddr == AXI_RW_BASE_ADDR) begin
            rom_wt_addr_buf <= wdata[ROM_ADDR_LEN - 1:0];
        end
        else if(waddr == AXI_RW_TRIG) begin
            rom_wt_addr_buf <= rom_wt_addr_buf + 1'h1;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rom_wt_addr <= 'h0;
    end
    else begin
        rom_wt_addr <= rom_wt_addr_buf;
    end
end

assign rom_addr = (rom_rw_state == ROM_RD) ? rom_rd_addr : rom_wt_addr;

assign rom_rw = (rom_rw_state == ROM_WT) ? rom_wt_en : 1'b0;

endmodule
