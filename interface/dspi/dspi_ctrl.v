module dspi_ctrl #(
    parameter   integer DATA_WIDTH = 16
) (
    input           rstn,
    input           clk,

    input   [DATA_WIDTH-1:0]  s_axis_tdata,
    input           s_axis_tvalid,
    output          s_axis_tready,
    output  [DATA_WIDTH-1:0]  m_axis_tdata,
    output          m_axis_tvalid,
    input           m_axis_tready,

    input           rdata_trig_out,

    input           sck,
    input           csn,
    input           mosi0,
    output          miso0
);

// global value
// fifo flag
wire        rw_valid0;
// fifo data
wire [DATA_WIDTH-1:0]    rdata0;
wire [DATA_WIDTH-1:0]    tdata0;
reg  [DATA_WIDTH-1:0]    w_data;
reg                      w_en_reg;
wire                     w_full;
wire                     w_empty;
wire [31:0]              w_fifo_dout;
reg  [DATA_WIDTH-1:0]    m_axis_tdata_reg;
wire [DATA_WIDTH-1:0]    r_data;
reg                      r_en_reg;
wire                     r_full;
wire                     r_empty;
wire [31:0]              r_fifo_dout;
reg                      m_axis_tvalid_reg;

// fifo data
always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        w_data <= 'b0;
        w_en_reg <= 1'b0;
    end else if(s_axis_tvalid == 1'b1) begin
        w_data <= s_axis_tdata;
        w_en_reg <= ~w_full;
    end else begin
        w_en_reg <= 1'b0;
    end
end

assign s_axis_tready = ~w_full;

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        r_en_reg <= 1'b0;
    end else if((m_axis_tready == 1'b1) && (rdata_trig_out == 1'b1)) begin
        r_en_reg <= ~r_empty;
    end else begin
        r_en_reg <= 1'b0;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        m_axis_tvalid_reg <= 1'b0;
    end else begin
        m_axis_tvalid_reg <= r_en_reg;
    end
end

always @(posedge clk or negedge rstn) begin
    if(rstn == 1'b0) begin
        m_axis_tdata_reg <= 'b0;
    end else if((r_en_reg == 1'b1) && (r_empty == 1'b0)) begin
        m_axis_tdata_reg <= r_data;
    end
end

assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tdata = m_axis_tdata_reg;

/*
 * FIFO18E1 only supports FWFT when EN_SYN is FALSE.  The two clock
 * inputs are nevertheless driven by the same clock, so these are still
 * common-clock FIFOs at the dspi_ctrl interface.
 *
 * DATA_WIDTH=18 selects the native 18-bit FIFO organization.  The DSPI
 * payload occupies the low DATA_WIDTH bits and the parity inputs are not
 * used.
 */
assign tdata0 = w_fifo_dout[DATA_WIDTH-1:0];

FIFO18E1 #(
    .DATA_WIDTH(18),
    .DO_REG(1),
    .EN_SYN("FALSE"),
    .FIFO_MODE("FIFO18"),
    .FIRST_WORD_FALL_THROUGH("TRUE"),
    .INIT(36'h000000000),
    .SIM_DEVICE("7SERIES"),
    .SRVAL(36'h000000000)
) fifo_dspi_primitive_t (
    .ALMOSTEMPTY(),
    .ALMOSTFULL(),
    .DO(w_fifo_dout),
    .DOP(),
    .EMPTY(w_empty),
    .FULL(w_full),
    .RDCOUNT(),
    .RDERR(),
    .WRCOUNT(),
    .WRERR(),
    .DI({{(32-DATA_WIDTH){1'b0}}, w_data}),
    .DIP(4'b0000),
    .RDCLK(clk),
    .RDEN(rw_valid0 && !w_empty),
    .REGCE(1'b1),
    .RST(~rstn),
    .RSTREG(1'b1),
    .WRCLK(clk),
    .WREN(w_en_reg && !w_full)
);

assign r_data = r_fifo_dout[DATA_WIDTH-1:0];

FIFO18E1 #(
    .DATA_WIDTH(18),
    .DO_REG(1),
    .EN_SYN("FALSE"),
    .FIFO_MODE("FIFO18"),
    .FIRST_WORD_FALL_THROUGH("TRUE"),
    .INIT(36'h000000000),
    .SIM_DEVICE("7SERIES"),
    .SRVAL(36'h000000000)
) fifo_dspi_primitive_r (
    .ALMOSTEMPTY(),
    .ALMOSTFULL(),
    .DO(r_fifo_dout),
    .DOP(),
    .EMPTY(r_empty),
    .FULL(r_full),
    .RDCOUNT(),
    .RDERR(),
    .WRCOUNT(),
    .WRERR(),
    .DI({{(32-DATA_WIDTH){1'b0}}, rdata0}),
    .DIP(4'b0000),
    .RDCLK(clk),
    .RDEN(r_en_reg && !r_empty),
    .REGCE(1'b1),
    .RST(~rstn),
    .RSTREG(1'b1),
    .WRCLK(clk),
    .WREN(rw_valid0 && !r_full)
);

dspi #(
    .DATA_WIDTH(DATA_WIDTH)
) dspi_inst0 (
    .rstn(rstn),
    .clk(clk),

    .tdata(tdata0),
    .rdata(rdata0),
    .rw_valid(rw_valid0),

    .sck(sck),
    .csn(csn),
    .mosi(mosi0),
    .miso(miso0)
);

endmodule
