`timescale 1 ns / 1 ps

module tb_axi_dds;
    reg axi_clk = 1'b0;
    reg dds_clk = 1'b0;
    always #5.0 axi_clk = ~axi_clk;
    always #3.5 dds_clk = ~dds_clk;

    reg axi_resetn = 1'b0;
    reg dds_resetn = 1'b0;

    reg  [0:0]  awid;
    reg  [5:0]  awaddr;
    reg  [7:0]  awlen;
    reg  [2:0]  awsize;
    reg  [1:0]  awburst;
    reg         awlock;
    reg  [3:0]  awcache;
    reg  [2:0]  awprot;
    reg  [3:0]  awqos;
    reg  [3:0]  awregion;
    reg  [0:0]  awuser;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wlast;
    reg  [0:0]  wuser;
    reg         wvalid;
    wire        wready;
    wire [0:0]  bid;
    wire [1:0]  bresp;
    wire [0:0]  buser;
    wire        bvalid;
    reg         bready;

    reg  [0:0]  arid;
    reg  [5:0]  araddr;
    reg  [7:0]  arlen;
    reg  [2:0]  arsize;
    reg  [1:0]  arburst;
    reg         arlock;
    reg  [3:0]  arcache;
    reg  [2:0]  arprot;
    reg  [3:0]  arqos;
    reg  [3:0]  arregion;
    reg  [0:0]  aruser;
    reg         arvalid;
    wire        arready;
    wire [0:0]  rid;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire [0:0]  ruser;
    wire        rvalid;
    reg         rready;

    wire signed [15:0] wave_data;
    wire               wave_valid;

    axi_dds #(
        .C_S00_AXI_AWUSER_WIDTH(1),
        .C_S00_AXI_ARUSER_WIDTH(1),
        .C_S00_AXI_WUSER_WIDTH (1),
        .C_S00_AXI_RUSER_WIDTH (1),
        .C_S00_AXI_BUSER_WIDTH (1)
    ) dut (
        .dds_aclk(dds_clk),
        .dds_aresetn(dds_resetn),
        .wave_data(wave_data),
        .wave_valid(wave_valid),
        .s00_axi_aclk(axi_clk),
        .s00_axi_aresetn(axi_resetn),
        .s00_axi_awid(awid),
        .s00_axi_awaddr(awaddr),
        .s00_axi_awlen(awlen),
        .s00_axi_awsize(awsize),
        .s00_axi_awburst(awburst),
        .s00_axi_awlock(awlock),
        .s00_axi_awcache(awcache),
        .s00_axi_awprot(awprot),
        .s00_axi_awqos(awqos),
        .s00_axi_awregion(awregion),
        .s00_axi_awuser(awuser),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata),
        .s00_axi_wstrb(wstrb),
        .s00_axi_wlast(wlast),
        .s00_axi_wuser(wuser),
        .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bid(bid),
        .s00_axi_bresp(bresp),
        .s00_axi_buser(buser),
        .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready),
        .s00_axi_arid(arid),
        .s00_axi_araddr(araddr),
        .s00_axi_arlen(arlen),
        .s00_axi_arsize(arsize),
        .s00_axi_arburst(arburst),
        .s00_axi_arlock(arlock),
        .s00_axi_arcache(arcache),
        .s00_axi_arprot(arprot),
        .s00_axi_arqos(arqos),
        .s00_axi_arregion(arregion),
        .s00_axi_aruser(aruser),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rid(rid),
        .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp),
        .s00_axi_rlast(rlast),
        .s00_axi_ruser(ruser),
        .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready)
    );

    task axi_write32;
        input [5:0]  address;
        input [31:0] value;
        begin
            @(negedge axi_clk);
            awaddr  <= address;
            awvalid <= 1'b1;
            while (!awready)
                @(negedge axi_clk);
            @(negedge axi_clk);
            awvalid <= 1'b0;

            wdata  <= value;
            wvalid <= 1'b1;
            while (!wready)
                @(negedge axi_clk);
            @(negedge axi_clk);
            wvalid <= 1'b0;

            while (!bvalid)
                @(negedge axi_clk);
            if (bresp != 2'b00)
                $fatal(1, "AXI write SLVERR at address 0x%02x", address);
            @(negedge axi_clk);
        end
    endtask

    task axi_read32;
        input  [5:0]  address;
        output [31:0] value;
        begin
            @(negedge axi_clk);
            araddr  <= address;
            arvalid <= 1'b1;
            while (!arready)
                @(negedge axi_clk);
            @(negedge axi_clk);
            arvalid <= 1'b0;

            while (!rvalid)
                @(negedge axi_clk);
            value = rdata;
            if ((rresp != 2'b00) || !rlast)
                $fatal(1, "AXI read response error at address 0x%02x", address);
            @(negedge axi_clk);
        end
    endtask

    reg [31:0] status_value;
    reg [15:0] first_address;
    reg [15:0] expected_address;
    reg [15:0] offset_first_sample;
    reg        request_before;
    integer sample_index;

    initial begin
        awid = 0;
        awaddr = 0;
        awlen = 0;
        awsize = 3'd2;
        awburst = 2'b01;
        awlock = 0;
        awcache = 0;
        awprot = 0;
        awqos = 0;
        awregion = 0;
        awuser = 0;
        awvalid = 0;
        wdata = 0;
        wstrb = 4'hf;
        wlast = 1;
        wuser = 0;
        wvalid = 0;
        bready = 1;

        arid = 0;
        araddr = 0;
        arlen = 0;
        arsize = 3'd2;
        arburst = 2'b01;
        arlock = 0;
        arcache = 0;
        arprot = 0;
        arqos = 0;
        arregion = 0;
        aruser = 0;
        arvalid = 0;
        rready = 1;

        #31 dds_resetn = 1'b1;
        #12 axi_resetn = 1'b1;

        // Address must advance by one ROM entry per DDS clock:
        // 2^(32-8) = 0x01000000.
        axi_write32(6'h00, 32'h00000001);
        axi_write32(6'h04, 32'h01000000);
        axi_write32(6'h08, 32'h00000000);
        axi_write32(6'h0c, 32'h00000003);

        axi_read32(6'h10, status_value);
        while (status_value[0])
            axi_read32(6'h10, status_value);
        if (!status_value[1])
            $fatal(1, "DDS active-enable status did not cross back to AXI");

        wait (wave_valid);
        #1;
        first_address = $unsigned(wave_data);
        expected_address = first_address;

        for (sample_index = 1; sample_index < 12;
             sample_index = sample_index + 1) begin
            @(posedge dds_clk);
            #1;
            expected_address = {8'd0, expected_address[7:0] + 8'd1};
            if ($unsigned(wave_data) !== expected_address)
                $fatal(1, "Sample %0d was %04x", sample_index, wave_data);
        end

        // Apply a 180-degree offset and clear phase.  The first ROM address
        // following the acknowledged update must be 0x80.
        axi_write32(6'h08, 32'h80000000);
        request_before =
            dut.axi_dds_slave_full_v1_S00_AXI_inst.cfg_update_toggle;
        fork
            begin
                wait (dut.axi_dds_slave_full_v1_S00_AXI_inst
                        .cfg_update_toggle != request_before);
                wait (dut.axi_dds_slave_full_v1_S00_AXI_inst
                        .cfg_update_toggle ==
                      dut.axi_dds_slave_full_v1_S00_AXI_inst
                        .cfg_update_ack_toggle);
                @(posedge dds_clk);
                #1;
                offset_first_sample = $unsigned(wave_data);
            end
            begin
                axi_write32(6'h0c, 32'h00000003);
            end
        join
        if (offset_first_sample !== 16'h0080)
            $fatal(1, "Offset sample was %04x, expected 0080",
                   offset_first_sample);

        $display("PASS: AXI register access, CDC apply, and DDS phase stepping");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Simulation timeout");
    end

endmodule
