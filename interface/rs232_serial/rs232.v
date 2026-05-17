//rs232 serial
module rs232 (
   input wire sys_clk, sys_rst_n, rx,
   input wire [7:0] pi_data,

   output wire tx,
   output wire [7:0] po_data
);

parameter
UART_BPS = 'd9600, //uart baud rate
CLK_FREQ = 'd50_000_000; //clk freq

wire po_flag, pi_flag;

uart_rx #(
   .UART_BPS(UART_BPS),
   .CLK_FREQ(CLK_FREQ)
)
uart_rx_inst0 (
   .sys_clk(sys_clk),
   .sys_rst_n(sys_rst_n),
   .rx(rx),

   .po_flag(po_flag),
   .po_data(po_data)
);

uart_tx #(
   .UART_BPS(UART_BPS),
   .CLK_FREQ(CLK_FREQ) 
)
uart_tx_inst0 (
   .sys_clk(sys_clk),
   .sys_rst_n(sys_rst_n),
   .pi_flag(pi_flag),
   .pi_data(pi_data),

   .tx(tx)
);

data_detect data_detect_inst0(
	.sys_clk(sys_clk),
   .sys_rst_n(sys_rst_nrst),
	.data(pi_data),

	.flag(pi_flag)
);

endmodule

module data_detect (
	input wire sys_clk, sys_rst_n,
	input wire [7:0]data,

	output reg flag
);

reg [7:0] data_reg;

//assign flag = (!sys_rst_n) ? 1'b0 : (data_reg != data) ? 1'b1 : 1'b0;

always @(posedge sys_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
	flag <= 1'b0;
	else if(data_reg != data)
	flag <= 1'b1;
	else
	flag <= 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
	data_reg <= 8'b0;
	else
	data_reg <= data;
end

endmodule
