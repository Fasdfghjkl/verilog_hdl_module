//image data generator
module vga_pic (
	input wire vga_clk, sys_rst_n,
  	input wire [9:0] pix_x, pix_y,

	output reg [23:0] pix_data
);

//parameter define
parameter H_VALID = 10'd640 ,
V_VALID = 10'd480 ;
parameter RED = 24'hFF0000, //red
ORANGE = 24'hFF8000, //orange
YELLOW = 24'hFFFF00, //yellow
GREEN = 24'h00FF00, //green
CYAN = 24'h00FFFF, //cyan
BLUE = 24'h0000FF, //blue
PURPPLE = 24'h800080, //purple
BLACK = 24'h000000, //black
WHITE = 24'hFFFFFF, //white
GRAY = 24'h808080; //gray

always @(posedge vga_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
	pix_data <= 16'h0;
	else if((pix_x >= 10'd0) && (pix_x < (H_VALID / 10) * 1))
	pix_data <= RED;
	else if((pix_x >= (H_VALID / 10) * 1) && (pix_x < (H_VALID / 10) * 2))
	pix_data <= ORANGE;
	else if((pix_x >= (H_VALID / 10) * 2) && (pix_x < (H_VALID / 10) * 3))
	pix_data <= YELLOW;
	else if((pix_x >= (H_VALID / 10) * 3) && (pix_x < (H_VALID / 10) * 4))
	pix_data <= GREEN;
	else if((pix_x >= (H_VALID / 10) * 4) && (pix_x < (H_VALID / 10) * 5))
	pix_data <= CYAN;
	else if((pix_x >= (H_VALID / 10) * 5) && (pix_x < (H_VALID / 10) * 6))
	pix_data <= BLUE;
	else if((pix_x >= (H_VALID / 10) * 6) && (pix_x < (H_VALID / 10) * 7))
	pix_data <= PURPPLE;
	else if((pix_x >= (H_VALID / 10) * 7) && (pix_x < (H_VALID / 10) * 8))
	pix_data <= BLACK;
	else if((pix_x >= (H_VALID / 10) * 8) && (pix_x < (H_VALID / 10) * 9))
	pix_data <= WHITE;
	else if((pix_x >= (H_VALID / 10) * 9) && (pix_x < H_VALID))
	pix_data <= GRAY;
	else
	pix_data <= BLACK;
end

endmodule