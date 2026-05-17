//static display
module seg7_static (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire [4:0] num0,
    input wire [4:0] num1,
    input wire [4:0] num2,
    input wire [4:0] num3,
    input wire [4:0] num4,
    input wire [4:0] num5,

    output reg [6:0] seg0,
    output reg [6:0] seg1,
    output reg [6:0] seg2,
    output reg [6:0] seg3,
    output reg [6:0] seg4,
    output reg [6:0] seg5
);

parameter SEG_0 = 7'b100_0000, SEG_1 = 7'b1111_1001,
SEG_2 = 7'b010_0100, SEG_3 = 7'b011_0000,
SEG_4 = 7'b001_1001, SEG_5 = 7'b001_0010,
SEG_6 = 7'b000_0010, SEG_7 = 7'b111_1000,
SEG_8 = 7'b000_0000, SEG_9 = 7'b001_0000,
SEG_A = 7'b000_1000, SEG_B = 7'b000_0011,
SEG_C = 7'b100_0110, SEG_D = 7'b010_0001,
SEG_E = 7'b000_0110, SEG_F = 7'b000_1110;
parameter IDLE = 7'b111_1111; 

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
    seg0 <= IDLE; seg1 <= IDLE; seg2 <= IDLE; seg3 <= IDLE; seg4 <= IDLE; seg5 <= IDLE;
    end
    else begin
        case(num0)
            5'd0:seg0 <= SEG_0;
            5'd1:seg0 <= SEG_1;
            5'd2:seg0 <= SEG_2;
            5'd3:seg0 <= SEG_3;
            5'd4:seg0 <= SEG_4;
            5'd5:seg0 <= SEG_5;
            5'd6:seg0 <= SEG_6;
            5'd7:seg0 <= SEG_7;
            5'd8:seg0 <= SEG_8;
            5'd9:seg0 <= SEG_9;
            5'd10:seg0 <= SEG_A;
            5'd11:seg0 <= SEG_B;
            5'd12:seg0 <= SEG_C;
            5'd13:seg0 <= SEG_D;
            5'd14:seg0 <= SEG_E;
            5'd15:seg0 <= SEG_F;
            5'd16:seg0 <= IDLE;
            default:seg0 <= IDLE;
        endcase
        case(num1)
            5'd0:seg1 <= SEG_0;
            5'd1:seg1 <= SEG_1;
            5'd2:seg1 <= SEG_2;
            5'd3:seg1 <= SEG_3;
            5'd4:seg1 <= SEG_4;
            5'd5:seg1 <= SEG_5;
            5'd6:seg1 <= SEG_6;
            5'd7:seg1 <= SEG_7;
            5'd8:seg1 <= SEG_8;
            5'd9:seg1 <= SEG_9;
            5'd10:seg1 <= SEG_A;
            5'd11:seg1 <= SEG_B;
            5'd12:seg1 <= SEG_C;
            5'd13:seg1 <= SEG_D;
            5'd14:seg1 <= SEG_E;
            5'd15:seg1 <= SEG_F;
            5'd16:seg1 <= IDLE;
            default:seg1 <= IDLE;
        endcase
        case(num2)
            5'd0:seg2 <= SEG_0;
            5'd1:seg2 <= SEG_1;
            5'd2:seg2 <= SEG_2;
            5'd3:seg2 <= SEG_3;
            5'd4:seg2 <= SEG_4;
            5'd5:seg2 <= SEG_5;
            5'd6:seg2 <= SEG_6;
            5'd7:seg2 <= SEG_7;
            5'd8:seg2 <= SEG_8;
            5'd9:seg2 <= SEG_9;
            5'd10:seg2 <= SEG_A;
            5'd11:seg2 <= SEG_B;
            5'd12:seg2 <= SEG_C;
            5'd13:seg2 <= SEG_D;
            5'd14:seg2 <= SEG_E;
            5'd15:seg2 <= SEG_F;
            5'd16:seg2 <= IDLE;
            default:seg2 <= IDLE;
        endcase
        case(num3)
            5'd0:seg3 <= SEG_0;
            5'd1:seg3 <= SEG_1;
            5'd2:seg3 <= SEG_2;
            5'd3:seg3 <= SEG_3;
            5'd4:seg3 <= SEG_4;
            5'd5:seg3 <= SEG_5;
            5'd6:seg3 <= SEG_6;
            5'd7:seg3 <= SEG_7;
            5'd8:seg3 <= SEG_8;
            5'd9:seg3 <= SEG_9;
            5'd10:seg3 <= SEG_A;
            5'd11:seg3 <= SEG_B;
            5'd12:seg3 <= SEG_C;
            5'd13:seg3 <= SEG_D;
            5'd14:seg3 <= SEG_E;
            5'd15:seg3 <= SEG_F;
            5'd16:seg3 <= IDLE;
            default:seg3 <= IDLE;
        endcase
        case(num4)
            5'd0:seg4 <= SEG_0;
            5'd1:seg4 <= SEG_1;
            5'd2:seg4 <= SEG_2;
            5'd3:seg4 <= SEG_3;
            5'd4:seg4 <= SEG_4;
            5'd5:seg4 <= SEG_5;
            5'd6:seg4 <= SEG_6;
            5'd7:seg4 <= SEG_7;
            5'd8:seg4 <= SEG_8;
            5'd9:seg4 <= SEG_9;
            5'd10:seg4 <= SEG_A;
            5'd11:seg4 <= SEG_B;
            5'd12:seg4 <= SEG_C;
            5'd13:seg4 <= SEG_D;
            5'd14:seg4 <= SEG_E;
            5'd15:seg4 <= SEG_F;
            5'd16:seg4 <= IDLE;
            default:seg4 <= IDLE;
        endcase
        case(num5)
            5'd0:seg5 <= SEG_0;
            5'd1:seg5 <= SEG_1;
            5'd2:seg5 <= SEG_2;
            5'd3:seg5 <= SEG_3;
            5'd4:seg5 <= SEG_4;
            5'd5:seg5 <= SEG_5;
            5'd6:seg5 <= SEG_6;
            5'd7:seg5 <= SEG_7;
            5'd8:seg5 <= SEG_8;
            5'd9:seg5 <= SEG_9;
            5'd10:seg5 <= SEG_A;
            5'd11:seg5 <= SEG_B;
            5'd12:seg5 <= SEG_C;
            5'd13:seg5 <= SEG_D;
            5'd14:seg5 <= SEG_E;
            5'd15:seg5 <= SEG_F;
            5'd16:seg5 <= IDLE;
            default:seg5 <= IDLE;
        endcase
    end
end

endmodule