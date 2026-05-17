`timescale 1ns/1ns
module tb_spi();

reg sys_clk, sys_rst_n;
reg [7:0] data_master_send, data_slave_send;

wire cs_n, sck, mosi, miso;
wire [7:0] data_master_rec, data_slave_rec;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n <= 1'b0;
//add
data_master_send <= 8'b0;
data_slave_send <= 8'b0;
#200
sys_rst_n <= 1'b1;
end

//sys_clk
always #10 sys_clk = ~sys_clk;
//add
always #10000 data_master_send = data_master_send + 8'd10;
always #10 data_slave_send = data_slave_rec / 8'd2;

spi0_master spi0_master_inst0 (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .miso(miso),
    .data(data_master_send),

    .cs_n(cs_n),
    .sck(sck),
    .mosi(mosi),
    .data_out(data_master_rec)
);

spi0_slave spi0_slave_inst0 (
    .sys_rst_n(sys_rst_n),
    .cs_n(cs_n),
    .sck(sck),
    .mosi(mosi),
    .data_out(data_slave_send),

    .miso(miso),
    .data(data_slave_rec)
);

endmodule
