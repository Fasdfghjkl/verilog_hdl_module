//vga controller with DAC
module vga_colorbar_dac (
   	input wire sys_clk, sys_rst_n,

   	output wire hsync, vsync, vga_clk, vga_sync_n, vga_blank_n,
   	output wire [7:0] vga_r, vga_g, vga_b
);

wire locked, rst_n;
wire [9:0] pix_x, pix_y;
wire [23:0] pix_data;

assign rst_n = sys_rst_n & locked;

assign vga_blank_n = sys_rst_n; // VGA blank signal, active low

assign vga_sync_n = 1'b0; // VGA sync signal, active low

clk_div clk_div_inst0 (
	.sys_clk(sys_clk),
	.sys_rst_n(sys_rst_n),

	.locked(locked),
	.div_clk(vga_clk)
);

avd7123_vdac avd7123_vdac_inst0 (
	.vga_clk(vga_clk),
	.sys_rst_n(rst_n),
	.pix_data(pix_data),

	.hsync(hsync),
	.vsync(vsync),
	.pix_x(pix_x),
	.pix_y(pix_y),
	.vga_r(vga_r),
	.vga_g(vga_g),
	.vga_b(vga_b)
);

vga_pic vga_pic_inst0 (
	.vga_clk(vga_clk),
	.sys_rst_n(rst_n),
	.pix_x(pix_x),
	.pix_y(pix_y),

	.pix_data(pix_data)
);

endmodule