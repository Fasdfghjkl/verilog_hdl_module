`timescale 1ns / 1ns

module tb_ads8361_mode0();

reg sys_clk, sys_rst_n;

reg conv_contin;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n = 1'b0;
// add
conv_contin = 1'b0;
#100
sys_rst_n = 1'b1;
// add
#20
conv_contin = 1'b1;
#7000
conv_contin = 1'b0;
end

//sys_clk
always #10 sys_clk = ~sys_clk;
//add

//module
ads8361_mode0 ads8361_mode0_inst (
    .clk(sys_clk),
    .rst_n(sys_rst_n),

    .conv_contin(conv_contin),
    .rdata_a(),
    .rdata_b(),
    .rdata_valid_trig(),

    .sdata_a_in(1'b1),
    .sdata_b_in(1'b1),
    .adc_conv_busy(1'b0),
    .sclock(),
    .cs_n(),
    .adc_read(),
    .adc_convst(),
    .addr_sel_a0()
);

endmodule
