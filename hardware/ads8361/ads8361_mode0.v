module ads8361_mode0 #(
    parameter SCK_DIV_CNT_MAX = 4'd3 - 1 // 50Mhz basic
)(
    input           clk,
    input           rst_n,

    input           conv_contin,
    output  signed  [15:0]  rdata_a,
    output  signed  [15:0]  rdata_b,
    output          rdata_valid_trig,

    input           sdata_a_in,
    input           sdata_b_in,
    input           adc_conv_busy,
    output          sclock,
    output          cs_n,
    output          adc_read,
    output          adc_convst,
    output          addr_sel_a0
);

// global value
// sclock generator
reg     [3:0]   sck_div_cnt;
reg             sclock_gen;
reg             sclock_redge;
reg             sclock_fedge;
assign sclock = sclock_gen;
// rec state
reg     [1:0]   rec_state;
reg             conv_contin_reg;
// clock operator
reg     [4:0]   sclock_cnt;
// adc convst & read & addr
reg             adc_convst_reg;
reg             addr_sel_a0_reg;
assign adc_read = adc_convst_reg;
assign adc_convst = adc_convst_reg;
assign addr_sel_a0 = addr_sel_a0_reg;
// adc cs_n
reg             cs_n_reg;
assign cs_n = cs_n_reg;
// rec data
reg             rdata_nfirst_reg;
reg             rdata_nfirst;
reg  signed  [15:0]  data_a_buf;
reg  signed  [15:0]  data_b_buf;
reg  signed  [15:0]  data_a_reg;
reg  signed  [15:0]  data_b_reg;
reg             rdata_refresh;
reg             rdata_refresh_reg;
assign rdata_a = data_a_reg;
assign rdata_b = data_b_reg;

// sclock generator
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sck_div_cnt <= 4'b0;
        sclock_gen <= 1'b0;
    end
    else if(sck_div_cnt == SCK_DIV_CNT_MAX) begin
        sck_div_cnt <= 4'b0;
        sclock_gen <= ~sclock_gen;
    end
    else begin
        sck_div_cnt <= sck_div_cnt + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sclock_redge <= 1'b0;
        sclock_fedge <= 1'b0;
    end
    else if(sck_div_cnt == SCK_DIV_CNT_MAX - 1'b1) begin
        if(sclock_gen == 1'b0) begin
            sclock_redge <= 1'b1;
        end
        else begin
            sclock_fedge <= 1'b1;
        end
    end
    else begin
        sclock_redge <= 1'b0;
        sclock_fedge <= 1'b0;
    end
end

// state & cs_n
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        conv_contin_reg <= 1'b0;
    end
    else if(rec_state == 2'd1) begin
        conv_contin_reg <= 1'b0;
    end
    else if(conv_contin == 1'b1) begin
        conv_contin_reg <= 1'b1;
    end
end

// always @(posedge sclock or negedge rst_n) begin
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rec_state <= 2'b0;
        cs_n_reg <= 1'b1;
    end
    else if(sclock_redge == 1'b1) begin
        case(rec_state)
            2'd0: begin
                if(conv_contin_reg == 1'b1) begin
                    rec_state <= 2'd1;
                    cs_n_reg <= 1'b0;
                end
            end
            2'd1: begin
                if(sclock_cnt == 5'b0) begin
                    rec_state <= 2'd2;
                end
            end
            2'd2: begin
                if(adc_conv_busy == 1'b0) begin
                    if(conv_contin == 1'b1) begin
                        rec_state <= 2'd1;
                    end
                    else begin
                        rec_state <= 2'd0;
                        cs_n_reg <= 1'b1;
                    end
                end
            end
            default: begin
                rec_state <= 2'b0;
                cs_n_reg <= 1'b1;
            end
        endcase
    end
end

// clock operator
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        sclock_cnt <= 5'd21;
    end
    else if(sclock_redge == 1'b1) begin
        if(rec_state == 2'd1) begin
            if(sclock_cnt != 5'b0) begin
                sclock_cnt <= sclock_cnt - 1'b1;
            end
        end
        else begin
            sclock_cnt <= 5'd21;
        end
    end
end

// adc convst & read & addr
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        adc_convst_reg <= 1'b0;
    end
    else if(sclock_redge == 1'b1) begin
        if(rec_state == 2'd1) begin
            if(sclock_cnt > 5'd20) begin
                adc_convst_reg <= 1'b1;
            end
            else begin
                adc_convst_reg <= 1'b0;
            end
        end
        else begin
            adc_convst_reg <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        addr_sel_a0_reg <= 1'b0;
    end
    else if(sclock_redge == 1'b1) begin
        if(rec_state == 2'd1) begin
            if(sclock_cnt > 5'd19) begin
                addr_sel_a0_reg <= 1'b1;
            end
            else begin
                addr_sel_a0_reg <= 1'b0;
            end
        end
        else begin
            addr_sel_a0_reg <= 1'b0;
        end
    end
end

// rec data
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_a_buf <= 16'b0;
        data_b_buf <= 16'b0;
    end
    else if(sclock_fedge == 1'b1) begin
        // if(rec_state == 2'd1) begin
        //     if((sclock_cnt < 5'd18) && (sclock_cnt > 5'd1)) begin
        if((rec_state == 2'd1) && (sclock_cnt < 5'd18) && (sclock_cnt > 5'd1)) begin
            data_a_buf[sclock_cnt - 5'd2] <= sdata_a_in;
            data_b_buf[sclock_cnt - 5'd2] <= sdata_b_in;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_a_reg <= 16'b0;
        data_b_reg <= 16'b0;
    end
    else if(sclock_redge == 1'b1) begin
        if((rec_state == 2'd1) && (sclock_cnt == 5'd2)) begin
            data_a_reg <= data_a_buf;
            data_b_reg <= data_b_buf;
        end
    end
end

always @(negedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rdata_nfirst_reg <= 1'b0;
        rdata_nfirst <= 1'b0;
    end
    else if((rec_state == 2'd1) && (rdata_nfirst_reg == 1'b1)) begin
        rdata_nfirst <= 1'b1;
    end
    else if(rec_state == 2'd2) begin
        rdata_nfirst_reg <= 1'b1;
    end
end

// rec valid
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rdata_refresh <= 1'b0;
    end
    else if(sclock_redge == 1'b1) begin
        if((rec_state == 2'd1) && (sclock_cnt == 5'd1)) begin
            rdata_refresh <= 1'b1;
        end
        else begin
            rdata_refresh <= 1'b0;
        end
    end
end

always @(posedge clk) rdata_refresh_reg <= rdata_refresh;

assign rdata_valid_trig = (~rdata_refresh & rdata_refresh_reg) & rdata_nfirst;

endmodule

//module
// ads8361_mode0#(
//     .SCK_DIV_CNT_MAX(4'd3 - 1) // 50Mhz basic
// ) ads8361_mode0_inst0 (
//     .clk(clk),
//     .rst_n(rst_n),

//     .conv_contin(conv_contin),
//     .rdata_a(rdata_a),
//     .rdata_b(rdata_b),
//     .rdata_valid_trig(rdata_valid_trig),

//     .sdata_a_in(sdata_a_in),
//     .sdata_b_in(sdata_b_in),
//     .adc_conv_busy(adc_conv_busy),
//     .sclock(sclock),
//     .cs_n(cs_n),
//     .adc_read(adc_read),
//     .adc_convst(adc_convst),
//     .addr_sel_a0(addr_sel_a0)
// );