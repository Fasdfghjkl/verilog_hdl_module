module spi0_master (
    input wire sys_clk, sys_rst_n, miso,
    input wire [7:0] data,

    output wire [7:0] data_out,
    output reg cs_n, sck, mosi
);

parameter
DELAY_MAX = 6'd31, //32 * 20 ns
SCK_CNT_MAX = 3'd1; //2^(n+1) div

wire en;
reg [7:0] data_send;
reg [1:0] delay_cnt_flag;
reg [5:0] delay_cnt;
reg [2:0] sck_cnt;
reg [4:0] sck_state;
reg [7:0] data_fb;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    delay_cnt <= 6'd0;
    else if((cs_n == 1'b1) && (delay_cnt == DELAY_MAX) && (delay_cnt_flag == 2'd3))
    delay_cnt <= 6'd0;
    else if(delay_cnt == DELAY_MAX)
    delay_cnt <= 6'd0;
    else
    delay_cnt <= delay_cnt + 6'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
    delay_cnt_flag <= 2'd0;
    else if(delay_cnt == DELAY_MAX) begin
        if(delay_cnt_flag == 2'd3)
        delay_cnt_flag <= 2'd0;
        else if(cs_n == 1'b0)
        delay_cnt_flag <= delay_cnt_flag + 2'd1;
    end
end

assign en = (delay_cnt_flag == 2'd1) ? 1'b1 : 1'b0;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if((!sys_rst_n) || (cs_n == 1'b1))
    sck_cnt <= 3'b0;
    else if(en == 1'b0)
    sck_cnt <= 3'b0;
    else
        if(sck_cnt == SCK_CNT_MAX)
        sck_cnt <= 3'd0;
        else
        sck_cnt <= sck_cnt + 3'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if((!sys_rst_n) || (cs_n == 1'b1))
    sck_state <= 5'd0;
    else if(en == 1'b0)
    sck_state <= 5'd0;
    else if(sck_cnt == SCK_CNT_MAX) begin
        if(sck_state == 5'd16) begin
            if(en == 1'b0)
            sck_state <= 5'd0;
        end
        else
        sck_state <= sck_state + 5'd1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        data_send <= 8'b0;
        cs_n <= 1'b1;
    end
    else if((delay_cnt == DELAY_MAX) && (delay_cnt_flag == 2'd2))
    cs_n <= 1'b1;
    else if((delay_cnt == 6'd0) && (delay_cnt_flag == 2'd0) && (data_send != data)) begin
        data_send <= data;
        cs_n <= 1'b0;
    end
end

assign data_out = (!sys_rst_n) ? 8'b0 : ((sck_state == 5'd16) ? data_fb : data_out);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        mosi <=1'b0;
        sck <= 1'b0;
        data_fb <= 8'b0;
    end
    else if((en == 1'b0) || (cs_n == 1'b1)) begin
        mosi <=1'b0;
        sck <= 1'b0;
    end
    else begin
        case(sck_state)
        5'd0: begin
            mosi <= data_send[7];
            sck <= 1'b0;
        end
        5'd1: begin
            sck <= 1'b1;
            data_fb[7] <= miso;
        end
        5'd2: begin
            mosi <= data_send[6];
            sck <= 1'b0;
        end
        5'd3: begin
            sck <= 1'b1;
            data_fb[6] <= miso;
        end
        5'd4: begin
            mosi <= data_send[5];
            sck <= 1'b0;
        end
        5'd5: begin
            sck <= 1'b1;
            data_fb[5] <= miso;
        end
        5'd6: begin
            mosi <= data_send[4];
            sck <= 1'b0;
        end
        5'd7: begin
            sck <= 1'b1;
            data_fb[4] <= miso;
        end
        5'd8: begin
            mosi <= data_send[3];
            sck <= 1'b0;
        end
        5'd9: begin
            sck <= 1'b1;
            data_fb[3] <= miso;
        end
        5'd10: begin
            mosi <= data_send[2];
            sck <= 1'b0;
        end
        5'd11: begin
            sck <= 1'b1;
            data_fb[2] <= miso;
        end
        5'd12: begin
            mosi <= data_send[1];
            sck <= 1'b0;
        end
        5'd13: begin
            sck <= 1'b1;
            data_fb[1] <= miso;
        end
        5'd14: begin
            mosi <= data_send[0];
            sck <= 1'b0;
        end
        5'd15: begin
            sck <= 1'b1;
            data_fb[0] <= miso;
        end
        5'd16: sck <= 1'b0;
        default: begin
            mosi <= 1'b0;
            sck <= 1'b0;
            data_fb <= 8'b0;
        end
        endcase
    end
end

endmodule
