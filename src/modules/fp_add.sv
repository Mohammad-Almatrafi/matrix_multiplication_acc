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

  localparam int EXPONENT_SIZE = SIZE == 32 ? 8 : 0;
  localparam int MANTISSA_SIZE = SIZE == 32 ? 23 : 0;

  logic [SIZE-1:0] op1, op2;
  logic [MANTISSA_SIZE:0] sum;
  logic cout, guard_bit, round_bit, sticky_bit, subtract;
  logic [SIZE-1:0] normalized_fp;
  logic op1_imp_1;
  initial begin
    if (MANTISSA_SIZE == 0 && EXPONENT_SIZE == 0)
      $fatal(1, "Floating point size 32 is the only one supported for now");
    //  %0d is not specified by the IEEE 754 standard", SIZE);
  end

  fp_sort #(
      .SIZE(SIZE)
  ) fp_sort_inst (
      .A  (A),
      .B  (B),
      .op1(op1),
      .op2(op2)
  );

  fp_align_add #(
      .SIZE(SIZE),
      .EXPONENT_SIZE(EXPONENT_SIZE),
      .MANTISSA_SIZE(MANTISSA_SIZE)
  ) fp_align_add_inst (
      .op1(op1),
      .op2(op2),
      .sum(sum),
      .cout(cout),
      .guard_bit(guard_bit),
      .round_bit(round_bit),
      .sticky_bit(sticky_bit),
      .subtract(subtract),
      .op1_imp_1(op1_imp_1)
  );

  fp_normalize_round #(
      .SIZE(SIZE),
      .EXPONENT_SIZE(EXPONENT_SIZE),
      .MANTISSA_SIZE(MANTISSA_SIZE)
  ) fp_normalize_round_inst (
      .op1_imp_1(op1_imp_1),
      .cout(cout),
      .guard_bit(guard_bit),
      .round_bit(round_bit),
      .sticky_bit(sticky_bit),
      .subtract(subtract),
      .sum(sum),
      .op1(op1),
      .normalized_fp(normalized_fp)
  );

  assign Y = normalized_fp;

endmodule

