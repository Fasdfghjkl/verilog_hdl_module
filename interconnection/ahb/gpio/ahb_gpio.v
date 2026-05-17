module ahb_gpio (
    input               clk,
    input               rstn,

    input   [7:0]       user_addr,
    input   [31:0]      user_wdata,
    input               user_wr_en,
    input               user_rd_en,
    input   [3:0]       user_wstrb,
    output  [31:0]      user_rdata,
    output              user_ready,
    
    inout   [31:0]      GPIO
);

reg [31:0] r_gpio_dir;  // 0x00: 方向
reg [31:0] r_gpio_out;  // 0x04: 输出值
reg [31:0] rdata_comb;

assign user_rdata = rdata_comb;
assign user_ready = 1'b1;
genvar i;
generate
    for (i = 0; i <= 31; i = i + 1) begin : gpio_tri_loop
        assign GPIO[i] = (r_gpio_dir[i] == 1'b1) ? r_gpio_out[i] : 1'bz;
    end
endgenerate

// 写逻辑
integer j;
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        r_gpio_dir <= 32'b0;
        r_gpio_out <= 32'bz;
    end
    else if (user_wr_en) begin
        case (user_addr[7:2]) // 按字寻址，忽略低2位
            6'h0: begin
                for (j = 0; j <= 3; j = j + 1) begin
                    if (user_wstrb[j]) begin
                        r_gpio_dir[8*j +: 8] <= user_wdata[8*j +: 8];
                    end
                end
            end
            6'h1: begin
                for (j = 0; j <= 3; j = j + 1) begin
                    if (user_wstrb[j]) begin
                        r_gpio_out[8*j +: 8] <= user_wdata[8*j +: 8];
                    end
                end
            end
        endcase
    end
end

// 读逻辑 (组合逻辑)
always @(*) begin
    case (user_addr[7:2])
        6'h0: rdata_comb = r_gpio_dir;
        6'h1: rdata_comb = r_gpio_out;
        6'h2: rdata_comb = GPIO;
        default: rdata_comb = 32'h0;
    endcase
end

endmodule

// module
// ahb_gpio ahb_gpio_inst (
//     .clk(clk),
//     .rstn(rstn),

//     .user_addr(user_addr),
//     .user_wdata(user_wdata),
//     .user_wr_en(user_wr_en),
//     .user_rd_en(user_rd_en),
//     .user_wstrb(user_wstrb),
//     .user_rdata(user_rdata),
//     .user_ready(user_ready),

//     .GPIO(GPIO)
// );
