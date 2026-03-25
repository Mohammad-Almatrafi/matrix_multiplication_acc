/*
 * module: fp_add
 * description:
 * takes two floating point numbers and add them
 * 2025-12-2 NOTE(rur1k): the module doesn't work for any rounding mode
 * except truncation till now
 */

module fp_add #(
    parameter int SIZE = 32
) (
    input  logic [SIZE-1:0] A,
    input  logic [SIZE-1:0] B,
    output logic [SIZE-1:0] Y
);

  // NOTE(rur1k): support generalized case later
  // localparam int EXPONENT_SIZE = SIZE == 16 ? 5 :
  //                           SIZE == 32 ? 8 :
  //                           SIZE == 64 ? 11 :
  //                           SIZE == 128 ? 15 :
  //                           0;

  // localparam int MANTISSA_SIZE = SIZE == 16 ? 10 :
  //                           SIZE == 32 ? 23 :
  //                           SIZE == 64 ? 52 :
  //                           SIZE == 128 ? 112 :
  //                           0;

  localparam int NB_EXP = SIZE == 32 ? 8 : 0;
  localparam int NB_MAN = SIZE == 32 ? 23 : 0;

  fp_add_all #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) fp_add_all_inst (
      .A(A),
      .B(B),
      .Y(Y)
  );


endmodule

