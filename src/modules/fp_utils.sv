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

  logic subtract;
  logic A_exp_gt_B_exp;
  logic cout;
  logic op1_sign;
  logic [EXPONENT-1:0] A_exp;
  logic [EXPONENT-1:0] B_exp;
  logic [MANTISSA-1:0] A_man;
  logic [MANTISSA-1:0] B_man;
  logic [EXPONENT-1:0] op1_exp;
  logic [EXPONENT-1:0] op2_exp;
  logic [MANTISSA:0]shifted_op2_man;
  logic [MANTISSA-1:0] op1_man;
  logic [MANTISSA-1:0] op2_man;
  logic [MANTISSA:0] op2_man_temp;
  logic [EXPONENT-1:0] shift_amt;
  logic [MANTISSA:0] temp_mantissa;
  logic [MANTISSA-1:0] out_mantissa;
  logic [EXPONENT-1:0] temp_exponent;
  logic op1_implicit_1;
  logic op2_implicit_1;

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

  assign subtract = A[SIZE-1] ^ B[SIZE-1];
  assign A_exp = A[SIZE-2:SIZE-EXPONENT-1];
  assign B_exp = B[SIZE-2:SIZE-EXPONENT-1];
  assign A_man = A[SIZE-2-EXPONENT:0];
  assign B_man = B[SIZE-2-EXPONENT:0];
  assign op1_implicit_1 = A_exp != 0;
  assign op2_implicit_1 = B_exp != 0;

  assign A_exp_gt_B_exp = A_exp > B_exp;
  assign op1_exp = A_exp_gt_B_exp ? A_exp : B_exp;
  assign op2_exp = A_exp_gt_B_exp ? B_exp : A_exp;
  assign op1_sign = A_exp_gt_B_exp ? A[SIZE-1] : B[SIZE-1];

  assign shift_amt = (op1_exp - op2_exp);

  assign op1_man = A_exp_gt_B_exp ? A_man : B_man;
  assign op2_man = A_exp_gt_B_exp ? B_man : A_man;
  assign shifted_op2_man = {op2_implicit_1, op2_man} >> shift_amt;

  assign op2_man_temp = {(MANTISSA+1){subtract}} ^ shifted_op2_man +
                    {{(MANTISSA) {1'b0}}, subtract};

  // TODO(Rur1k): add rounding modes
  assign {cout, temp_mantissa} = {op1_implicit_1, op1_man} + op2_man_temp;
  assign out_mantissa = temp_exponent=={EXPONENT{1'b1}} ? 23'h0:
                        (cout ? temp_mantissa[MANTISSA:1]:
                         temp_mantissa[MANTISSA-1:0]);
  assign temp_exponent = cout ? op1_exp + 1 : op1_exp;
  assign Y = {op1_sign, temp_exponent, out_mantissa};

endmodule

