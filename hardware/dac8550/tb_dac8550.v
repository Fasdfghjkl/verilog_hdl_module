`timescale 1ns / 1ns

module tb_dac8550();

reg sys_clk, sys_rst_n;

reg [17:0] send_data;
reg send_start;
wire send_ready;

//IDLE
initial
begin
sys_clk = 1'b1;
sys_rst_n = 1'b0;
//add
send_data = 18'b11_0101_0101_0101_0111;
#100
sys_rst_n = 1'b1;
end

//sys_clk
always #10 sys_clk = ~sys_clk;

//add
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_start <= 1'b0;
    end
    else if(send_ready == 1'b1) begin
        send_start <= 1'b1;
    end
    else begin
        send_start <= 1'b0;
    end
end

dac8550 #(
    .SCK_DIV_CNT_MAX(2'd1 - 1)
) dac8550_inst0 (
    .clk(sys_clk),
    .rst_n(sys_rst_n),

    .send_start(send_start),
    .send_data(send_data),
    .send_ready(send_ready),

    .sck(),
    .sync_n(),
    .dout()
);

endmodule
