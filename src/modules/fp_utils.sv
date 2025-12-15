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

  localparam int EXPONENT = SIZE == 16 ? 5 :
                            SIZE == 32 ? 8 :
                            SIZE == 64 ? 11 :
                            SIZE == 128 ? 15 :
                            0;

  localparam int MANTISSA = SIZE == 16 ? 10 :
                            SIZE == 32 ? 23 :
                            SIZE == 64 ? 52 :
                            SIZE == 128 ? 112 :
                            0;

  initial begin
    if (MANTISSA == 0 && EXPONENT == 0)
      $fatal(1, "Floating point size %0d is not specified by the IEEE 754 standard", SIZE);
  end

  logic [SIZE-1:0] op1;
  logic [SIZE-1:0] op2;
  logic [EXPONENT-1:0] out_exponent;
  logic [MANTISSA-1:0] out_mantissa;
  logic out_sign;

  logic subtract;
  logic [EXPONENT-1:0] shift_amt;

  fp_add_order #(
      .SIZE(SIZE),
      .EXPONENT_SIZE(EXPONENT),
      .MANTISSA_SIZE(MANTISSA)
  ) fp_add_order_inst (
      .A(A),
      .B(B),

      .op1(op1),
      .op2(op2),
      .shift_amt(shift_amt),
      .subtract(subtract)
  );

  fp_add_shift #(
      .MANTISSA_SIZE(MANTISSA),
      .EXPONENT_SIZE(EXPONENT)
  ) fp_add_shift_inst (
      .op1(op1),
      .op2(op2),

      .shift_amt(shift_amt),
      .subtract(subtract),
      .out_sign(out_sign),
      .out_exponent(out_exponent),
      .out_mantissa(out_mantissa)
  );

  assign Y = {out_sign, out_exponent, out_mantissa};

endmodule


module fp_add_order #(
    parameter int SIZE = 32,
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input logic [SIZE-1:0] A,
    input logic [SIZE-1:0] B,
    output logic [SIZE-1:0] op1,
    output logic [SIZE-1:0] op2,
    output logic [EXPONENT_SIZE-1:0] shift_amt,
    output logic subtract
);

  logic [EXPONENT_SIZE-1:0] A_exp, B_exp;
  logic A_exp_gt_B_exp;

  assign subtract = A[SIZE-1] ^ B[SIZE-1];

  assign A_exp = A[SIZE-2:SIZE-EXPONENT_SIZE-1];
  assign B_exp = B[SIZE-2:SIZE-EXPONENT_SIZE-1];

  assign A_exp_gt_B_exp = A_exp > B_exp;

  assign shift_amt = (op1[SIZE-2:SIZE-EXPONENT_SIZE-1] - op2[SIZE-2:SIZE-EXPONENT_SIZE-1]);

  assign op1 = A_exp_gt_B_exp ? A : B;
  assign op2 = A_exp_gt_B_exp ? B : A;

endmodule

module fp_add_shift #(
    parameter int SIZE = 32,
    parameter int MANTISSA_SIZE = 23,
    parameter int EXPONENT_SIZE = 8
) (
    input logic [SIZE-1:0] op1,
    input logic [SIZE-1:0] op2,
    input logic [EXPONENT_SIZE-1:0] shift_amt,
    input logic subtract,
    output logic out_sign,
    output logic [EXPONENT_SIZE-1:0] out_exponent,
    output logic [MANTISSA_SIZE-1:0] out_mantissa
);

  logic op1_implicit_1;
  logic op2_implicit_1;
  logic [MANTISSA_SIZE-1:0] op1_man;
  logic [MANTISSA_SIZE-1:0] op2_man;
  logic [EXPONENT_SIZE-1:0] op1_exp;
  logic [EXPONENT_SIZE-1:0] op2_exp;
  logic [MANTISSA_SIZE:0] temp_mantissa;
  logic [MANTISSA_SIZE:0] shifted_op2_man;
  logic [MANTISSA_SIZE:0] op2_man_temp;
  logic cout;

  assign op1_man = op1[SIZE-EXPONENT_SIZE-2:0];
  assign op2_man = op2[SIZE-EXPONENT_SIZE-2:0];
  assign op1_exp = op1[SIZE-2:SIZE-EXPONENT_SIZE-1];
  assign op2_exp = op2[SIZE-2:SIZE-EXPONENT_SIZE-1];

  assign op1_implicit_1 = op1_exp != 0;
  assign op2_implicit_1 = op2_exp != 0;

  assign shifted_op2_man = {op2_implicit_1, op2_man} >> shift_amt;

  assign op2_man_temp = {(MANTISSA_SIZE+1){subtract}} ^ shifted_op2_man +
                        {{(MANTISSA_SIZE) {1'b0}}, subtract};

  // TODO(Rur1k): add rounding modes
  assign {cout, temp_mantissa} = {op1_implicit_1, op1_man} + op2_man_temp;
  assign out_exponent = cout ? op1_exp + 1 : op1_exp;

  assign out_mantissa = out_exponent=={EXPONENT_SIZE{1'b1}} ? 23'h0:
                      (cout ? temp_mantissa[MANTISSA_SIZE:1]:
                       temp_mantissa[MANTISSA_SIZE-1:0]);
  assign out_sign = op1[SIZE-1];

endmodule

// module fp_add_exp_calc #(
//     parameter EXPONENT_SIZE = 8,
//     parameter MANTISSA_SIZE = 23
// ) (
//     input  [MANTISSA_SIZE-1:0] mantissa,
//     input  [MANTISSA_SIZE-1:0] exponent,
//     output [EXPONENT_SIZE-1:0] out_exponent
// );

// endmodule
