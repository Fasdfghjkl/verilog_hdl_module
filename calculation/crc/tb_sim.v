`timescale 1ns / 1ns

module tb_sim();

reg sys_clk;
reg sys_rst_n;

wire  [15:0]  crc_out;
wire  [15:0]  crc_out_ivt;
reg           crc_en;
reg   [15:0]  data;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n = 1'b0;
//add
crc_en = 1'b0;
data = 16'b0;
#100
sys_rst_n <= 1'b1;
//add
#50
crc_en <= 1'b1;
data <= 16'h1C;
#40
crc_en <= 1'b0;
end

//sys_clk
always #10 sys_clk = ~sys_clk;
//add
assign crc_out_ivt =
{
  ~crc_out[0],  ~crc_out[1],  ~crc_out[2],  ~crc_out[3],
  ~crc_out[4],  ~crc_out[5],  ~crc_out[6],  ~crc_out[7],
  ~crc_out[8],  ~crc_out[9],  ~crc_out[10], ~crc_out[11],
  ~crc_out[12], ~crc_out[13], ~crc_out[14], ~crc_out[15]
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
crc16_16b crc16_16b_inst0 (
  .clk(sys_clk),
  .rst(~sys_rst_n),

  .crc_en(crc_en),
  .data_in(data),

  .crc_out(crc_out)
);

endmodule
