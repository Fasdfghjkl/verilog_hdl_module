module crc16_16b (				//crc[15:0]=1+x^2+x^15+x^16;
  input   wire  clk,
  input   wire  rst,

  input   wire  crc_en,
  input   wire  [15:0]  data_in,

  output  wire  [15:0]  crc_out
);

reg  [15:0] lfsr_q;
reg  [15:0] lfsr_c;

assign crc_out = lfsr_q;

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst)
        lfsr_q <= 16'hffff;
    else
        lfsr_q <= crc_en ? lfsr_c : lfsr_q;
end

always @(*) begin
  lfsr_c[0] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^ lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[15] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7] ^ data_in[8] ^ data_in[9] ^ data_in[10] ^ data_in[11] ^ data_in[12] ^ data_in[13] ^ data_in[15];
  lfsr_c[1] = lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^ lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[13] ^ lfsr_q[14] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7] ^ data_in[8] ^ data_in[9] ^ data_in[10] ^ data_in[11] ^ data_in[12] ^ data_in[13] ^ data_in[14];
  lfsr_c[2] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[14] ^ data_in[0] ^ data_in[1] ^ data_in[14];
  lfsr_c[3] = lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[15] ^ data_in[1] ^ data_in[2] ^ data_in[15];
  lfsr_c[4] = lfsr_q[2] ^ lfsr_q[3] ^ data_in[2] ^ data_in[3];
  lfsr_c[5] = lfsr_q[3] ^ lfsr_q[4] ^ data_in[3] ^ data_in[4];
  lfsr_c[6] = lfsr_q[4] ^ lfsr_q[5] ^ data_in[4] ^ data_in[5];
  lfsr_c[7] = lfsr_q[5] ^ lfsr_q[6] ^ data_in[5] ^ data_in[6];
  lfsr_c[8] = lfsr_q[6] ^ lfsr_q[7] ^ data_in[6] ^ data_in[7];
  lfsr_c[9] = lfsr_q[7] ^ lfsr_q[8] ^ data_in[7] ^ data_in[8];
  lfsr_c[10] = lfsr_q[8] ^ lfsr_q[9] ^ data_in[8] ^ data_in[9];
  lfsr_c[11] = lfsr_q[9] ^ lfsr_q[10] ^ data_in[9] ^ data_in[10];
  lfsr_c[12] = lfsr_q[10] ^ lfsr_q[11] ^ data_in[10] ^ data_in[11];
  lfsr_c[13] = lfsr_q[11] ^ lfsr_q[12] ^ data_in[11] ^ data_in[12];
  lfsr_c[14] = lfsr_q[12] ^ lfsr_q[13] ^ data_in[12] ^ data_in[13];
  lfsr_c[15] = lfsr_q[0] ^ lfsr_q[1] ^ lfsr_q[2] ^ lfsr_q[3] ^ lfsr_q[4] ^ lfsr_q[5] ^ lfsr_q[6] ^ lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[14] ^ lfsr_q[15] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7] ^ data_in[8] ^ data_in[9] ^ data_in[10] ^ data_in[11] ^ data_in[12] ^ data_in[14] ^ data_in[15];
end

endmodule
