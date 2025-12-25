module fp_add_wrapper (
    input  [31:0] A,
    input  [31:0] B,
    output [31:0] Y
);

  fp_add #(
      .SIZE(32)
  ) DUT (
      .A(A),
      .B(B),
      .Y(Y)
  );

endmodule
