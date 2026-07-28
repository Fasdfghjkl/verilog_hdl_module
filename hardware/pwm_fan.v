module pwm_fan (
    input           rstn,
    input           clk,

    input   [3:0]   spd_ctrl,

    output          pwm
);

// global value
reg [6:0]  pwm_cnt_percent;
reg [3:0]  pwm_cnt_cycle;
reg [3:0]  spd_ctrl_reg;
reg        pwm_reg;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        pwm_cnt_percent <= 7'b0;
    end else if(pwm_cnt_percent == 7'd124) begin
        pwm_cnt_percent <= 7'b0;
    end else begin
        pwm_cnt_percent <= pwm_cnt_percent + 1'b1;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        pwm_cnt_cycle <= 4'b0;
    end else if(pwm_cnt_percent == 7'd124) begin
        pwm_cnt_cycle <= pwm_cnt_cycle + 1'b1;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        spd_ctrl_reg <= 4'd7;
    end else begin
        spd_ctrl_reg <= spd_ctrl;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        pwm_reg <= 1'b0;
    end else if(pwm_cnt_cycle == spd_ctrl) begin
        pwm_reg <= ~pwm_reg;
    end
end

assign pwm = pwm_reg;

endmodule
