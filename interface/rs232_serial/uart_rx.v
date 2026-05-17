//serial receive
module uart_rx #(
parameter UART_BPS = 'd9600, //uart baud rate
parameter CLK_FREQ = 'd50_000_000 //clk freq
)
(
   input wire sys_clk, sys_rst_n, rx,
   output reg po_flag,
   output reg [7:0]po_data
);

reg rx_reg1, rx_reg2, rx_reg3, start_nedge, work_en, bit_flag, rx_flag;
reg [12:0] baud_cnt;
reg [3:0] bit_cnt;
reg [7:0] rx_data;

localparam BAUD_CNT_MAX = CLK_FREQ/UART_BPS;

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n) begin
      rx_reg1 <= 1'b1;
      rx_reg2 <= 1'b1;
      rx_reg3 <= 1'b1;
   end
   else begin
      rx_reg1 <= rx;
      rx_reg2 <= rx_reg1;
      rx_reg3 <= rx_reg2;
   end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   start_nedge <= 1'b0;
   else if((~rx_reg2) && (rx_reg3))
   start_nedge <= 1'b1;
   else
   start_nedge <= 1'b0;
end

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
   else if(baud_cnt == BAUD_CNT_MAX / 2 - 1)
   bit_flag <= 1'b1;
   else
   bit_flag <= 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   bit_cnt <= 4'd0;
   else if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
   bit_cnt <= 4'd0;
   else if(bit_flag == 1'b1)
   bit_cnt <= bit_cnt + 4'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   work_en <= 1'b0;
   else if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
   work_en <= 1'b0;
   else if(start_nedge == 1'b1)
   work_en <= 1'b1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   rx_data <= 8'b0;
   else if((bit_cnt >= 4'd1) && (bit_flag == 1'b1))
   rx_data <= {rx_reg3, rx_data[7:1]};
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   rx_flag <= 1'b0;
   else if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
   rx_flag <= 1'b1;
   else
   rx_flag <= 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   po_data <= 8'd0;
   else if(rx_flag == 1'b1)
   po_data <= rx_data;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
   if(!sys_rst_n)
   po_flag <= 1'b0;
   else
   po_flag <= rx_flag;
end

endmodule
