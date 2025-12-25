module lzc4_wrapper (
    input logic [3:0] datain,
    output logic [1:0] zero_count,
    output logic all_zeros
);

  lzc4 DUT (
      .datain(datain),
      .zero_count(zero_count),
      .all_zeros(all_zeros)
  );

endmodule
