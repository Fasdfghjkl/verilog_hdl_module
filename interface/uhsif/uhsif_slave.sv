`timescale 1ns/1ps
module uhsif_slave #(
    parameter integer SEL_WIDTH = 1,
    parameter integer DATA_WIDTH = 16,
    parameter LINE_MODE = 4'b0101,
    // Enable for MCU-master UART transmit verification (receiving sink).
    parameter RX_TEST_MODE = 0,
    // Select the complete-frame loopback used by the current CH32H417 UART test.
    parameter PACKET_TEST_MODE = 0,
    parameter integer FRAME_WORDS = 32,
    // This project's libUHSIF master ends a read when the physical AE pin is high.
    // The WCH timing document describes active-low AE#; this is a measured compatibility setting.
    parameter AE_STOP_HIGH = 1,
    parameter integer AE_STOP_CYCLE = 35
)(
    input           clk,
    input           rstn,

    input           pclk,
    input           cs_n,
    input           wr_n,
    input           rd_n,
    input           oe_n,
    input           eop_n,
    input   [SEL_WIDTH-1:0] sel,
    output          rdne,
    output          wrnf,
    output          af_n,
    output          ae_n,
    input   [DATA_WIDTH-1:0] idata,
    output  [DATA_WIDTH-1:0] odata,
    output          data_oe,
    output [15:0]   debug_status
);

generate if (RX_TEST_MODE) begin : rx_test
    wire [7:0] word_count;
    wire [15:0] last_word;
    uhsif_rx_test receiver (
        .pclk(pclk), .rstn(rstn), .cs_n(cs_n), .wr_n(wr_n),
        .eop_n(eop_n), .sel(sel[0]), .idata(idata),
        .rdne(rdne), .wrnf(wrnf), .ae_n(ae_n), .af_n(af_n),
        .word_count(word_count), .last_word(last_word)
    );
    assign odata = 0;
    assign data_oe = 0;
    // [15:8] cumulative accepted words (wraps); [7:0] reset/EOP/CS/SEL/AF/AE/WRNF/RDNE.
    assign debug_status = {word_count, rstn, eop_n, cs_n, sel[0], af_n, ae_n, wrnf, rdne};
end else if (PACKET_TEST_MODE) begin : packet_loopback
    uhsif_packet_loopback #(
        .DATA_WIDTH(DATA_WIDTH), .SEL_WIDTH(SEL_WIDTH), .FRAME_WORDS(FRAME_WORDS),
        .AE_STOP_HIGH(AE_STOP_HIGH), .AE_STOP_CYCLE(AE_STOP_CYCLE)
    ) packet_inst (
        .clk(clk), .rstn(rstn), .pclk(pclk), .cs_n(cs_n), .wr_n(wr_n),
        .rd_n(rd_n), .oe_n(oe_n), .eop_n(eop_n), .sel(sel),
        .rdne(rdne), .wrnf(wrnf), .af_n(af_n), .ae_n(ae_n),
        .idata(idata), .odata(odata), .data_oe(data_oe), .debug_status(debug_status)
    );
end else begin : legacy_loopback
    assign debug_status = 0;
    
localparam
LINE0_RW_MODE = LINE_MODE[0],
LINE1_RW_MODE = LINE_MODE[1],
LINE2_RW_MODE = LINE_MODE[2],
LINE3_RW_MODE = LINE_MODE[3];

// write data
logic uhsif_full;
logic wr_n_dy;
logic wr_end_flag;
logic [0:0] wr_end_cnt;
logic wr_end_state;

always_ff@(posedge pclk or negedge rstn) begin
    if(rstn == 1'b0) begin
        wr_n_dy <= 1'b1;
    end else begin
        wr_n_dy <= wr_n;
    end
end
assign wr_end_flag = wr_n & ~wr_n_dy;

always_ff@(posedge pclk or negedge rstn) begin
    if(rstn == 1'b0) begin
        wr_end_cnt <= 'b0;
        wr_end_state <= 1'b0;
    end else if(wr_end_cnt == 'd1) begin
        wr_end_cnt <= 'b0;
        wr_end_state <= 1'b1;
    end else if(wr_end_flag == 1'b1) begin
        wr_end_cnt <= wr_end_cnt + 1'b1;
    end else begin
        wr_end_state <= 1'b0;
    end
end

assign wrnf = ~wr_end_state & ~uhsif_full;
assign af_n = ~wr_end_state & ~uhsif_full;

// read data
logic uhsif_empty;
logic rd_n_dy;
logic rd_end_flag;
logic [0:0] rd_end_cnt;
logic rd_end_state;

always_ff@(posedge pclk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rd_n_dy <= 1'b1;
    end else begin
        rd_n_dy <= rd_n;
    end
end
assign rd_end_flag = rd_n & ~rd_n_dy;

always_ff@(posedge pclk or negedge rstn) begin
    if(rstn == 1'b0) begin
        rd_end_cnt <= 'b0;
        rd_end_state <= 1'b0;
    end else if(rd_end_cnt == 'd1) begin
        rd_end_cnt <= 'b0;
        rd_end_state <= 1'b1;
    end else if(rd_end_flag == 1'b1) begin
        rd_end_cnt <= rd_end_cnt + 1'b1;
    end else begin
        rd_end_state <= 1'b0;
    end
end

assign rdne = ~rd_end_state & ~uhsif_empty;
// assign ae_n = ~rd_end_state & ~uhsif_empty;
assign ae_n = 1'b1;
assign data_oe = ~oe_n;

logic [DATA_WIDTH-1:0] fifo_odata;
logic [DATA_WIDTH-1:0] odata_buf0;

always_ff@(posedge pclk or negedge rstn) begin
    if(rstn == 1'b0) begin
        odata_buf0 <= 'b0;
    end else begin
        odata_buf0 <= fifo_odata;
    end
end
assign odata = odata_buf0;

fifo_generator_uhsif fifo_generator_uhsif_inst (
    .clk(pclk),      // input wire clk
    .rst(~rstn),      // input wire rst

    .din(idata),      // input wire [15 : 0] din
    .wr_en(~wr_n),  // input wire wr_en
    .rd_en(~rd_n),  // input wire rd_en
    .dout(fifo_odata),    // output wire [15 : 0] dout

    .full(uhsif_full),    // output wire full
    .empty(uhsif_empty)  // output wire empty
);


end endgenerate
endmodule

`timescale 1ns/1ps
// MCU master -> FPGA sink. This library drives SEL0=0 for software LINE1.
module uhsif_rx_test (
    input wire pclk, rstn, cs_n, wr_n, eop_n, sel,
    input wire [15:0] idata,
    output wire rdne, wrnf, ae_n, af_n,
    output reg [7:0] word_count,
    output reg [15:0] last_word
);
    wire selected = !sel;
    wire wr_active = !cs_n && !wr_n && selected;
    reg wr_active_d, zlp_active_d, had_write;
    wire zlp_active = !cs_n && !eop_n && selected && !had_write && !wr_active;
    reg [1:0] end_pipe;
    reg [3:0] busy_hold;
    assign rdne = 1'b0;
    assign ae_n = 1'b0;
    assign af_n = 1'b1;
    assign wrnf = rstn && (busy_hold == 0) && !end_pipe[1];
    always @(posedge pclk or negedge rstn) begin
        if (!rstn) begin
            wr_active_d <= 0;
            zlp_active_d <= 0;
            had_write <= 0;
            end_pipe <= 0;
            busy_hold <= 0;
            word_count <= 0;
            last_word <= 0;
        end else begin
            wr_active_d <= wr_active;
            zlp_active_d <= zlp_active;
            if (cs_n) had_write <= 0;
            else if (wr_active) had_write <= 1;
            // Nonempty packets acknowledge WR# rise; do not wait for EOP# rise.
            end_pipe <= {end_pipe[0], (wr_active_d && !wr_active) || (zlp_active_d && !zlp_active)};
            if (end_pipe[0]) busy_hold <= 8;
            else if (busy_hold != 0) busy_hold <= busy_hold - 1'b1;
            // EOP# low marks the terminal control cycle, not another data word.
            if (wr_active && eop_n && wrnf) begin
                word_count <= word_count + 1'b1;
                last_word <= idata;
            end
        end
    end
endmodule
`timescale 1ns/1ps
// Complete-frame loopback for the current 16-bit, 64-byte UART test.
// Physical AE high terminates this project's libUHSIF master read. At 12.5 MHz,
// AE_STOP_CYCLE=35 yields 32 payload words; read_cycles also includes startup clocks.
module uhsif_packet_loopback #(
    parameter integer DATA_WIDTH = 16,
    parameter integer SEL_WIDTH = 1,
    parameter integer FRAME_WORDS = 32,
    parameter AE_STOP_HIGH = 1,
    parameter integer AE_STOP_CYCLE = 35
)(
    input wire clk, rstn, pclk,
    input wire cs_n, wr_n, rd_n, oe_n, eop_n,
    input wire [SEL_WIDTH-1:0] sel,
    output wire rdne, wrnf, af_n, ae_n,
    input wire [DATA_WIDTH-1:0] idata,
    output reg [DATA_WIDTH-1:0] odata,
    output wire data_oe,
    output wire [15:0] debug_status
);
    reg [DATA_WIDTH-1:0] frame [0:FRAME_WORDS-1];
    reg packet_ready, read_started;
    reg wr_n_d, rd_n_d, write_active_d;
    reg [1:0] write_end_pipe, read_end_pipe;
    reg [5:0] write_count, read_cycles;
    reg overflow, bad_length;

    wire write_active = !cs_n && !wr_n;
    wire read_active = !cs_n && !rd_n && !oe_n;
    wire write_rise = wr_n && !wr_n_d;
    wire read_rise = rd_n && !rd_n_d;

    // Packet readiness does not depend on a FIFO pop or the number of read clocks.
    assign rdne = packet_ready;
    assign ae_n = AE_STOP_HIGH ? (read_cycles >= AE_STOP_CYCLE) : (read_cycles < AE_STOP_CYCLE);
    assign af_n = 1'b1;
    assign wrnf = rstn && !packet_ready && !write_end_pipe[1];
    assign data_oe = rstn && !cs_n && !oe_n && wr_n;
    assign debug_status = {packet_ready, read_started, (overflow || bad_length), ae_n,
                           write_count, read_cycles};

    always @(posedge pclk or negedge rstn) begin
        if (!rstn) begin
            packet_ready <= 0;
            read_started <= 0;
            wr_n_d <= 1;
            rd_n_d <= 1;
            write_active_d <= 0;
            write_end_pipe <= 0;
            read_end_pipe <= 0;
            write_count <= 0;
            read_cycles <= 0;
            overflow <= 0;
            bad_length <= 0;
            odata <= 0;
        end else begin
            wr_n_d <= wr_n;
            rd_n_d <= rd_n;
            write_active_d <= write_active;
            write_end_pipe <= {write_end_pipe[0], write_rise};
            read_end_pipe <= {read_end_pipe[0], read_rise && read_started};

            // EOP# low is a terminal control cycle, not an additional FIFO word.
            if (write_active && !write_active_d && !packet_ready) begin
                write_count <= eop_n ? 1 : 0;
                overflow <= 0;
                bad_length <= 0;
                if (eop_n) frame[0] <= idata;
            end else if (write_active && eop_n && !packet_ready) begin
                if (write_count < FRAME_WORDS) begin
                    frame[write_count] <= idata;
                    write_count <= write_count + 1'b1;
                end else begin
                    overflow <= 1;
                end
            end

            // The sampled WR# rising edge and this update are separated by two clocks.
            if (write_end_pipe[1]) begin
                if (write_count == FRAME_WORDS && !overflow) begin
                    packet_ready <= 1;
                    read_started <= 0;
                end else if (write_count != FRAME_WORDS || overflow) begin
                    bad_length <= 1;
                end
            end

            // Prefetch the first word, then allow two startup clocks before advancing.
            // A read ending after one word must not consume five words of a FIFO.
            if (packet_ready) begin
                if (read_active) begin
                    read_started <= 1;
                    if (read_cycles < 63) read_cycles <= read_cycles + 1'b1;
                    if (read_cycles <= 2) odata <= frame[0];
                    else if (read_cycles - 2 < FRAME_WORDS)
                        odata <= frame[read_cycles - 2];
                    else odata <= frame[FRAME_WORDS-1];
                end else begin
                    read_cycles <= 0;
                    odata <= frame[0];
                end
            end else begin
                read_cycles <= 0;
                odata <= 0;
            end

            // RDNE is withdrawn two clocks after RD# rises, and stays low until
            // another complete write frame. A premature MCU read discards the
            // unused suffix instead of advertising the same frame repeatedly.
            if (read_end_pipe[1]) begin
                packet_ready <= 0;
                read_started <= 0;
            end
        end
    end
endmodule

