module fp_mult_wrapper (
    input  [31:0] A,
    input  [31:0] B,
    output [31:0] Y
);

  fp_mult #(
      .SIZE(32)
  ) DUT (
      .A(A),
      .B(B),
      .Y(Y)
  );

endmodule
