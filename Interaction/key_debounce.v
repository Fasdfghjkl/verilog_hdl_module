
// Debounce by key
module key_debounce (
    input           clk,      // 50MHz
    input           rstn,

    input           in,
    output          out
);

localparam st_const = 20'd1000000;  // 20ms at 50MHz

reg            in_reg0;
reg            in_reg1;
reg            in_reg2;
reg   [19:0]   cnt;
reg            reg_out;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        in_reg0 <= 1'b0;
        in_reg1 <= 1'b0;
        in_reg2 <= 1'b0;
    end
    else begin
        in_reg0 <= in;
        in_reg1 <= in_reg0;
        in_reg2 <= in_reg1;
    end
end

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        cnt <= 20'd0;
    end
    else begin
        if (in_reg1 == in_reg2) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= 20'd0;
        end
    end
end

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        reg_out <= 1'b0;
    end
    else begin
        if (cnt == st_const) begin
            reg_out <= in_reg2;
        end
    end
end

assign out = reg_out;

endmodule

// module
// key_debounce key_debounce_inst (
//     .clk(clk),      // 50MHz
//     .rstn(rstn),

//     .in(in),
//     .out(out)
// );
