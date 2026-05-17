module ahb_ws2812 #(
    parameter LED_RST_CNT = 'd28000, // 100M clk
    parameter DATA_PERIOD_CNT = 'd100,
    parameter DATA_HT_CNT = 'd70
)(
    input           clk,
    input           rstn,

    input   [7:0]   user_addr,
    input   [31:0]  user_wdata,
    input           user_wr_en,
    input           user_rd_en,
    input   [3:0]   user_wstrb,
    output  [31:0]  user_rdata,
    output          user_ready,

    output          sdata
);

localparam DATA_LT_CNT = DATA_PERIOD_CNT - DATA_HT_CNT;

// state matchine
localparam
RS_INIT = 2'b00,
RS_SEND = 2'b01,
RS_WAIT = 2'b10,
RS_RESET = 2'b11;
reg     [1:0]   rgb_send_state;
localparam
DS_INIT = 2'b00,
DS_HIGH = 2'b01,
DS_LOW = 2'b10;
reg     [1:0]   sdata_send_state;

// global value
reg     [7:0]   led_num;
reg 	[31:0]  rgb_data_read;
reg             send_flag;
reg     [31:0]  ahb_rdata;
reg             ready_state;

wire 	[23:0]  rgb_data;
reg 	[23:0]  reg_rgb_data;
reg     [7:0]   reg_led_num;
reg     [7:0]   led_num_max;
reg     [7:0]   send_data_cnt;
reg     [4:0]   rgb_data_position;
reg     [14:0]  led_delay_cnt;
reg             ready_reg;
reg             ready_reg_dy;
reg             sdata_reg;

assign sdata = sdata_reg;
assign user_ready = 1'b1;

integer j;
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        led_num <= 8'b1;
        rgb_data_read <= 32'b0;
        send_flag <= 1'b0;
    end
    else if (user_wr_en) begin
        case (user_addr[7:2]) // 按字寻址，忽略低2位
            6'h0: begin
                led_num <= user_wdata[7:0];
            end
            6'h1: begin
                for (j = 0; j <= 3; j = j + 1) begin
                    if (user_wstrb[j]) begin
                        rgb_data_read[8*j +: 8] <= user_wdata[8*j +: 8];
                    end
                end
                send_flag <= 1'b1;
            end
        endcase
    end
    else begin
        send_flag <= 1'b0;
    end
end

assign rgb_data = rgb_data_read[23:0];

always @(*) begin
    case (user_addr[7:2])
        6'h0: ahb_rdata = {24'b0, led_num};
        6'h1: ahb_rdata = {8'b0, rgb_data};
        6'h2: ahb_rdata = {30'b0, ready_state};
        6'h3: ahb_rdata = {24'b0, send_data_cnt};
        default: ahb_rdata = 32'h0;
    endcase
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        ready_state <= 1'b0;
    end
    else if((ready_reg == 1'b1) && (ready_reg_dy == 1'b0)) begin
        ready_state <= ready_reg;
    end
    else if((user_rd_en == 1'b1) && (user_addr[7:2] == 6'h2)) begin
        ready_state <= 1'b0;
    end
end

assign user_rdata = ahb_rdata;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        led_num_max <= 8'b1;
    end
    else if(led_num_max < reg_led_num) begin
        led_num_max <= reg_led_num;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rgb_send_state <= RS_INIT;
        reg_rgb_data <= 24'h0;
        reg_led_num <= 8'b1;
        send_data_cnt <= 8'b0;
        ready_reg <= 1'b0;
    end
    else begin
        case(rgb_send_state)
            RS_INIT: begin
                if(led_num == 8'b0) begin
                    reg_rgb_data <= 24'h0;
                    rgb_send_state <= RS_SEND;
                    reg_led_num <= led_num_max;
                    ready_reg <= 1'b0;
                end
                else if(send_flag == 1'b1) begin
                    reg_rgb_data <= rgb_data;
                    rgb_send_state <= RS_SEND;
                    reg_led_num <= led_num;
                    ready_reg <= 1'b0;
                end
                else begin
                    ready_reg <= 1'b1;
                end
            end
            RS_SEND: begin
                if((rgb_data_position == 5'd15) && (send_data_cnt != reg_led_num - 8'd1)) begin
                    ready_reg <= 1'b1;
                end
                else if((led_delay_cnt == DATA_PERIOD_CNT - 'd1) && (rgb_data_position == 1'b0)) begin
                    rgb_send_state <= RS_WAIT;
                    ready_reg <= 1'b0;
                end
            end
            RS_WAIT: begin
                reg_rgb_data <= rgb_data;
                if(send_data_cnt == reg_led_num - 8'd1) begin
                    rgb_send_state <= RS_RESET;
                end
                else begin
                    rgb_send_state <= RS_SEND;
                    send_data_cnt <= send_data_cnt + 8'd1;
                end
            end
            RS_RESET: begin
                if(led_delay_cnt == LED_RST_CNT - 'd1) begin
                    rgb_send_state <= RS_INIT;
                    send_data_cnt <= 8'b0;
                end
            end
            default: begin
                rgb_send_state <= RS_INIT;
                reg_rgb_data <= 24'b0;
                reg_led_num <= 8'b1;
                send_data_cnt <= 8'b0;
                ready_reg <= 1'b0;
            end
        endcase
    end
end

always @(posedge clk) ready_reg_dy <= ready_reg;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        led_delay_cnt <= 14'b0;
    end
    else begin
        case(rgb_send_state)
            RS_INIT: begin
                led_delay_cnt <= 14'b0;
            end
            RS_SEND: begin
                if(led_delay_cnt == DATA_PERIOD_CNT - 'd1) begin
                    led_delay_cnt <= 14'd0;
                end
                else begin
                    led_delay_cnt <= led_delay_cnt + 14'd1;
                end
            end
            RS_WAIT: begin
                led_delay_cnt <= 14'b0;
            end
            RS_RESET: begin
                led_delay_cnt <= led_delay_cnt + 14'd1;
            end
            default: begin
                led_delay_cnt <= 14'b0;
            end
        endcase
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        sdata_send_state <= DS_INIT;
        rgb_data_position <= 5'd23;
        sdata_reg <= 1'b0;
    end
    else begin
        case(sdata_send_state)
            DS_INIT: begin
                if((rgb_send_state == RS_SEND) && (led_delay_cnt != DATA_PERIOD_CNT - 'd1)) begin
                    sdata_send_state <= DS_HIGH;
                    sdata_reg <= 1'b1;
                end
            end
            DS_HIGH: begin
                if((reg_rgb_data[rgb_data_position] == 1'b0) && (led_delay_cnt == DATA_LT_CNT - 'd1)) begin
                    sdata_send_state <= DS_LOW;
                    sdata_reg <= 1'b0;
                end
                else if(led_delay_cnt == DATA_HT_CNT - 'd1) begin
                    sdata_send_state <= DS_LOW;
                    sdata_reg <= 1'b0;
                end
            end
            DS_LOW: begin
                if(led_delay_cnt == DATA_PERIOD_CNT - 'd1) begin
                    if(rgb_data_position == 1'b0) begin
                        sdata_send_state <= DS_INIT;
                        sdata_reg <= 1'b0;
                        rgb_data_position <= 5'd23;
                    end
                    else begin
                        sdata_send_state <= DS_HIGH;
                        rgb_data_position <= rgb_data_position - 5'd1;
                        sdata_reg <= 1'b1;
                    end
                end
            end
            default: begin
                sdata_send_state <= DS_INIT;
                sdata_reg <= 1'b0;
                rgb_data_position <= 5'd23;
            end
        endcase
    end
end

endmodule

// module
// ws2812 ws2812_inst (
//     .clk(HCLK),
//     .rstn(HRESETn),

//     .user_addr(user_addr),
//     .user_wdata(user_wdata),
//     .user_wr_en(user_wr_en),
//     .user_rd_en(user_rd_en),
//     .user_wstrb(user_wstrb),
//     .user_rdata(user_rdata),
//     .user_ready(user_ready),

//     .sdata(sdata)
// );
