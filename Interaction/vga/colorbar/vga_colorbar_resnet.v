//vga controller with resistor network
module vga_colorbar_resnet (
   	input wire sys_clk, sys_rst_n,

   	output wire hsync, vsync,
   	output wire [15:0] rgb
);

wire vga_clk, locked, rst_n;
wire [9:0] pix_x, pix_y;
wire [15:0] pix_data;

assign rst_n = sys_rst_n & locked;

clk_div clk_div_inst0 (
	.sys_clk(sys_clk),
	.sys_rst_n(sys_rst_n),

	.locked(locked),
	.div_clk(vga_clk)
);

vga_ctrl vga_ctrl_inst0 (
	.vga_clk(vga_clk),
	.sys_rst_n(rst_n),
	.pix_data(pix_data),

	.hsync(hsync),
	.vsync(vsync),
	.pix_x(pix_x),
	.pix_y(pix_y),
	.rgb(rgb)
);

vga_pic vga_pic_inst0 (
	.vga_clk(vga_clk),
	.sys_rst_n(rst_n),
	.pix_x(pix_x),
	.pix_y(pix_y),

	.pix_data(pix_data)
);

endmodule