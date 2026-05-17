module dac8550 #(
    parameter SCK_DIV_CNT_MAX = 2'd1 - 1
)(
    input           clk,
    input           rst_n,

    input           send_start,
    input   [17:0]  send_data,
    output          send_ready,

    output          sck,
    output          sync_n,
    output          dout
);

localparam SEND_DELAY_CNT_MAX = 3'd3 - 1; // 50Mhz basic

// global vaue
// sck generator
reg     [1:0]   sck_div_cnt;
reg             sck_gen;
assign sck = sck_gen;
// send state
reg     [1:0]   send_state;
// send status cnt
reg     [2:0]   send_delay_cnt;
reg     [4:0]   send_cnt;
// sync_n set
reg             sync_n_reg;
assign sync_n = sync_n_reg;
// send ready
reg             send_ready_reg;
assign send_ready = send_ready_reg;
// send data
reg     [17:0]  send_data_buf;
reg             dout_reg;
assign dout = dout_reg;

// sck generator
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sck_div_cnt <= 2'b0;
        sck_gen <= 1'b1;
    end
    else if(send_state == 2'd1) begin
        if(sck_div_cnt == SCK_DIV_CNT_MAX) begin
            sck_div_cnt <= 2'b0;
            sck_gen <= ~sck_gen;
        end
        else begin
            sck_div_cnt <= sck_div_cnt + 1'b1;
        end
    end
    else begin
        sck_gen <= 1'b1;
        sck_div_cnt <= 2'b0;
    end
end

// state
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        send_state <= 2'd2;
    end
    else begin
        case(send_state)
        2'd0: begin
            if(send_start == 1'b1) begin
                send_state <= 2'd1;
            end
        end
        2'd1: begin
            if(send_cnt == 5'b0) begin
                send_state <= 2'd2;
            end
        end
        2'd2: begin
            if(send_delay_cnt == SEND_DELAY_CNT_MAX) begin
                send_state <= 2'd0;
            end
        end
        default: begin
            send_state <= 2'd2;
        end
        endcase
    end
end

// send status cnt
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        send_delay_cnt <= 3'b0;
    end
    else if(send_state == 2'd2) begin
        if(send_delay_cnt != SEND_DELAY_CNT_MAX) begin
            send_delay_cnt <= send_delay_cnt + 1'b1;
        end
    end
    else begin
        send_delay_cnt <= 3'b0;
    end
end

always @(posedge sck or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        send_cnt <= 5'd24;
    end
    else if(send_state == 2'd1) begin
        if(send_cnt != 5'b0) begin
            send_cnt <= send_cnt - 1'b1;
        end
    end
    else begin
        send_cnt <= 5'd24;
    end
end

// sync_n set
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sync_n_reg <= 1'b1;
    end
    else if(send_state == 2'd1) begin
        sync_n_reg <= 1'b0;
    end
    else begin
        sync_n_reg <= 1'b1;
    end
end

// send ready
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        send_ready_reg <= 1'b0;
    end
    else if(send_state == 2'd0) begin
        send_ready_reg <= 1'b1;
    end
    else begin
        send_ready_reg <= 1'b0;
    end
end

// send data
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        send_data_buf <= 18'b0;
    end
    else if((send_state == 2'd0) && (send_start == 1'b1)) begin
        send_data_buf <= send_data;
    end
end

always @(posedge sck or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        dout_reg <= 1'bz;
    end
    else if(send_state == 2'b1) begin
        if(send_cnt > 5'd18) begin
            dout_reg <= 1'b0;
        end
        else begin
            dout_reg <= send_data_buf[send_cnt - 1'b1];
        end
    end
    else begin
        dout_reg <= 1'bz;
    end
end

endmodule

// module
// dac8550 #(
//     .SCK_DIV_CNT_MAX(2'd1 - 1)
// ) dac8550_inst0 (
//     .clk(clk),
//     .rst_n(rst_n),

//     .send_start(send_start),
//     .send_data(send_data),
//     .send_ready(send_ready),

//     .sck(sck),
//     .sync_n(sync_n),
//     .dout(dout)
// );