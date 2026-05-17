//resistor network
module vga_resnet_ctrl (
	input wire vga_clk, sys_rst_n,
	input wire [23:0] pix_data,

	output wire hsync, vsync,
  	output wire [9:0] pix_x, pix_y,
   	output wire [23:0] rgb
);

reg [9:0] cnt_h, cnt_v;
wire rgb_valid, pix_data_req;

//parameter define
parameter H_SYNC = 10'd96 ,
H_BACK = 10'd40 , //hback porch
H_LEFT = 10'd8 , //hleft border
H_VALID = 10'd640 , //hvalid data
H_RIGHT = 10'd8 , //hright border
H_FRONT = 10'd8 , //hfront border
H_TOTAL = 10'd800 ; //htotal period
parameter V_SYNC = 10'd2 ,
V_BACK = 10'd25 , //vback porch
V_TOP = 10'd8 , //vtop border
V_VALID = 10'd480 , //vvalid data
V_BOTTOM = 10'd8 , //vbottom border
V_FRONT = 10'd2 , //vfront border
V_TOTAL = 10'd525 ; //vtotal period

always @(posedge vga_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
	cnt_h <= 10'd0;
	else if(cnt_h == H_TOTAL - 10'd1)
	cnt_h <= 10'd0;
	else
	cnt_h <= cnt_h + 10'd1;
end

assign hsync = ((cnt_h >= 10'd0) && (cnt_h <= H_SYNC - 10'd1)) ? 1'b1 : 1'b0;

always @(posedge vga_clk or negedge sys_rst_n) begin
	if(!sys_rst_n)
	cnt_v <= 10'd0;
	else if((cnt_v == V_TOTAL - 10'd1) && (cnt_h == H_TOTAL - 10'd1))
	cnt_v <= 10'd0;
	else if(cnt_h == H_TOTAL - 10'd1)
	cnt_v <= cnt_v + 10'd1;
end

assign vsync = ((cnt_v >= 10'd0) && (cnt_v <= V_SYNC - 10'd1)) ? 1'b1 : 1'b0;

assign rgb_valid = ((cnt_h >= H_SYNC + H_BACK + H_LEFT) && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID) && (cnt_v >= V_SYNC + V_BACK + V_TOP) && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID)) ? 1'b1 : 1'b0;

assign pix_data_req = ((cnt_h >= H_SYNC + H_BACK + H_LEFT - 10'd1) && (cnt_h < H_SYNC + H_BACK + H_LEFT + H_VALID - 10'd1) && (cnt_v >= V_SYNC + V_BACK + V_TOP) && (cnt_v < V_SYNC + V_BACK + V_TOP + V_VALID)) ? 1'b1 : 1'b0;

assign pix_x = pix_data_req ? (cnt_h - (H_SYNC + H_BACK + H_LEFT - 10'b1)) : 10'h3ff;

assign pix_y = pix_data_req ? (cnt_v - (V_SYNC + V_BACK + V_TOP)) : 10'h3ff;

assign rgb = rgb_valid ? pix_data : 24'b0;

endmodule