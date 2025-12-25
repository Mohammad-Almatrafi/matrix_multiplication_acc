module lzc16_wrapper (
    input logic [15:0] datain,
    input logic [15:0] i,
    output logic [3:0] zero_count,
    output logic all_zeros
);

  lzc16 DUT (
      .datain(datain),
      .zero_count(zero_count),
      .all_zeros(all_zeros)
  );

endmodule
