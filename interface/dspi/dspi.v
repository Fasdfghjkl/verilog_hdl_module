module dspi #(
    parameter   integer DATA_WIDTH = 16
) (
    input           rstn,
    input           clk,

    input   [DATA_WIDTH-1:0]  tdata,
    output  [DATA_WIDTH-1:0]  rdata,
    output                    rw_valid,

    input           sck,
    input           csn,
    input           mosi,
    output          miso
);

// global value
// data_rw
reg [$clog2(DATA_WIDTH)-1:0]  data_cnt;
reg [$clog2(DATA_WIDTH)-1:0]  data_cnt_reg0;
reg [$clog2(DATA_WIDTH)-1:0]  data_cnt_reg1;
reg [DATA_WIDTH-1:0]  tdata_latch;
reg [DATA_WIDTH-1:0]  rdata_reg;
reg [DATA_WIDTH-1:0]  rdata_buf;
reg                   miso_reg;
// rw flag
reg                   rw_valid_reg0;
reg                   rw_valid_reg1;

// state matchine
reg            state;
localparam
SPI_IDLE = 'b0,
SPI_CSN = 'b1;

// state
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        state <= SPI_IDLE;
    end else if(csn == 1'b0) begin
        state <= SPI_CSN;
    end else begin
        state <= SPI_IDLE;
    end
end

// rw data
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        tdata_latch <= 'b0;
    end else if(state == SPI_IDLE) begin
        tdata_latch <= tdata;
    end else if(rw_valid_reg1 == 1'b1) begin
        tdata_latch <= tdata;
    end 
end

always @(negedge sck or negedge rstn) begin
    if(rstn == 1'b0) begin
        miso_reg <= 1'b0;
    end else if(state == SPI_CSN)begin
        miso_reg <= tdata_latch[(DATA_WIDTH-1)-data_cnt];
    end else begin
        miso_reg <= tdata_latch[DATA_WIDTH-1];
    end
end
assign miso = miso_reg;

always @(posedge sck or negedge rstn) begin
    if(rstn == 1'b0) begin
        rdata_reg <= 'b0;
        data_cnt <= 'b0;
    end else if(state == SPI_CSN)begin
        rdata_reg[(DATA_WIDTH-1)-data_cnt] <= mosi;
        data_cnt <= data_cnt + 1'b1;
    end else begin
        data_cnt <= 'b0;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        data_cnt_reg0 <= 'b0;
        data_cnt_reg1 <= 'b0;
    end else if(state == SPI_IDLE)begin
        data_cnt_reg0 <= 'b0;
        data_cnt_reg1 <= 'b0;
    end else begin
        data_cnt_reg0 <= data_cnt;
        data_cnt_reg1 <= data_cnt_reg0;
    end
end

// rw flag
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rw_valid_reg0 <= 1'b0;
        rdata_buf <= 'b0;
    end else if((data_cnt_reg0 == 'b0) && (data_cnt_reg1 == DATA_WIDTH-1)) begin
        rw_valid_reg0 <= 1'b1;
        rdata_buf <= rdata_reg;
    end else begin
        rw_valid_reg0 <= 1'b0;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rw_valid_reg1 <= 1'b0;
    end else begin
        rw_valid_reg1 <= rw_valid_reg0;
    end
end

assign rdata = rdata_buf;
assign rw_valid = rw_valid_reg0;

endmodule
