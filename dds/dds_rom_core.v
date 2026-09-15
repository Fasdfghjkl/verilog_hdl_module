`timescale 1 ns / 1 ps

// Phase-accumulator DDS using the high phase bits as a ROM address.
//
// dds_wave_rom is a Xilinx Block Memory Generator single-port ROM.  Its
// required native interface is:
//   clka, ena, addra[ROM_ADDR_WIDTH-1:0], douta[OUTPUT_WIDTH-1:0]
module dds_rom_core #(
    parameter integer PHASE_WIDTH    = 32,
    parameter integer ROM_ADDR_WIDTH = 8,
    parameter integer OUTPUT_WIDTH   = 16
) (
    input  wire                           dds_aclk,
    input  wire                           dds_aresetn,

    // These mailbox data bits remain stable until the request is acknowledged.
    input  wire                           cfg_enable_async,
    input  wire [PHASE_WIDTH-1:0]         cfg_phase_inc_async,
    input  wire [PHASE_WIDTH-1:0]         cfg_phase_offset_async,
    input  wire                           cfg_clear_phase_async,
    input  wire                           cfg_update_toggle_async,
    output reg                            cfg_update_ack_toggle,

    output reg                            active_enable,
    output wire signed [OUTPUT_WIDTH-1:0] wave_data,
    output reg                            wave_valid
);

    (* ASYNC_REG = "TRUE" *) reg cfg_update_meta;
    (* ASYNC_REG = "TRUE" *) reg cfg_update_sync;

    reg [PHASE_WIDTH-1:0] phase_accumulator;
    reg [PHASE_WIDTH-1:0] phase_increment;
    reg [PHASE_WIDTH-1:0] phase_offset;

    wire [PHASE_WIDTH-1:0] phase_with_offset;
    wire [ROM_ADDR_WIDTH-1:0] rom_address;
    wire [OUTPUT_WIDTH-1:0] rom_data;
    wire config_pending;

    assign config_pending    = cfg_update_sync ^ cfg_update_ack_toggle;
    assign phase_with_offset = phase_accumulator + phase_offset;
    assign rom_address       = phase_with_offset[PHASE_WIDTH-1 -: ROM_ADDR_WIDTH];
    assign wave_data         = $signed(rom_data);

    // Synchronize only the request toggle.  The source-side mailbox holds all
    // multi-bit data stable while the request is outstanding.
    always @(posedge dds_aclk or negedge dds_aresetn) begin
        if (!dds_aresetn) begin
            cfg_update_meta <= 1'b0;
            cfg_update_sync <= 1'b0;
        end else begin
            cfg_update_meta <= cfg_update_toggle_async;
            cfg_update_sync <= cfg_update_meta;
        end
    end

    always @(posedge dds_aclk or negedge dds_aresetn) begin
        if (!dds_aresetn) begin
            cfg_update_ack_toggle <= 1'b0;
            active_enable         <= 1'b0;
            phase_increment       <= {PHASE_WIDTH{1'b0}};
            phase_offset          <= {PHASE_WIDTH{1'b0}};
            phase_accumulator     <= {PHASE_WIDTH{1'b0}};
            wave_valid            <= 1'b0;
        end else begin
            // Block Memory Generator is configured for one clock of latency.
            wave_valid <= active_enable;

            if (config_pending) begin
                active_enable         <= cfg_enable_async;
                phase_increment       <= cfg_phase_inc_async;
                phase_offset          <= cfg_phase_offset_async;
                cfg_update_ack_toggle <= cfg_update_sync;

                if (cfg_clear_phase_async)
                    phase_accumulator <= {PHASE_WIDTH{1'b0}};
            end else if (active_enable) begin
                phase_accumulator <= phase_accumulator + phase_increment;
            end
        end
    end

    // Generate this IP with ip/create_dds_wave_rom.tcl.  Keep the IP module
    // name and native port names unchanged.
    dds_wave_rom dds_wave_rom_inst (
        .clka  (dds_aclk),
        .ena   (active_enable),
        .addra (rom_address),
        .douta (rom_data)
    );

endmodule
