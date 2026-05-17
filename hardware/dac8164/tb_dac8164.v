`timescale 1ns / 1ns

module tb_dac8164();

wire ready;

reg sys_clk, sys_rst_n, en_w;
reg [13:0] wdata;
reg [2:0] waddr;

wire sck, mosi, ss_n;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n = 1'b0;
//add
en_w = 1'b0;
waddr = 3'h0;
wdata = 14'b0;

#200
sys_rst_n = 1'b1;
//add
waddr = 3'h1;
wdata = 2'd3;
#10
en_w = 1'b1;
#20
en_w = 1'b0;

#20
waddr = 3'h2;
wdata = 2'b01;
#10
en_w = 1'b1;
#20
en_w = 1'b0;

#20
waddr = 3'h3;
wdata = 1'b1;
#10
en_w = 1'b1;
#20
en_w = 1'b0;

#20
waddr = 3'h4;
wdata = 2'b10;
#10
en_w = 1'b1;
#20
en_w = 1'b0;

//
#400
waddr = 3'h0;
wdata = 14'd1145;
#10
en_w = 1'b1;
#20
en_w = 1'b0;
end

//sys_clk
always #5 sys_clk = ~sys_clk;
//add

dac8164 dac8164_inst0 (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .en_w(en_w),
    .waddr(waddr),
    .wdata(wdata),
    .load(1'b0),
    .ready(ready),

    .en_n(en_n),
    .ldac(),
    .ss_n(ss_n),
    .sck(sck),
    .mosi(mosi)
);

endmodule
