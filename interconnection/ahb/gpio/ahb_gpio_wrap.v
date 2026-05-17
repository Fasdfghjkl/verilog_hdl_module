module ahb_gpio_wrap #(
    parameter DATA_WIDTH = 32,      // 数据位宽
    parameter ADDR_WIDTH = 32,      // 地址位宽
    parameter USER_ADDR_BITS = 8    // 用户逻辑实际使用的地址低位宽度 (例如 8 bits = 256 bytes 空间)
)(
    // ----------------------------------------------------------------
    // AHB-Lite 接口信号 (连接到总线矩阵或Master)
    // ----------------------------------------------------------------
    input                       HCLK,
    input                       HRESETn,
    input                       HSEL,      // 从机片选信号
    input   [ADDR_WIDTH-1:0]    HADDR,     // 地址
    input   [1:0]               HTRANS,    // 传输类型 (IDLE, BUSY, NONSEQ, SEQ)
    input                       HWRITE,    // 写使能 (1=Write, 0=Read)
    input   [2:0]               HSIZE,     // 传输大小 (8, 16, 32 bits)
    input   [2:0]               HBURST,    // 突发类型 (本从机将其视为单次传输处理)
    input   [3:0]               HPROT,     // 保护控制
    input                       HREADY,    // 系统全局 Ready 信号 (输入)
    input   [DATA_WIDTH-1:0]    HWDATA,    // 写数据
    
    output                      HREADYOUT, // 从机 Ready 信号 (输出)
    output  [1:0]               HRESP,     // 响应状态 (0=OKAY, 1=ERROR)
    output  [DATA_WIDTH-1:0]    HRDATA,    // 读数据
    // ----------------------------------------------------------------
    // 用户逻辑接口 (User Logic Interface)
    // ----------------------------------------------------------------
    inout   [31:0]              GPIO
);

// ----------------------------------------------------------------
// 常量定义
// ----------------------------------------------------------------
localparam [1:0] HTRANS_IDLE   = 2'b00;
localparam [1:0] HTRANS_BUSY   = 2'b01;
localparam [1:0] HTRANS_NONSEQ = 2'b10;
localparam [1:0] HTRANS_SEQ    = 2'b11;

localparam [1:0] HRESP_OKAY    = 2'b00;
localparam [1:0] HRESP_ERROR   = 2'b01;

// ----------------------------------------------------------------
// 用户逻辑接口 (User Logic Interface)
// ----------------------------------------------------------------
wire [USER_ADDR_BITS-1:0] user_addr;     // 输出给用户逻辑的地址
wire [DATA_WIDTH-1:0]     user_wdata;    // 输出给用户逻辑的写数据
wire                      user_wr_en;    // 写使能脉冲 (高电平有效)
wire                      user_rd_en;    // 读使能脉冲 (高电平有效)
wire [DATA_WIDTH/8-1:0]   user_wstrb;    // 写选通 (字节使能，可选用于支持 8/16位写)
// 用户逻辑反馈信号
wire [DATA_WIDTH-1:0]     user_rdata;    // 用户逻辑返回的读数据
wire                      user_ready;    // 用户逻辑忙闲指示 (1=Ready, 0=Wait)

// ----------------------------------------------------------------
// 内部寄存器 (用于流水线对齐)
// ----------------------------------------------------------------
reg [USER_ADDR_BITS-1:0] addr_phase_addr;
reg                      addr_phase_write;
reg                      addr_phase_valid;
reg [2:0]                addr_phase_size;

// ----------------------------------------------------------------
// 地址阶段采样 (Address Phase Sampling)
// AHB 是流水线的：在 T 周期采样地址，在 T+1 周期进行数据读写
// ----------------------------------------------------------------
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        addr_phase_addr  <= {USER_ADDR_BITS{1'b0}};
        addr_phase_write <= 1'b0;
        addr_phase_valid <= 1'b0;
        addr_phase_size  <= 3'b0;
    end 
    // 只有当 HREADY=1 且 HSEL=1 时，总线上的地址才是针对本从机的有效新传输
    else if (HREADY && HSEL) begin
        addr_phase_addr  <= HADDR[USER_ADDR_BITS-1:0];
        addr_phase_write <= HWRITE;
        addr_phase_size  <= HSIZE;
        
        // 只有 NONSEQ 和 SEQ 代表有效的数据传输请求
        if (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ)
            addr_phase_valid <= 1'b1;
        else
            addr_phase_valid <= 1'b0; // IDLE or BUSY
    end 
    else if (HREADY) begin
        // 如果 HSEL 拉低，但 HREADY 高，说明选中了别的从机，我们需要清除有效标志
        addr_phase_valid <= 1'b0;
    end
    // 如果 !HREADY，保持寄存器状态不变 (Wait state)
end

// ----------------------------------------------------------------
// 数据阶段逻辑 (Data Phase Logic) - 产生用户接口信号
// ----------------------------------------------------------------

// 生成写数据 (直接来自总线)
assign user_wdata = HWDATA;

// 生成地址 (来自上一拍采样的地址)
assign user_addr  = addr_phase_addr;

// 生成读/写使能脉冲
// 条件：之前采样到了有效传输 + 当前 HREADY 为高 (握手完成)
assign user_wr_en = addr_phase_valid && addr_phase_write && HREADY; 
assign user_rd_en = addr_phase_valid && !addr_phase_write && HREADY;

// 生成字节选通 (Write Strobe) - 辅助功能，用于支持 byte/half-word 写
reg [DATA_WIDTH/8-1:0] wstrb_decode;
always @(*) begin
    if(!HRESETn) begin
        wstrb_decode = {(DATA_WIDTH/8){1'b1}};
    end
    else begin
        case (addr_phase_size)
            3'b010: begin 
                wstrb_decode = 4'b1111; // 32位写，全选
            end
            3'b001: begin
                if (addr_phase_addr[1] == 1'b0) // 16-bit Half-Word
                    wstrb_decode = 4'b0011; // 地址低位 0x0, 0x4... 写低16位
                else
                    wstrb_decode = 4'b1100; // 地址低位 0x2, 0x6... 写高16位
            end
            3'b000: begin
                case (addr_phase_addr[1:0]) // 8-bit Byte
                    2'b00: wstrb_decode = 4'b0001; // 写 Byte 0 (bits 7:0)
                    2'b01: wstrb_decode = 4'b0010; // 写 Byte 1 (bits 15:8)
                    2'b10: wstrb_decode = 4'b0100; // 写 Byte 2 (bits 23:16)
                    2'b11: wstrb_decode = 4'b1000; // 写 Byte 3 (bits 31:24)
                endcase
            end
            default: wstrb_decode = 4'b0000;
        endcase
    end
end
assign user_wstrb = wstrb_decode;

// ----------------------------------------------------------------
// AHB 输出信号处理
// ----------------------------------------------------------------

// 读数据直接透传用户的 rdata
assign HRDATA = user_rdata;

// HRESP 始终返回 OKAY (简单从机通常不需要 ERROR 响应)
assign HRESP  = HRESP_OKAY;

// HREADYOUT 生成
// 如果用户逻辑需要等待 (例如 FIFO 满/空，或者外设慢速)，拉低 user_ready
// 这里的逻辑：如果有有效传输请求，且用户逻辑未准备好，则拉低 HREADYOUT
assign HREADYOUT = !addr_phase_valid ? 1'b1 : user_ready;


// user module
ahb_gpio ahb_gpio_inst (
    .clk(HCLK),
    .rstn(HRESETn),

    .user_addr(user_addr),
    .user_wdata(user_wdata),
    .user_wr_en(user_wr_en),
    .user_rd_en(user_rd_en),
    .user_wstrb(user_wstrb),
    .user_rdata(user_rdata),
    .user_ready(user_ready),

    .GPIO(GPIO)
);

endmodule

// module
// ahb_slave_wrap #(
//     .DATA_WIDTH(),
//     .ADDR_WIDTH(),
//     .USER_ADDR_BITS()
// ) ahb_slave_wrap_inst (
//     .HCLK(),
//     .HRESETn(),
//     .HSEL(),
//     .HADDR(),
//     .HTRANS(),
//     .HWRITE(),
//     .HSIZE(),
//     .HBURST(),
//     .HPROT(),
//     .HREADY(),
//     .HWDATA(),
//     .HREADYOUT(),
//     .HRESP(),
//     .HRDATA(),

//     .GPIO(GPIO)
// );
