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

  initial begin
    if (MANTISSA_SIZE == 0 && EXPONENT_SIZE == 0)
      $fatal(1, "Floating point size 32 is the only one supported for now");
    //  %0d is not specified by the IEEE 754 standard", SIZE);
  end

  logic [SIZE-1:0] op1;
  logic [SIZE-1:0] op2;
  logic [EXPONENT_SIZE-1:0] temp_exponent;
  logic [EXPONENT_SIZE-1:0] out_exponent;

  logic [MANTISSA_SIZE*2+1:0] temp_mantissa;
  logic [MANTISSA_SIZE:0] temp_mantissa2;
  logic [MANTISSA_SIZE-1:0] out_mantissa;
  logic out_sign;
  logic cout;

  logic subtract;
  logic [EXPONENT_SIZE-1:0] shift_amt;

  fp_add_order #(
      .SIZE(SIZE),
      .EXPONENT_SIZE(EXPONENT_SIZE),
      .MANTISSA_SIZE(MANTISSA_SIZE)
  ) fp_add_order_inst (
      .A(A),
      .B(B),

      .op1(op1),
      .op2(op2),
      .shift_amt(shift_amt),
      .subtract(subtract)
  );

  fp_add_shift #(
      .MANTISSA_SIZE(MANTISSA_SIZE),
      .EXPONENT_SIZE(EXPONENT_SIZE)
  ) fp_add_shift_inst (
      .op1(op1),
      .op2(op2),

      .shift_amt(shift_amt),
      .subtract(subtract),
      .cout(cout),
      .out_sign(out_sign),
      .out_exponent(temp_exponent),
      .out_mantissa(temp_mantissa)
  );
  fp_add_exp_round_calc #(
      .EXPONENT_SIZE(EXPONENT_SIZE),
      .MANTISSA_SIZE(MANTISSA_SIZE)
  ) fp_add_exp_round_cal_inst (
      .mantissa(temp_mantissa),
      .exponent(temp_exponent),
      .subtract(subtract),
      .cout(cout),
      .out_mantissa(out_mantissa),
      .out_exponent(out_exponent)
  );

  assign Y = {out_sign, temp_exponent, out_mantissa};

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
    output logic cout,
    output logic out_sign,
    output logic [EXPONENT_SIZE-1:0] out_exponent,
    output logic [MANTISSA_SIZE*2+1:0] out_mantissa
);

  logic op1_implicit_1;
  logic op2_implicit_1;
  logic [MANTISSA_SIZE-1:0] op1_man;
  logic [MANTISSA_SIZE-1:0] op2_man;
  logic [EXPONENT_SIZE-1:0] op1_exp;
  logic [EXPONENT_SIZE-1:0] op2_exp;

  logic [MANTISSA_SIZE*2+1:0] op2_man_padded;
  logic [MANTISSA_SIZE*2+1:0] op1_man_padded;
  logic [MANTISSA_SIZE*2+1:0] shifted_op2_man;
  logic [MANTISSA_SIZE*2+1:0] xor_value;
  logic [MANTISSA_SIZE*2+1:0] op2_man_temp;

  assign op1_man = op1[SIZE-EXPONENT_SIZE-2:0];
  assign op2_man = op2[SIZE-EXPONENT_SIZE-2:0];
  assign op1_exp = op1[SIZE-2:SIZE-EXPONENT_SIZE-1];
  assign op2_exp = op2[SIZE-2:SIZE-EXPONENT_SIZE-1];

  assign op1_implicit_1 = op1_exp != 0;
  assign op2_implicit_1 = op2_exp != 0;

  assign op2_man_padded = {op2_implicit_1, op2_man, {(MANTISSA_SIZE + 1) {1'b0}}};
  assign shifted_op2_man = op2_man_padded >> shift_amt;
  assign xor_value = {(MANTISSA_SIZE * 2 + 2) {subtract}} ^ shifted_op2_man;
  assign op2_man_temp = xor_value + {{(MANTISSA_SIZE * 2 + 1) {1'b0}}, subtract};
  assign op1_man_padded = {op1_implicit_1, op1_man, {((MANTISSA_SIZE + 1)) {1'b0}}};

  assign {cout, out_mantissa} = op1_man_padded + op2_man_temp;
  assign out_exponent = cout ? op1_exp + 1 : op1_exp;

  assign out_sign = op1[SIZE-1];

endmodule

module fp_add_exp_round_calc #(
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input logic [MANTISSA_SIZE*2+1:0] mantissa,
    input logic [EXPONENT_SIZE-1:0] exponent,
    input logic subtract,
    input logic cout,
    output logic [MANTISSA_SIZE-1:0] out_mantissa,
    output logic [EXPONENT_SIZE-1:0] out_exponent
);
  localparam int SIZE = MANTISSA_SIZE + EXPONENT_SIZE + 1;
  localparam int LZC_DI_SIZE = SIZE == 32 ? 64 : 1;
  localparam int LZC_ZC_SIZE = $clog2(LZC_DI_SIZE);
  logic [LZC_DI_SIZE-1:0] padded_mantissa;
  logic [LZC_ZC_SIZE-1:0] zero_count;
  logic all_zeros;
  logic [MANTISSA_SIZE*2+1:0] temp_mantissa_padded;
  logic [MANTISSA_SIZE:0] temp_mantissa;
  generate
    case (SIZE)
      32: begin : gen_32F_case
        assign padded_mantissa = {mantissa, {(LZC_DI_SIZE - (MANTISSA_SIZE * 2 + 2)) {1'b1}}};
        lzc64 lzc64_inst (
            .datain(padded_mantissa),
            .zero_count(zero_count),
            .all_zeros(all_zeros)
        );
      end
    endcase
  endgenerate
  logic [MANTISSA_SIZE:0] man_sel[0:1];
  assign man_sel[0] = temp_mantissa_padded[MANTISSA_SIZE*2+1:MANTISSA_SIZE+1];
  assign man_sel[1] = temp_mantissa_padded[MANTISSA_SIZE*2:MANTISSA_SIZE];
  assign temp_mantissa_padded = mantissa << zero_count;
  assign temp_mantissa = cout ^ subtract ? man_sel[0] : man_sel[1];
  assign out_mantissa = temp_mantissa[0] ? temp_mantissa[MANTISSA_SIZE:1] + 1:
                                           temp_mantissa[MANTISSA_SIZE:1];

  assign out_exponent = exponent - {{(EXPONENT_SIZE - LZC_ZC_SIZE) {1'b0}}, zero_count};

  // TODO(Rur1k): add rounding modes

endmodule


module lzc4 (
    input logic [3:0] datain,
    output logic [1:0] zero_count,
    output logic all_zeros
);

  assign zero_count[0] = (~datain[3] & datain[2]) | (~datain[3] & ~datain[1]);
  assign zero_count[1] = ~(datain[3] | datain[2]);
  assign all_zeros = ~(|datain);

endmodule

module lzc16 (
    input logic [15:0] datain,
    output logic [3:0] zero_count,
    output logic all_zeros
);

  logic [1:0] temp_zero_count[0:3];
  logic [1:0] group_sel;
  logic [3:0] temp_all_zeros;

  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : gen_lzc4
      lzc4 lzc_inst (
          .datain(datain[15-(4*i):15-(4*i)-3]),
          .zero_count(temp_zero_count[i]),
          .all_zeros(temp_all_zeros[3-i])
      );
    end
  endgenerate

  lzc4 lzc_inst (
      .datain(~temp_all_zeros),
      .zero_count(group_sel),
      .all_zeros(all_zeros)
  );
  assign zero_count[3:2] = group_sel;
  assign zero_count[1:0] = temp_zero_count[group_sel];

endmodule

module lzc64 (
    input logic [63:0] datain,
    output logic [5:0] zero_count,
    output logic all_zeros
);

  logic [3:0] temp_zero_count[0:3];
  logic [1:0] group_sel;
  logic [3:0] temp_all_zeros;

  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : gen_lzc4
      lzc16 lzc_inst (
          .datain(datain[63-(16*i):63-(16*i)-15]),
          .zero_count(temp_zero_count[i]),
          .all_zeros(temp_all_zeros[3-i])
      );
    end
  endgenerate

  lzc4 lzc_inst (
      .datain(~temp_all_zeros),
      .zero_count(group_sel),
      .all_zeros(all_zeros)
  );
  assign zero_count[5:4] = group_sel;
  assign zero_count[3:0] = temp_zero_count[group_sel];

endmodule
