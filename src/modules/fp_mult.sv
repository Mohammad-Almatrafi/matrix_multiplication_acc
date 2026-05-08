
module fp_mult #(
    parameter int SIZE = 32
) (
    input  logic [SIZE-1:0] A,
    input  logic [SIZE-1:0] B,
    output logic [SIZE-1:0] Y
);


  localparam int NB_EXP = SIZE == 32 ? 8 : 0;
  localparam int NB_MAN = SIZE == 32 ? 23 : 0;
  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] BIAS = (1 << (NB_EXP - 1)) - 1, EMAX = (1 << (NB_EXP)) - 1;
  localparam logic [NB_EXP+1:0] PADDED_BIAS = (1 << (NB_EXP - 1)) - 1,
      PADDED_EMAX = (1 << (NB_EXP)) - 1;
  localparam logic [1:0] ROUND_NE = 0, ROUND_TI = 1, ROUND_TNI = 2;
  localparam int ZC_WIDTH = $clog2(NB_MAN);


  typedef struct packed {
    logic sign;
    logic [NB_EXP-1:0] exponent;
    logic [NB_MAN-1:0] mantissa;
  } floating_point_t;

  typedef struct packed {
    logic guard_bit;
    logic round_bit;
    logic sticky_bit;
  } rounding_bits_t;

  typedef struct packed {
    logic overflow;
    logic [NB_MAN:0] upper;
    logic [NB_MAN-1:0] lower;
  } mult_result_t;

  floating_point_t fp_A, fp_B, fp_result;
  rounding_bits_t init_rounding_bits;
  mult_result_t mult_result;
  logic [NB_MAN:0] mult_man;
  logic [NB_EXP+1:0] mult_exp;
  logic result_sign, mult_overflow;
  logic [NFLAGS-1:0] aflags, bflags;
  logic [NB_MAN:0] A_man, B_man;


  flags #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) aflags_inst (
      .number(fp_A),
      .output_flags(aflags)
  );

  flags #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) bflags_inst (
      .number(fp_B),
      .output_flags(bflags)
  );

  assign A_man = aflags[DENORMAL] ? {fp_A.mantissa, 1'b0} : {1'b1, fp_A.mantissa};
  assign B_man = bflags[DENORMAL] ? {fp_B.mantissa, 1'b0} : {1'b1, fp_B.mantissa};

  assign mult_result = A_man * B_man;
  assign mult_man = mult_result.upper;
  assign mult_overflow = mult_result.overflow;
  assign mult_exp = {2'b0, fp_A.exponent} + {2'b0, fp_B.exponent} - PADDED_BIAS;
  assign result_sign = fp_A.sign ^ fp_B.sign;

  assign init_rounding_bits.guard_bit = mult_result.lower[NB_MAN-1];
  assign init_rounding_bits.round_bit = mult_result.lower[NB_MAN-2];
  assign init_rounding_bits.sticky_bit = |mult_result.lower[NB_MAN-3:0];



  generate
    case (SIZE)
      16: begin : gen_16float
      end
      32: begin : gen_32float
        lzc32 lzc32_inst (
            .datain({{mult_man[NB_MAN:0], rounding_bits_t}, 5'b0}),
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

  assign Y = fp_result;

endmodule

module flags #(
    parameter int SIZE   = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    input  logic [  SIZE-1:0] number,
    output logic [NFLAGS-1:0] output_flags
);

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] EMAX = (1 << (NB_EXP)) - 1;
  logic [NB_EXP-1:0] number_exp;
  logic [NB_MAN-1:0] nubmer_man;
  logic exp_is_max, exp_is_zero, man_is_zero;

  assign number_exp = number[SIZE-2:NB_MAN];
  assign nubmer_man = number[NB_MAN-1:0];

  assign exp_is_max = number_exp == EMAX;
  assign exp_is_zero = number_exp == 0;
  assign man_is_zero = nubmer_man == 0;

  assign output_flags[NORMAL] = ~exp_is_zero & ~exp_is_max;
  assign output_flags[DENORMAL] = exp_is_zero;
  assign output_flags[INFINITY] = exp_is_max & man_is_zero;
  assign output_flags[QNAN] = exp_is_max & ~man_is_zero;

endmodule

module fp_normalize #(
    parameter int SIZE   = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    mult_result,
    mult_exp,
    mult_rounding_bits,
    overflow,
    norm_rounding_bits,
    fp_result
);

  typedef struct packed {
    logic sign;
    logic [NB_EXP-1:0] exponent;
    logic [NB_MAN-1:0] mantissa;
  } floating_point_t;

  typedef struct packed {
    logic guard_bit;
    logic round_bit;
    logic sticky_bit;
  } rounding_bits_t;

  input [NB_MAN:0] mult_result;
  input [NB_EXP+1:0] mult_exp;
  input rounding_bits_t mult_rounding_bits;
  input overflow;
  output rounding_bits_t norm_rounding_bits;
  output floating_point_t fp_result;

  logic [NB_MAN:0]mantissa_container;


  // always @* begin
  //
  //
  // end


endmodule

