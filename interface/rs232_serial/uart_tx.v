//serial transmit
module uart_tx #(
parameter UART_BPS = 'd9600, //uart baud rate
parameter CLK_FREQ = 'd50_000_000 //clk freq
)
(
   input wire sys_clk, sys_rst_n, pi_flag,
   input wire [7:0]pi_data,

   output reg tx
);

reg work_en, bit_flag;
reg [12:0] baud_cnt;
reg [3:0] bit_cnt;

localparam BAUD_CNT_MAX = CLK_FREQ/UART_BPS;

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   baud_cnt <= 13'd0;
   else if((baud_cnt == BAUD_CNT_MAX - 1) || (work_en == 1'b0))
   baud_cnt <= 13'd0;
   else if(work_en == 1'b1)
   baud_cnt <= baud_cnt + 13'b1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   bit_flag <= 1'b0;
   else if(baud_cnt == 13'd1)
   bit_flag <= 1'b1;
   else
   bit_flag <= 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   bit_cnt <= 4'd0;
   else if((bit_cnt == 4'd9) && (bit_flag == 1'b1))
   bit_cnt <= 4'd0;
   else if(bit_flag == 1'b1)
   bit_cnt <= bit_cnt + 4'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   work_en <= 1'b0;
   else if((bit_cnt == 4'd9) && (bit_flag == 1'b1))
   work_en <= 1'b0;
   else if(pi_flag == 1'b1)
   work_en <= 1'b1;
end

always@(posedge sys_clk or negedge sys_rst_n)
if(sys_rst_n == 1'b0)
tx <= 1'b1; //idle high
else if(bit_flag == 1'b1) begin
   case(bit_cnt)
   0 : tx <= 1'b0;
   1 : tx <= pi_data[0];
   2 : tx <= pi_data[1];
   3 : tx <= pi_data[2];
   4 : tx <= pi_data[3];
   5 : tx <= pi_data[4];
   6 : tx <= pi_data[5];
   7 : tx <= pi_data[6];
   8 : tx <= pi_data[7];
   9 : tx <= 1'b1;
   default : tx <= 1'b1;
   endcase
end

endmodule
