
module fp_mult #(
    parameter int SIZE = 32
) (
    input  logic [SIZE-1:0] A,
    input  logic [SIZE-1:0] B,
    output logic [SIZE-1:0] Y
);



  localparam int EXPONENT_SIZE = SIZE == 32 ? 8 : 0;
  localparam int MANTISSA_SIZE = SIZE == 32 ? 23 : 0;
  logic [EXPONENT_SIZE-1:0] A_exp, B_exp;
  logic [MANTISSA_SIZE-1:0] A_man, B_man;
  logic [MANTISSA_SIZE:0] A_man_post, B_man_post;
  logic A_sign, B_sign;
  logic [MANTISSA_SIZE*2+1:0] result_man;
  logic result_sign;
  logic [EXPONENT_SIZE+1:0] dbg_exponent, shift_amt;
  logic [EXPONENT_SIZE-1:0] result_exponent;
  logic A_imp_1, B_imp_1;
  logic [SIZE-1:0] result, round_result;
  logic sticky_bit, round_bit, guard_bit, round_cout;
  logic [MANTISSA_SIZE-1:0] sticky_bits;
  logic A_man_is_0, B_man_is_0, A_exp_is_max, B_exp_is_max;
  logic both_denormal, one_is_inf, one_is_NaN, one_is_denormal;
  logic [SIZE-1:0] normalized_fp;
  logic RNE;

  assign A_imp_1 = A_exp != 0;
  assign B_imp_1 = B_exp != 0;
  assign A_exp = A[SIZE-2:MANTISSA_SIZE];
  assign B_exp = B[SIZE-2:MANTISSA_SIZE];
  assign A_man = A[MANTISSA_SIZE-1:0];
  assign B_man = B[MANTISSA_SIZE-1:0];
  assign A_sign = A[SIZE-1];
  assign B_sign = B[SIZE-1];
  assign A_exp_is_max = A_exp == MAX_EXPONENT;
  assign B_exp_is_max = B_exp == MAX_EXPONENT;
  assign A_man_is_0 = A_man == 0;
  assign B_man_is_0 = B_man == 0;
  assign A_man_post = A_imp_1 ? {1'b1, A_man} : {A_man, 1'b0};
  assign B_man_post = B_imp_1 ? {1'b1, B_man} : {B_man, 1'b0};

  assign both_denormal = !A_imp_1 & !B_imp_1;
  assign one_is_denormal = (!A_imp_1 & B_imp_1) | (A_imp_1 & !B_imp_1);
  assign one_is_inf = (A_exp_is_max & A_man_is_0) | (B_exp_is_max & B_man_is_0);
  assign one_is_NaN = (A_exp_is_max & !A_man_is_0) | (B_exp_is_max & !B_man_is_0);

  assign result_man = A_man_post * B_man_post;
  assign result_sign = A_sign ^ B_sign;

  logic dbg_gt;
  localparam int ZC_WIDTH = $clog2(MANTISSA_SIZE * 2);
  logic [ZC_WIDTH-1:0] zero_count;
  logic all_zeros;
  generate
    case (SIZE)
      16: begin : gen_16float
      end
      32: begin : gen_32float
        lzc64 lzc64_inst (
            .datain({result_man[MANTISSA_SIZE*2:0], 17'b0}),
            .zero_count(zero_count),
            .all_zeros(all_zeros)
        );
      end
      64: begin : gen64float
      end
      128: begin : gen128float
      end

    endcase
  endgenerate

  localparam logic [EXPONENT_SIZE-1:0] MAX_MINUS_1 = 2 ** EXPONENT_SIZE - 2;
  localparam logic [EXPONENT_SIZE-1:0] MAX_EXPONENT = 2 ** EXPONENT_SIZE - 1;
  localparam logic [EXPONENT_SIZE-1:0] EXPNENT_BIAS = 2 ** (EXPONENT_SIZE - 1) - 1;
  localparam logic [MANTISSA_SIZE-1:0] qNaN = 2 ** (MANTISSA_SIZE - 1);

  always @(*) begin
    dbg_exponent = {2'b0, A_exp} + {2'b0, B_exp} - {2'b0, EXPNENT_BIAS};
    shift_amt = -dbg_exponent;
    result[SIZE-1] = result_sign;
    result_exponent = dbg_exponent[EXPONENT_SIZE-1:0];
    dbg_gt = $signed(dbg_exponent) > $signed({2'b0, MAX_MINUS_1});
    // dbg_gt = ;
    sticky_bits = 0;
    if (one_is_inf) begin
      result[SIZE-2:MANTISSA_SIZE] = MAX_EXPONENT;
      result[MANTISSA_SIZE-1:0] = 0;
      guard_bit = 0;
      round_bit = 0;
      sticky_bits = 0;
    end else if (one_is_NaN) begin
      result[SIZE-2:MANTISSA_SIZE] = MAX_EXPONENT;
      result[MANTISSA_SIZE-1:0] = qNaN;
      guard_bit = 0;
      round_bit = 0;
      sticky_bits = 0;
    end else if (both_denormal) begin
      result[SIZE-2:MANTISSA_SIZE] = 0;
      result[MANTISSA_SIZE-1:0] = 0;
      guard_bit = 0;
      round_bit = 0;
      sticky_bits = 0;
    end else if (dbg_gt) begin
      result[SIZE-2:MANTISSA_SIZE] = MAX_EXPONENT;
      result[MANTISSA_SIZE-1:0] = 0;
      guard_bit = 0;
      round_bit = 0;
      sticky_bits = 0;
    end else begin
      if (dbg_exponent[EXPONENT_SIZE+1]) begin
        if (result_man[MANTISSA_SIZE*2+1]) begin
          result[SIZE-1] = result_sign;
          result[SIZE-2:MANTISSA_SIZE] = 0;
          {result[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bits[MANTISSA_SIZE-1:0]} = result_man[MANTISSA_SIZE*2+1:0] >> (shift_amt-1);
        end else begin
          result[SIZE-1] = result_sign;
          result[SIZE-2:MANTISSA_SIZE] = 0;
          {result[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bits[MANTISSA_SIZE-2:0]} = result_man[MANTISSA_SIZE*2:0] >> shift_amt;
        end
      end else if (result_man[MANTISSA_SIZE*2+1]) begin
        result[SIZE-2:MANTISSA_SIZE] = result_exponent + 1;
        result[MANTISSA_SIZE-1:0] = result_man[MANTISSA_SIZE*2:MANTISSA_SIZE+1];
        guard_bit = result_man[MANTISSA_SIZE];
        round_bit = result_man[MANTISSA_SIZE-1];
        sticky_bits = {1'b0, result_man[MANTISSA_SIZE-2:0]};
      end else if (result_man[MANTISSA_SIZE*2]) begin
        if (dbg_exponent != 0) begin
          result[SIZE-2:MANTISSA_SIZE] = result_exponent;
          result[MANTISSA_SIZE-1:0] = result_man[MANTISSA_SIZE*2-1:MANTISSA_SIZE];
          guard_bit = result_man[MANTISSA_SIZE-1];
          round_bit = result_man[MANTISSA_SIZE-2];
          sticky_bits = {2'b0, result_man[MANTISSA_SIZE-3:0]};
        end else begin
          result[SIZE-2:MANTISSA_SIZE] = result_exponent;
          result[MANTISSA_SIZE-1:0] = result_man[MANTISSA_SIZE*2:MANTISSA_SIZE+1];
          guard_bit = result_man[MANTISSA_SIZE];
          round_bit = result_man[MANTISSA_SIZE-1];
          sticky_bits = {1'b0, result_man[MANTISSA_SIZE-2:0]};
        end
      end else begin
        result[SIZE-2:MANTISSA_SIZE] = result_exponent - {{(EXPONENT_SIZE - ZC_WIDTH) {1'b0}}, zero_count};
        if (result[SIZE-2:MANTISSA_SIZE] > result_exponent) begin
          result[SIZE-2:MANTISSA_SIZE] = 0;
          {result[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bits[MANTISSA_SIZE-2:0]} = result_man[MANTISSA_SIZE*2:0] << result_exponent;
        end else if (result[SIZE-2:MANTISSA_SIZE] == 0) begin
          {result[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bits[MANTISSA_SIZE-2:0]} = result_man[MANTISSA_SIZE*2:0] << zero_count;
        end else begin
          {result[MANTISSA_SIZE-1:0], guard_bit, round_bit, sticky_bits[MANTISSA_SIZE-3:0]} = result_man[MANTISSA_SIZE*2-1:0] << zero_count;
        end
      end
    end
  end

  assign sticky_bit = |sticky_bits;
  assign RNE = guard_bit & (round_bit | sticky_bit | result[0]);
  always @(*) begin
    round_result = result;
    round_cout   = 0;
    if (RNE) begin

      {round_cout, round_result[MANTISSA_SIZE-1:0]} = round_result[MANTISSA_SIZE-1:0] + 1;
      if (round_cout) begin
        round_result[SIZE-2:MANTISSA_SIZE] = round_result[SIZE-2:MANTISSA_SIZE] + 1;
      end
    end

  end

  always @(*) begin
    normalized_fp = {
      round_result[SIZE-1], round_result[SIZE-2:MANTISSA_SIZE], round_result[MANTISSA_SIZE-1:0]
    };
    if (round_result[SIZE-2:MANTISSA_SIZE] == MAX_EXPONENT & !one_is_NaN & !one_is_inf) begin
      normalized_fp = {
        round_result[SIZE-1], round_result[SIZE-2:MANTISSA_SIZE], {MANTISSA_SIZE{1'b0}}
      };
    end
  end




  assign Y = normalized_fp;

endmodule
