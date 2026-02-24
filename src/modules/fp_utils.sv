module fp_align_add #(
    parameter int SIZE = 32,
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input logic [SIZE-1:0] A,
    input logic [SIZE-1:0] B,
    output [SIZE-1:0] op1,
    output logic [MANTISSA_SIZE:0] sum,
    output logic op1_imp_1,
    output logic cout,
    output logic guard_bit,
    output logic round_bit,
    output logic sticky_bit,
    output logic subtract,
    output logic A_is_nan,
    output logic B_is_nan
);

  logic [SIZE-1:0] op2;
  logic op1_sign;
  logic op2_sign;
  logic [MANTISSA_SIZE:0] op1_man, op2_man, op2_man_temp2;
  logic [EXPONENT_SIZE-1:0] shift_amt;
  logic [EXPONENT_SIZE-1:0] op1_exp, op2_exp, comp_op1_exp, comp_op2_exp;
  logic [MANTISSA_SIZE-1:0] op1_man_temp, op2_man_temp;
  logic [MANTISSA_SIZE-1:0] sticky_bits;
  logic op2_imp_1;
  logic [MANTISSA_SIZE*2+2:0] padded_op2;
  logic neg_cout, op_cout;
  logic A_ge_B;

  assign A_ge_B = A[SIZE-2:0] >= B[SIZE-2:0];

  assign op1 = A_ge_B ? A : B;
  assign op2 = A_ge_B ? B : A;
  assign op1_sign = op1[SIZE-1];
  assign op2_sign = op2[SIZE-1];
  assign subtract = op1_sign ^ op2_sign;
  assign op1_man_temp = op1[MANTISSA_SIZE-1:0];
  assign op2_man_temp = op2[MANTISSA_SIZE-1:0];
  assign op1_exp = op1[SIZE-2:MANTISSA_SIZE];
  assign op2_exp = op2[SIZE-2:MANTISSA_SIZE];


  assign op1_imp_1 = op1_exp != 0;
  assign op2_imp_1 = op2_exp != 0;
  assign comp_op1_exp = op1_exp;  //op1_imp_1 ?  : 1;
  assign comp_op2_exp = op2_exp;  //op2_imp_1 ?  : 1;
  assign A_is_nan = A[SIZE-2:MANTISSA_SIZE] == {EXPONENT_SIZE{1'b1}} & A[MANTISSA_SIZE-1:0] != 0;
  assign B_is_nan = B[SIZE-2:MANTISSA_SIZE] == {EXPONENT_SIZE{1'b1}} & B[MANTISSA_SIZE-1:0] != 0;

  always @(*) begin
    shift_amt = comp_op1_exp - comp_op2_exp;
    op1_man = op1_imp_1 ? {1'b1, op1_man_temp} : {op1_man_temp, 1'b0};
    op2_man_temp2 = op2_imp_1 ? {1'b1, op2_man_temp} : {op2_man_temp, 1'b0};
    padded_op2 = {op2_man_temp2, {(MANTISSA_SIZE + 2) {1'b0}}};
    padded_op2 = padded_op2 >> shift_amt;
    padded_op2 = padded_op2 ^ {(MANTISSA_SIZE * 2 + 3) {subtract}};
    {neg_cout,op2_man, guard_bit, round_bit, sticky_bits} = padded_op2 + {{(MANTISSA_SIZE*2+2){1'b0}},subtract};
    sticky_bit = |sticky_bits;
  end

  assign {op_cout, sum} = op1_man + op2_man;

  assign cout = op_cout | neg_cout;
endmodule

module fp_normalize_round #(
    parameter int SIZE = 32,
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input [SIZE-1:0] A,
    input [SIZE-1:0] B,
    input logic A_is_nan,
    input logic B_is_nan,
    input logic cout,
    input logic guard_bit,
    input logic round_bit,
    input logic sticky_bit,
    input logic subtract,
    input logic [MANTISSA_SIZE:0] sum,
    input logic [SIZE-1:0] op1,
    input logic op1_imp_1,
    output logic [SIZE-1:0] normalized_fp
);

  localparam ZC_WIDTH = $clog2(MANTISSA_SIZE);
  logic [ZC_WIDTH-1:0] zero_count;
  logic all_zeros;
  logic [EXPONENT_SIZE-1:0] exponent;
  logic [MANTISSA_SIZE-1:0] norm_man;
  logic [EXPONENT_SIZE-1:0] norm_exp;
  logic discarded_bit;
  logic new_guard_bit;
  logic new_round_bit;
  assign exponent = op1[SIZE-2:MANTISSA_SIZE];

  generate
    case (SIZE)
      16: begin
      end
      32: begin : gen_32float
        lzc32 lzc32_inst (
            .datain({sum, 8'b0}),
            .zero_count(zero_count),
            .all_zeros(all_zeros)
        );
      end
      64: begin
      end
      128: begin
      end

    endcase

  endgenerate

  always @(*) begin : normalization_step
    discarded_bit = 0;
    new_guard_bit = guard_bit;
    new_round_bit = round_bit;

    if (~op1_imp_1 & sum[MANTISSA_SIZE] & ~subtract) begin
      norm_exp = exponent + 1;
      norm_man = sum[MANTISSA_SIZE-1:0];
      new_guard_bit = guard_bit;
      new_round_bit = round_bit;
      discarded_bit = discarded_bit;
    end else if (cout ^ subtract) begin
      norm_exp = exponent + 1;
      norm_man = sum[MANTISSA_SIZE:1];
      new_guard_bit = sum[0];
      new_round_bit = guard_bit;
      discarded_bit = round_bit;

    end else if (all_zeros) begin
      norm_exp = 0;
      norm_man = 0;
      new_guard_bit = 0;
      new_round_bit = 0;

    end else begin
      norm_exp = exponent - {{(EXPONENT_SIZE - ZC_WIDTH) {1'b0}}, zero_count};
      if (norm_exp > exponent) begin
        norm_exp = 0;
      end
      if (norm_exp == 0) begin
        {norm_man, new_guard_bit, new_round_bit, discarded_bit} = {
          sum[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bit
        };
      end else
        {norm_man, new_guard_bit, new_round_bit, discarded_bit} = {sum[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bit} << zero_count;
    end
  end

  logic [MANTISSA_SIZE-1:0] round_man;
  logic [EXPONENT_SIZE-1:0] round_exp;
  logic round_cout;
  logic RNE, RTINF, RTNINF;

  logic new_sticky_bit;
  assign new_sticky_bit = sticky_bit | discarded_bit;
  assign RNE = new_guard_bit & (new_round_bit | new_sticky_bit | norm_man[0]);
  // assign RTINF = ~op1[SIZE-1] & (new_guard_bit | new_round_bit | new_sticky_bit);
  // assign RTNINF = op1[SIZE-1] & (new_guard_bit | new_round_bit | new_sticky_bit);

  always @(*) begin : rounding_step
    round_cout = 0;
    round_man  = norm_man;
    round_exp  = norm_exp;

    if (RNE) begin
      {round_cout, round_man} = norm_man + 1;
      round_exp = round_cout ? norm_exp + 1 : norm_exp;
    end

  end
  always @(*) begin
    if (A_is_nan) normalized_fp = A | 1 << 22;
    else if (B_is_nan) normalized_fp = B | 1 << 22;
    else if (round_exp == {EXPONENT_SIZE{1'b1}})
      normalized_fp = {op1[SIZE-1], round_exp, {MANTISSA_SIZE{1'b0}}};
    else normalized_fp = {op1[SIZE-1], round_exp, round_man};
  end

endmodule
