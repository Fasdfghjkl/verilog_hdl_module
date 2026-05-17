//dynamic display
module seg_7_dynamic (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire [19:0] number,
    input wire minus_sign,

    output reg [6:0] seg0,
    output reg [6:0] seg1,
    output reg [6:0] seg2,
    output reg [6:0] seg3,
    output reg [6:0] seg4,
    output reg [6:0] seg5
);

parameter SEG_0 = 7'b100_0000, SEG_1 = 7'b111_1001,
SEG_2 = 7'b010_0100, SEG_3 = 7'b011_0000,
SEG_4 = 7'b001_1001, SEG_5 = 7'b001_0010,
SEG_6 = 7'b000_0010, SEG_7 = 7'b111_1000,
SEG_8 = 7'b000_0000, SEG_9 = 7'b001_0000;
parameter MINUS = 7'b011_1111, IDLE = 7'b111_1111; 

reg [3:0] num0;
reg [3:0] num1;
reg [3:0] num2;
reg [3:0] num3;
reg [3:0] num4;
reg [3:0] num5;

wire [3:0] unit;
wire [3:0] ten;
wire [3:0] hun;
wire [3:0] tho;
wire [3:0] t_tho;
wire [3:0] h_hun;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        num0 <= 4'd11; num1 <= 4'd11; num2 <= 4'd11; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
    end
    else if(!number) begin
        num0 <= 4'd0; num1 <= 4'd11; num2 <= 4'd11; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
    end
    else if(!{h_hun, t_tho, tho, hun, ten}) begin
        if(minus_sign) begin
        num0 <= unit; num1 <= 4'd10; num2 <= 4'd11; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
        end
        else begin
            num0 <= unit; num1 <= 4'd11; num2 <= 4'd11; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
        end
    end
    else if(!{h_hun, t_tho, tho, hun}) begin
        if(minus_sign) begin
            num0 <= unit; num1 <= ten; num2 <= 4'd10; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
        end
        else begin
            num0 <= unit; num1 <= ten; num2 <= 4'd11; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
        end
    end
    else if(!{h_hun, t_tho, tho}) begin
        if(minus_sign) begin
            num0 <= unit; num1 <= ten; num2 <= hun; num3 <= 4'd10; num4 <= 4'd11; num5 <= 4'd11;
        end
        else begin
            num0 <= unit; num1 <= ten; num2 <= hun; num3 <= 4'd11; num4 <= 4'd11; num5 <= 4'd11;
        end
    end
    else if(!{h_hun, t_tho}) begin
        if(minus_sign) begin
            num0 <= unit; num1 <= ten; num2 <= hun; num3 <= tho; num4 <= 4'd10; num5 <= 4'd11;
        end
        else begin
            num0 <= unit; num1 <= ten; num2 <= hun; num3 <= tho; num4 <= 4'd11; num5 <= 4'd11;
        end
    end
    else if(!h_hun) begin
        if(minus_sign) begin
        num0 <= unit; num1 <= ten; num2 <= hun; num3 <= tho; num4 <= t_tho; num5 <= 4'd10;
        end
        else begin
            num0 <= unit; num1 <= ten; num2 <= hun; num3 <= tho; num4 <= t_tho; num5 <= 4'd11;
        end
    end
    else begin
        num0 <= unit; num1 <= ten; num2 <= hun; num3 <= tho; num4 <= t_tho; num5 <= h_hun;
    end
end


always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
    seg0 <= IDLE; seg1 <= IDLE; seg2 <= IDLE; seg3 <= IDLE; seg4 <= IDLE; seg5 <= IDLE;
    end
    else begin
        case(num0)
            4'd0:seg0 <= SEG_0;
            4'd1:seg0 <= SEG_1;
            4'd2:seg0 <= SEG_2;
            4'd3:seg0 <= SEG_3;
            4'd4:seg0 <= SEG_4;
            4'd5:seg0 <= SEG_5;
            4'd6:seg0 <= SEG_6;
            4'd7:seg0 <= SEG_7;
            4'd8:seg0 <= SEG_8;
            4'd9:seg0 <= SEG_9;
            4'd10:seg0 <= MINUS;
            4'd11:seg0 <= IDLE;
            default:seg0 <= IDLE;
        endcase
        case(num1)
            4'd0:seg1 <= SEG_0;
            4'd1:seg1 <= SEG_1;
            4'd2:seg1 <= SEG_2;
            4'd3:seg1 <= SEG_3;
            4'd4:seg1 <= SEG_4;
            4'd5:seg1 <= SEG_5;
            4'd6:seg1 <= SEG_6;
            4'd7:seg1 <= SEG_7;
            4'd8:seg1 <= SEG_8;
            4'd9:seg1 <= SEG_9;
            4'd10:seg1 <= MINUS;
            4'd11:seg1 <= IDLE;
            default:seg1 <= IDLE;
        endcase
        case(num2)
            4'd0:seg2 <= SEG_0;
            4'd1:seg2 <= SEG_1;
            4'd2:seg2 <= SEG_2;
            4'd3:seg2 <= SEG_3;
            4'd4:seg2 <= SEG_4;
            4'd5:seg2 <= SEG_5;
            4'd6:seg2 <= SEG_6;
            4'd7:seg2 <= SEG_7;
            4'd8:seg2 <= SEG_8;
            4'd9:seg2 <= SEG_9;
            4'd10:seg2 <= MINUS;
            4'd11:seg2 <= IDLE;
            default:seg2 <= IDLE;
        endcase
        case(num3)
            4'd0:seg3 <= SEG_0;
            4'd1:seg3 <= SEG_1;
            4'd2:seg3 <= SEG_2;
            4'd3:seg3 <= SEG_3;
            4'd4:seg3 <= SEG_4;
            4'd5:seg3 <= SEG_5;
            4'd6:seg3 <= SEG_6;
            4'd7:seg3 <= SEG_7;
            4'd8:seg3 <= SEG_8;
            4'd9:seg3 <= SEG_9;
            4'd10:seg3 <= MINUS;
            4'd11:seg3 <= IDLE;
            default:seg3 <= IDLE;
        endcase
        case(num4)
            4'd0:seg4 <= SEG_0;
            4'd1:seg4 <= SEG_1;
            4'd2:seg4 <= SEG_2;
            4'd3:seg4 <= SEG_3;
            4'd4:seg4 <= SEG_4;
            4'd5:seg4 <= SEG_5;
            4'd6:seg4 <= SEG_6;
            4'd7:seg4 <= SEG_7;
            4'd8:seg4 <= SEG_8;
            4'd9:seg4 <= SEG_9;
            4'd10:seg4 <= MINUS;
            4'd11:seg4 <= IDLE;
            default:seg4 <= IDLE;
        endcase
        case(num5)
            4'd0:seg5 <= SEG_0;
            4'd1:seg5 <= SEG_1;
            4'd2:seg5 <= SEG_2;
            4'd3:seg5 <= SEG_3;
            4'd4:seg5 <= SEG_4;
            4'd5:seg5 <= SEG_5;
            4'd6:seg5 <= SEG_6;
            4'd7:seg5 <= SEG_7;
            4'd8:seg5 <= SEG_8;
            4'd9:seg5 <= SEG_9;
            4'd10:seg5 <= MINUS;
            4'd11:seg5 <= IDLE;
            default:seg5 <= IDLE;
        endcase
    end
end

//module
six_8421_transfer six_8421_transfer_inst0 (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .data(number),

    .unit(unit),
    .ten(ten),
    .hun(hun),
    .tho(tho),
    .t_tho(t_tho),
    .h_hun(h_hun)
);

endmodule