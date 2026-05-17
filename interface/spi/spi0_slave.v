module spi0_slave (
    input wire sys_rst_n, cs_n, sck, mosi,
    input wire [7:0] data_out,

    output wire [7:0] data,
    output reg miso
);

wire [7:0] data_send;
reg [7:0] data_rec;
reg [2:0] sck_cnt;

always @(posedge sck or negedge sys_rst_n or posedge cs_n) begin
    if(!sys_rst_n || cs_n)
    sck_cnt <= 3'd7;
    else
    sck_cnt <= sck_cnt - 3'd1;
end

assign data_send = (!sys_rst_n) ? 8'b0 : ((sck_cnt == 3'd7) ? data_out : data_send);

always @(posedge sck or negedge sys_rst_n or posedge cs_n) begin
    if(!sys_rst_n || cs_n)begin
        data_rec <= 8'b0;
        miso <= 1'b0;
    end
    else begin
        data_rec[sck_cnt] <= mosi;
        miso <= data_send[sck_cnt];
    end
end

assign data = (!sys_rst_n) ? 8'b0 : ((sck_cnt == 3'd0) ? data_rec : data);

endmodule
