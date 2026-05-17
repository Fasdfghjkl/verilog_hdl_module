// hight-speed dac

module ad9744 (
    input           rstn,
    input           clk,

    // ad9744
    input           send_indc,

    input   [13:0]  send_data,
    output  [13:0]  pdata,
    output          dclk
);

// global value
// ad9744
reg     [13:0]  pdata_buf;
assign pdata = pdata_buf;
assign dclk = ~clk;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        pdata_buf <= 14'b0;
    end
    else if(send_indc == 1'b1) begin
        pdata_buf <= send_data;
    end
end

endmodule
