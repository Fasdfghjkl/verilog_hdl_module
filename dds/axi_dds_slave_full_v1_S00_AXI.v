`timescale 1 ns / 1 ps

// Single-outstanding AXI4-Full register slave for axi_dds.
//
// FIXED, INCR, and WRAP bursts are accepted.  The register map is 32-bit, so
// normal software accesses use AWSIZE/ARSIZE=2.  Unsupported transfer sizes or
// reserved burst type 2'b11 complete with SLVERR.
module axi_dds_slave_full_v1_S00_AXI #(
    parameter integer PHASE_WIDTH           = 32,
    parameter integer ROM_ADDR_WIDTH        = 8,
    parameter integer OUTPUT_WIDTH          = 16,
    
    parameter integer C_S_AXI_ID_WIDTH       = 1,
    parameter integer C_S_AXI_DATA_WIDTH     = 32,
    parameter integer C_S_AXI_ADDR_WIDTH     = 6,
    parameter integer C_S_AXI_AWUSER_WIDTH   = 0,
    parameter integer C_S_AXI_ARUSER_WIDTH   = 0,
    parameter integer C_S_AXI_WUSER_WIDTH    = 0,
    parameter integer C_S_AXI_RUSER_WIDTH    = 0,
    parameter integer C_S_AXI_BUSER_WIDTH    = 0
) (
    // User ports: independent DDS clock domain and waveform output.
    input  wire                           dds_aclk,
    input  wire                           dds_aresetn,
    output wire signed [OUTPUT_WIDTH-1:0] wave_data,
    output wire                           wave_valid,

    input  wire                           S_AXI_ACLK,
    input  wire                           S_AXI_ARESETN,
    input  wire [C_S_AXI_ID_WIDTH-1:0]    S_AXI_AWID,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR,
    input  wire [7:0]                     S_AXI_AWLEN,
    input  wire [2:0]                     S_AXI_AWSIZE,
    input  wire [1:0]                     S_AXI_AWBURST,
    input  wire                           S_AXI_AWLOCK,
    input  wire [3:0]                     S_AXI_AWCACHE,
    input  wire [2:0]                     S_AXI_AWPROT,
    input  wire [3:0]                     S_AXI_AWQOS,
    input  wire [3:0]                     S_AXI_AWREGION,
    input  wire [C_S_AXI_AWUSER_WIDTH-1:0] S_AXI_AWUSER,
    input  wire                           S_AXI_AWVALID,
    output wire                           S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                           S_AXI_WLAST,
    input  wire [C_S_AXI_WUSER_WIDTH-1:0] S_AXI_WUSER,
    input  wire                           S_AXI_WVALID,
    output wire                           S_AXI_WREADY,
    output wire [C_S_AXI_ID_WIDTH-1:0]    S_AXI_BID,
    output wire [1:0]                     S_AXI_BRESP,
    output wire [C_S_AXI_BUSER_WIDTH-1:0] S_AXI_BUSER,
    output wire                           S_AXI_BVALID,
    input  wire                           S_AXI_BREADY,
    input  wire [C_S_AXI_ID_WIDTH-1:0]    S_AXI_ARID,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR,
    input  wire [7:0]                     S_AXI_ARLEN,
    input  wire [2:0]                     S_AXI_ARSIZE,
    input  wire [1:0]                     S_AXI_ARBURST,
    input  wire                           S_AXI_ARLOCK,
    input  wire [3:0]                     S_AXI_ARCACHE,
    input  wire [2:0]                     S_AXI_ARPROT,
    input  wire [3:0]                     S_AXI_ARQOS,
    input  wire [3:0]                     S_AXI_ARREGION,
    input  wire [C_S_AXI_ARUSER_WIDTH-1:0] S_AXI_ARUSER,
    input  wire                           S_AXI_ARVALID,
    output wire                           S_AXI_ARREADY,
    output wire [C_S_AXI_ID_WIDTH-1:0]    S_AXI_RID,
    output wire [C_S_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
    output wire [1:0]                     S_AXI_RRESP,
    output wire                           S_AXI_RLAST,
    output wire [C_S_AXI_RUSER_WIDTH-1:0] S_AXI_RUSER,
    output wire                           S_AXI_RVALID,
    input  wire                           S_AXI_RREADY
);

    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_CONTROL      = 6'h00;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_PHASE_INC    = 6'h04;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_PHASE_OFFSET = 6'h08;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_COMMAND      = 6'h0c;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_STATUS       = 6'h10;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] REG_CAPABILITY   = 6'h14;

    // Source-side configuration mailbox.  The hold registers remain stable
    // until the DDS clock domain acknowledges the matching request toggle.
    reg        cfg_enable_hold;
    reg [31:0] cfg_phase_inc_hold;
    reg [31:0] cfg_phase_offset_hold;
    reg        cfg_clear_phase_hold;
    reg        cfg_update_toggle;
    wire       cfg_update_ack_toggle;
    wire       dds_active_enable;

    reg        cfg_enable_stage;
    reg [31:0] cfg_phase_inc_stage;
    reg [31:0] cfg_phase_offset_stage;
    reg        apply_overrun;

    (* ASYNC_REG = "TRUE" *) reg cfg_ack_meta;
    (* ASYNC_REG = "TRUE" *) reg cfg_ack_sync;
    (* ASYNC_REG = "TRUE" *) reg active_enable_meta;
    (* ASYNC_REG = "TRUE" *) reg active_enable_sync;

    wire cfg_busy;
    assign cfg_busy = cfg_update_toggle ^ cfg_ack_sync;

    reg                               wr_active;
    reg [C_S_AXI_ADDR_WIDTH-1:0]      wr_addr;
    reg [7:0]                         wr_len;
    reg [7:0]                         wr_beats_left;
    reg [2:0]                         wr_size;
    reg [1:0]                         wr_burst;
    reg                               wr_error;
    reg [C_S_AXI_ID_WIDTH-1:0]        axi_bid;
    reg [1:0]                         axi_bresp;
    reg                               axi_bvalid;

    reg                               rd_active;
    reg [C_S_AXI_ADDR_WIDTH-1:0]      rd_addr;
    reg [7:0]                         rd_len;
    reg [7:0]                         rd_beats_left;
    reg [2:0]                         rd_size;
    reg [1:0]                         rd_burst;
    reg [C_S_AXI_ID_WIDTH-1:0]        axi_rid;
    reg [C_S_AXI_DATA_WIDTH-1:0]      axi_rdata;
    reg [1:0]                         axi_rresp;
    reg                               axi_rlast;
    reg                               axi_rvalid;

    wire write_beat;
    assign S_AXI_AWREADY = !wr_active && !axi_bvalid;
    assign S_AXI_WREADY  = wr_active && !axi_bvalid;
    assign S_AXI_BID      = axi_bid;
    assign S_AXI_BRESP    = axi_bresp;
    assign S_AXI_BUSER    = {C_S_AXI_BUSER_WIDTH{1'b0}};
    assign S_AXI_BVALID   = axi_bvalid;
    assign write_beat     = S_AXI_WREADY && S_AXI_WVALID;

    assign S_AXI_ARREADY  = !rd_active && !axi_rvalid;
    assign S_AXI_RID      = axi_rid;
    assign S_AXI_RDATA    = axi_rdata;
    assign S_AXI_RRESP    = axi_rresp;
    assign S_AXI_RLAST    = axi_rlast;
    assign S_AXI_RUSER    = {C_S_AXI_RUSER_WIDTH{1'b0}};
    assign S_AXI_RVALID   = axi_rvalid;

    function [31:0] merge_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  byte_enable;
        integer byte_index;
        begin
            merge_wstrb = old_value;
            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                if (byte_enable[byte_index])
                    merge_wstrb[byte_index*8 +: 8] =
                        new_value[byte_index*8 +: 8];
        end
    endfunction

    function [C_S_AXI_ADDR_WIDTH-1:0] burst_next_addr;
        input [C_S_AXI_ADDR_WIDTH-1:0] current_addr;
        input [1:0]                    burst_type;
        input [7:0]                    burst_len;
        input [2:0]                    burst_size;
        reg [31:0] addr_ext;
        reg [31:0] step;
        reg [31:0] boundary;
        reg [31:0] wrap_mask;
        reg [31:0] wrap_base;
        reg [31:0] next_ext;
        begin
            addr_ext = {{(32-C_S_AXI_ADDR_WIDTH){1'b0}}, current_addr};
            step = 32'd1 << burst_size;
            next_ext = addr_ext + step;

            case (burst_type)
                2'b00: next_ext = addr_ext;
                2'b10: begin
                    boundary = step * ({24'd0, burst_len} + 32'd1);
                    wrap_mask = boundary - 1'b1;
                    wrap_base = addr_ext & ~wrap_mask;
                    if (next_ext >= (wrap_base + boundary))
                        next_ext = wrap_base;
                end
                default: begin
                    // INCR and reserved both increment.  Reserved is also
                    // reported as SLVERR by the response channel.
                    next_ext = addr_ext + step;
                end
            endcase
            burst_next_addr = next_ext[C_S_AXI_ADDR_WIDTH-1:0];
        end
    endfunction

    function [C_S_AXI_DATA_WIDTH-1:0] register_read;
        input [C_S_AXI_ADDR_WIDTH-1:0] address;
        reg [31:0] value;
        begin
            value = 32'd0;
            case (address)
                REG_CONTROL:
                    value[0] = cfg_enable_stage;
                REG_PHASE_INC:
                    value = cfg_phase_inc_stage;
                REG_PHASE_OFFSET:
                    value = cfg_phase_offset_stage;
                REG_COMMAND:
                    value = 32'd0;
                REG_STATUS: begin
                    value[0] = cfg_busy;
                    value[1] = active_enable_sync;
                    value[2] = apply_overrun;
                end
                REG_CAPABILITY: begin
                    value[7:0]   = OUTPUT_WIDTH;
                    value[15:8]  = ROM_ADDR_WIDTH;
                    value[23:16] = PHASE_WIDTH;
                    value[31:24] = 8'h01;
                end
                default:
                    value = 32'd0;
            endcase
            register_read = {{(C_S_AXI_DATA_WIDTH-32){1'b0}}, value};
        end
    endfunction

    // Return toggle and active-enable status to the AXI clock domain.
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            cfg_ack_meta       <= 1'b0;
            cfg_ack_sync       <= 1'b0;
            active_enable_meta <= 1'b0;
            active_enable_sync <= 1'b0;
        end else begin
            cfg_ack_meta       <= cfg_update_ack_toggle;
            cfg_ack_sync       <= cfg_ack_meta;
            active_enable_meta <= dds_active_enable;
            active_enable_sync <= active_enable_meta;
        end
    end

    // Write-address, write-data, response, and DDS shadow/mailbox registers.
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            wr_active             <= 1'b0;
            wr_addr               <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wr_len                <= 8'd0;
            wr_beats_left         <= 8'd0;
            wr_size               <= 3'd0;
            wr_burst              <= 2'd0;
            wr_error              <= 1'b0;
            axi_bid               <= {C_S_AXI_ID_WIDTH{1'b0}};
            axi_bresp             <= 2'b00;
            axi_bvalid            <= 1'b0;
            cfg_enable_stage      <= 1'b0;
            cfg_phase_inc_stage   <= 32'd0;
            cfg_phase_offset_stage<= 32'd0;
            cfg_enable_hold       <= 1'b0;
            cfg_phase_inc_hold    <= 32'd0;
            cfg_phase_offset_hold <= 32'd0;
            cfg_clear_phase_hold  <= 1'b0;
            cfg_update_toggle     <= 1'b0;
            apply_overrun         <= 1'b0;
        end else begin
            if (axi_bvalid && S_AXI_BREADY)
                axi_bvalid <= 1'b0;

            if (S_AXI_AWREADY && S_AXI_AWVALID) begin
                wr_active     <= 1'b1;
                wr_addr       <= S_AXI_AWADDR;
                wr_len        <= S_AXI_AWLEN;
                wr_beats_left <= S_AXI_AWLEN;
                wr_size       <= S_AXI_AWSIZE;
                wr_burst      <= S_AXI_AWBURST;
                wr_error      <= (S_AXI_AWSIZE != 3'd2) ||
                                 (S_AXI_AWBURST == 2'b11);
                axi_bid       <= S_AXI_AWID;
            end

            if (write_beat) begin
                case (wr_addr)
                    REG_CONTROL: begin
                        if (S_AXI_WSTRB[0])
                            cfg_enable_stage <= S_AXI_WDATA[0];
                    end
                    REG_PHASE_INC:
                        cfg_phase_inc_stage <=
                            merge_wstrb(cfg_phase_inc_stage,
                                        S_AXI_WDATA[31:0],
                                        S_AXI_WSTRB[3:0]);
                    REG_PHASE_OFFSET:
                        cfg_phase_offset_stage <=
                            merge_wstrb(cfg_phase_offset_stage,
                                        S_AXI_WDATA[31:0],
                                        S_AXI_WSTRB[3:0]);
                    REG_COMMAND: begin
                        // bit 0: APPLY, bit 1: CLEAR_PHASE with this apply
                        if (S_AXI_WSTRB[0] && S_AXI_WDATA[0]) begin
                            if (!cfg_busy) begin
                                cfg_enable_hold       <= cfg_enable_stage;
                                cfg_phase_inc_hold     <= cfg_phase_inc_stage;
                                cfg_phase_offset_hold  <= cfg_phase_offset_stage;
                                cfg_clear_phase_hold   <= S_AXI_WDATA[1];
                                cfg_update_toggle      <= ~cfg_update_toggle;
                            end else begin
                                apply_overrun <= 1'b1;
                            end
                        end
                    end
                    REG_STATUS: begin
                        // Sticky APPLY-overrun flag, write one to clear.
                        if (S_AXI_WSTRB[0] && S_AXI_WDATA[2])
                            apply_overrun <= 1'b0;
                    end
                    default: begin
                    end
                endcase

                if (S_AXI_WLAST || (wr_beats_left == 8'd0)) begin
                    wr_active  <= 1'b0;
                    axi_bvalid <= 1'b1;
                    axi_bresp  <= (wr_error ||
                                  (S_AXI_WLAST != (wr_beats_left == 8'd0)))
                                  ? 2'b10 : 2'b00;
                end else begin
                    wr_beats_left <= wr_beats_left - 1'b1;
                    wr_addr <= burst_next_addr(wr_addr, wr_burst,
                                               wr_len, wr_size);
                end
            end
        end
    end

    // Read address/data channel.  Register data is sampled when each beat is
    // prepared and remains stable until RREADY completes the transfer.
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            rd_active     <= 1'b0;
            rd_addr       <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            rd_len        <= 8'd0;
            rd_beats_left <= 8'd0;
            rd_size       <= 3'd0;
            rd_burst      <= 2'd0;
            axi_rid       <= {C_S_AXI_ID_WIDTH{1'b0}};
            axi_rdata     <= {C_S_AXI_DATA_WIDTH{1'b0}};
            axi_rresp     <= 2'b00;
            axi_rlast     <= 1'b0;
            axi_rvalid    <= 1'b0;
        end else begin
            if (S_AXI_ARREADY && S_AXI_ARVALID) begin
                rd_active     <= 1'b1;
                rd_addr       <= S_AXI_ARADDR;
                rd_len        <= S_AXI_ARLEN;
                rd_beats_left <= S_AXI_ARLEN;
                rd_size       <= S_AXI_ARSIZE;
                rd_burst      <= S_AXI_ARBURST;
                axi_rid       <= S_AXI_ARID;
                axi_rdata     <= register_read(S_AXI_ARADDR);
                axi_rresp     <= ((S_AXI_ARSIZE != 3'd2) ||
                                  (S_AXI_ARBURST == 2'b11))
                                  ? 2'b10 : 2'b00;
                axi_rlast     <= (S_AXI_ARLEN == 8'd0);
                axi_rvalid    <= 1'b1;
            end else if (axi_rvalid && S_AXI_RREADY) begin
                if (axi_rlast) begin
                    rd_active  <= 1'b0;
                    axi_rvalid <= 1'b0;
                    axi_rlast  <= 1'b0;
                end else begin
                    rd_addr <= burst_next_addr(rd_addr, rd_burst,
                                               rd_len, rd_size);
                    rd_beats_left <= rd_beats_left - 1'b1;
                    axi_rdata <= register_read(
                        burst_next_addr(rd_addr, rd_burst,
                                        rd_len, rd_size));
                    axi_rlast <= (rd_beats_left == 8'd1);
                end
            end
        end
    end

    // User logic is inside the generated AXI slave module, matching the
    // standard Xilinx peripheral hierarchy:
    // axi_dds -> axi_dds_slave_full_v1_S00_AXI -> dds_rom_core.
    dds_rom_core #(
        .PHASE_WIDTH            (PHASE_WIDTH),
        .ROM_ADDR_WIDTH         (ROM_ADDR_WIDTH),
        .OUTPUT_WIDTH           (OUTPUT_WIDTH)
    ) dds_rom_core_inst (
        .dds_aclk               (dds_aclk),
        .dds_aresetn            (dds_aresetn),
        .cfg_enable_async       (cfg_enable_hold),
        .cfg_phase_inc_async    (cfg_phase_inc_hold[PHASE_WIDTH-1:0]),
        .cfg_phase_offset_async (cfg_phase_offset_hold[PHASE_WIDTH-1:0]),
        .cfg_clear_phase_async  (cfg_clear_phase_hold),
        .cfg_update_toggle_async(cfg_update_toggle),
        .cfg_update_ack_toggle  (cfg_update_ack_toggle),
        .active_enable          (dds_active_enable),
        .wave_data              (wave_data),
        .wave_valid             (wave_valid)
    );

endmodule
