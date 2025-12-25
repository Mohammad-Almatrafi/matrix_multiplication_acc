module lzc64_wrapper (
    input logic [63:0] datain,
    output logic [5:0] zero_count,
    output logic all_zeros
);

  lzc64 DUT (
      .datain(datain),
      .zero_count(zero_count),
      .all_zeros(all_zeros)
  );

endmodule
