`timescale 1 ns / 1 ps

// Simulation-only stand-in for the generated Xilinx dds_wave_rom IP.
// Returning the address makes phase/address sequencing easy to check.
module dds_wave_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [7:0]  addra,
    output reg  [15:0] douta
);
    always @(posedge clka) begin
        if (ena)
            douta <= {8'd0, addra};
    end
endmodule
