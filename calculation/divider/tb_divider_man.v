`timescale 1ns / 1ns

module tb_divider_man();

wire done;
wire [19:0] data;
wire [15:0] data_extra;
reg sys_clk, sys_rst_n;
reg ready;
reg [19:0] in1;
reg [15:0] in2, in2_reg;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n = 1'b0;
//add
in1 = 20'd1048575;
in2 = 16'd1024;
#100
sys_rst_n <= 1'b1;
end

//sys_clk
always #10 sys_clk = ~sys_clk;
//add
always @(posedge done) in2 <= in2 + 16'd512;

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   in2_reg <= 20'b0;
   else
   in2_reg <= in2;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   ready <= 1'b0;
   else if(in2_reg != in2)
   ready <= 1'b1;
   else
   ready <= 1'b0;
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
divider_man #(
   .N(20), //dividend width
   .M(16) //divisor width
)
divider_man_inst0 (
   .clk(sys_clk),
   .rstn(sys_rst_n),
   .data_rdy(ready),
   .dividend(in1),
   .divisor(in2_reg),
   
   .res_rdy(done),
   .merchant(data), //result, dividend width
   .remainder(data_extra) //divisor width
);

endmodule
