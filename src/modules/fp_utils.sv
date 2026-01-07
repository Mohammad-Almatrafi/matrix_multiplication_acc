module fp_sort #(
    parameter int SIZE = 32
) (
    input  logic [SIZE-1:0] A,
    input  logic [SIZE-1:0] B,
    output logic [SIZE-1:0] op1,
    output logic [SIZE-1:0] op2
);

  logic A_ge_B;
  assign A_ge_B = A[SIZE-2:0] >= B[SIZE-2:0];

  assign op1 = A_ge_B ? A : B;
  assign op2 = A_ge_B ? B : A;

endmodule

module fp_align_add #(
    parameter int SIZE = 32,
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input logic [SIZE-1:0] op1,
    input logic [SIZE-1:0] op2,
    output logic [MANTISSA_SIZE:0] sum,
    output logic cout,
    output logic guard_bit,
    output logic round_bit,
    output logic sticky_bit,
    output logic subtract
);

  logic op1_sign;
  logic op2_sign;
  logic [MANTISSA_SIZE:0] op1_man;
  logic [MANTISSA_SIZE:0] op2_man;
  logic [EXPONENT_SIZE-1:0] shift_amt;
  logic [EXPONENT_SIZE-1:0] op1_exp;
  logic [EXPONENT_SIZE-1:0] op2_exp;
  logic [MANTISSA_SIZE-1:0] op1_man_temp;
  logic [MANTISSA_SIZE-1:0] op2_man_temp;
  logic [MANTISSA_SIZE-1:0] sticky_bits;
  logic op1_imp_1;
  logic op2_imp_1;
  logic [MANTISSA_SIZE*2+2:0] padded_op2;

  assign op1_sign = op1[SIZE-1];
  assign op2_sign = op2[SIZE-1];
  assign subtract = op1_sign ^ op2_sign;
  assign op1_man_temp = op1[MANTISSA_SIZE-1:0];
  assign op2_man_temp = op2[MANTISSA_SIZE-1:0];
  assign op1_exp = op1[SIZE-2:MANTISSA_SIZE];
  assign op2_exp = op2[SIZE-2:MANTISSA_SIZE];

  assign op1_imp_1 = op1_exp != 0;
  assign op2_imp_1 = op1_exp != 0;
  always @(*) begin
    shift_amt = op1_exp - op2_exp;
    op1_man = {op1_imp_1, op1_man_temp};
    padded_op2 = {op2_imp_1, op2_man_temp, {(MANTISSA_SIZE + 2) {1'b0}}};
    padded_op2 = padded_op2 >> shift_amt;
    {op2_man, guard_bit, round_bit, sticky_bits} = subtract ? -padded_op2 : padded_op2;
    sticky_bit = |sticky_bits;
  end

  assign {cout, sum} = op1_man + op2_man;
endmodule

module fp_normalize_round #(
    parameter int SIZE = 32,
    parameter int EXPONENT_SIZE = 8,
    parameter int MANTISSA_SIZE = 23
) (
    input logic cout,
    input logic guard_bit,
    input logic round_bit,
    input logic sticky_bit,
    input logic subtract,
    input logic [MANTISSA_SIZE:0] sum,
    input logic [SIZE-1:0] op1,
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

    if (cout ^ subtract) begin
      norm_exp = exponent + 1;
      norm_man = sum[MANTISSA_SIZE:1];
    end else if (all_zeros) begin
      norm_exp = 0;
      norm_man = 0;
    end else begin
      norm_exp = exponent - {{(EXPONENT_SIZE - ZC_WIDTH) {1'b0}}, zero_count};
      {norm_man, new_guard_bit, new_round_bit,discarded_bit} = {sum[MANTISSA_SIZE-1:0], guard_bit, round_bit,sticky_bit} << zero_count;
    end
  end

  logic [MANTISSA_SIZE-1:0] round_man;
  logic [EXPONENT_SIZE-1:0] round_exp;
  logic round_cout;

  always @(*) begin : rounding_step
    round_cout = 0;
    round_man  = norm_man;
    round_exp  = norm_exp;
    if (new_guard_bit) begin
      {round_cout, round_man} = norm_man + 1;
      round_exp = round_cout ? norm_exp + 1 : norm_exp;
    end
  end
  assign normalized_fp = {op1[SIZE-1], round_exp, round_man};


endmodule
