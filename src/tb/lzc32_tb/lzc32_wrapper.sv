module lzc32_wrapper (
    input logic [31:0] datain,
    output logic [4:0] zero_count,
    output logic all_zeros
);

  lzc32 DUT (
      .datain(datain),
      .zero_count(zero_count),
      .all_zeros(all_zeros)
  );

endmodule
