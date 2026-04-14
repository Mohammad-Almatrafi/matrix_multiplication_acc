module fp_add_all #(
    parameter int SIZE   = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    input  logic [SIZE-1:0] A,
    input  logic [SIZE-1:0] B,
    output logic [SIZE-1:0] Y
);

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] BIAS = (1 << (NB_EXP - 1)) - 1, EMAX = (1 << (NB_EXP)) - 1;
  localparam int MAN_PAD_SIZE = NB_MAN * 2 + 2;
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



  logic [NB_MAN+3:0] padded_mantissa;
  logic [NB_EXP-1:0] shift_amt;
  logic [NFLAGS-1:0] aflags, bflags, op1flags, op2flags;
  floating_point_t op1, op2, normalized_fp, round_fp, output_fp;
  logic [NB_MAN+3:0] op1_man, op2_man;
  logic A_gt_B, subtract, sum_cout, sum_ovf, norm_ovf, round_ovf;
  logic [NB_MAN-1:0] sticky_bits;
  logic [NB_MAN+3:0] man_sum;
  logic [NB_MAN:0] sum_bits;
  logic [ZC_WIDTH-1:0] zero_count;
  logic all_zeros;
  rounding_bits_t round_bits, norm_round_bits;




  ////////////////////////////////////////////////
  ///////////////reoder and add///////////////////
  ////////////////////start///////////////////////
  ////////////////////////////////////////////////

  assign A_gt_B = A[SIZE-2:0] > B[SIZE-2:0];
  assign op1 = A_gt_B ? A : B;
  assign op2 = A_gt_B ? B : A;

  flags #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) aflags_inst (
      .number(A),
      .output_flags(aflags)
  );

  flags #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) bflags_inst (
      .number(B),
      .output_flags(bflags)
  );

  assign op1flags = A_gt_B ? aflags : bflags;
  assign op2flags = A_gt_B ? bflags : aflags;
  assign op1_man[NB_MAN+3:3] = op1flags[DENORMAL] ? {op1.mantissa, 1'b0} : {1'b1, op1.mantissa};
  assign op1_man[2:0] = 0;
  assign subtract = op1.sign ^ op2.sign;
  assign shift_amt = op1.exponent - op2.exponent;

  shift_and_grs #(
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) shift_and_grs_inst (
      .shift_amt(shift_amt),
      .op2flags(op2flags),
      .input_man(op2.mantissa),
      .output_mantissa(padded_mantissa)
  );

  assign op2_man = padded_mantissa ^ {(NB_MAN + 4) {subtract}};

  assign {sum_cout, man_sum} = op1_man + op2_man + subtract;
  assign sum_ovf = sum_cout ^ subtract;
  assign round_bits = man_sum[2:0];
  assign sum_bits = man_sum[NB_MAN+3:3];

  ////////////////////////////////////////////////
  ///////////////reoder and add///////////////////
  /////////////////////end////////////////////////
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////
  ////////////////normalization///////////////////
  ////////////////////start///////////////////////
  ////////////////////////////////////////////////


  generate
    case (SIZE)

      16: begin : gen_16float
      end
      32: begin : gen_32float
        lzc32 lzc32_inst (
            .datain({man_sum, 5'b0}),
            .zero_count(zero_count),
            .all_zeros(all_zeros)
        );
      end
      64: begin : gen_64float
      end
      128: begin : gen_128float
      end
    endcase

  endgenerate



  normalize_fp #(
      .SIZE(SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN),
      .ZC_WIDTH(ZC_WIDTH)
  ) normalize_fp_inst (
      .sum(sum_bits),
      .overflow(sum_ovf),
      .sig_op(op1),
      .flags1(aflags),
      .flags2(bflags),
      .zeros(zero_count),
      .all_zeros(all_zeros),
      .rounding_bits(round_bits),
      .normalized_fp(normalized_fp),
      .output_rounding_bits(norm_round_bits),
      .ovf(norm_ovf)
  );

  ////////////////////////////////////////////////
  ////////////////normalization///////////////////
  /////////////////////end////////////////////////
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////
  ///////////////////rounding/////////////////////
  ////////////////////start///////////////////////
  ////////////////////////////////////////////////

  rounding_fp #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) rounding_fp_inst (
      .fp_number(normalized_fp),
      .fp_rounding(norm_round_bits),
      .rounding_mode(0),
      .flags1(aflags),
      .flags2(bflags),
      .rounded_fp(round_fp),
      .ovf(round_ovf)
  );

  ////////////////////////////////////////////////
  ///////////////////rounding/////////////////////
  /////////////////////end////////////////////////
  ////////////////////////////////////////////////

  ////////////////////////////////////////////////
  ///////////////////rounding/////////////////////
  ////////////////////start///////////////////////
  ////////////////////////////////////////////////



  output_decider #(
      .SIZE  (SIZE),
      .NB_EXP(NB_EXP),
      .NB_MAN(NB_MAN)
  ) output_decider_inst (
      .fp_number(round_fp),
      .op1(op1),
      .op2(op2),
      .flags1(aflags),
      .flags2(bflags),
      .round_ovf(round_ovf),
      .normalize_ovf(norm_ovf),
      .output_fp(output_fp)
  );

  ////////////////////////////////////////////////
  ////////////////nomralization///////////////////
  /////////////////////end////////////////////////
  ////////////////////////////////////////////////


  assign Y = output_fp;



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

module shift_and_grs #(
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    shift_amt,
    op2flags,
    input_man,
    output_mantissa
);

  typedef struct packed {
    logic [NB_MAN:0] upper;
    logic [NB_MAN:0] lower;
  } padded_mantissa_t;

  input logic [NB_EXP-1:0] shift_amt;
  input [NFLAGS-1:0] op2flags;
  input logic [NB_MAN-1:0] input_man;
  output [NB_MAN+3:0] output_mantissa;

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;


  padded_mantissa_t padded_man;

  always @(*) begin
    padded_man.upper = op2flags[DENORMAL] ? {input_man, 1'b0} : {1'b1, input_man};
    padded_man.lower = 0;
    padded_man = padded_man >> shift_amt;
  end


  assign output_mantissa[0] = |padded_man.lower[NB_MAN-2:0];
  assign output_mantissa[2:1] = padded_man.lower[NB_MAN:NB_MAN-1];
  assign output_mantissa[NB_MAN+3:3] = padded_man.upper;

endmodule

module normalize_fp #(
    parameter int SIZE = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23,
    parameter int ZC_WIDTH = 5
) (
    sum,
    overflow,
    sig_op,
    flags1,
    flags2,
    zeros,
    all_zeros,
    rounding_bits,
    normalized_fp,
    output_rounding_bits,
    ovf
);

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] BIAS = (1 << (NB_EXP - 1)) - 1, EMAX = (1 << (NB_EXP)) - 1;

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



  input logic [NB_MAN:0] sum;
  input logic overflow;
  input floating_point_t sig_op;
  input logic [NFLAGS-1:0] flags1;
  input logic [NFLAGS-1:0] flags2;
  input logic [ZC_WIDTH-1:0] zeros;
  input logic all_zeros;
  input rounding_bits_t rounding_bits;
  output logic [SIZE-1:0] normalized_fp;
  output logic [2:0] output_rounding_bits;
  output ovf;

  floating_point_t normalize;
  rounding_bits_t norm_rounding_bits;
  logic [NB_EXP-1:0] padded_zeros;
  logic [NB_MAN+3:0] mantissa_container;

  assign padded_zeros   = {{(NB_EXP - ZC_WIDTH) {1'b0}}, zeros};
  assign normalize.sign = sig_op.sign & ~all_zeros;

  always @(*) begin : mantissa_path

    norm_rounding_bits = rounding_bits;
    normalize.mantissa = sum[NB_MAN-1:0];
    mantissa_container = {sum, rounding_bits};

    if (overflow | (flags1[DENORMAL] & flags2[DENORMAL])) begin
      normalize.mantissa = sum[NB_MAN:1];
      norm_rounding_bits.guard_bit = sum[0];
      norm_rounding_bits.round_bit = rounding_bits.guard_bit;
      norm_rounding_bits.sticky_bit = rounding_bits.round_bit | rounding_bits.sticky_bit;
    end else begin
      if (all_zeros) {normalize.mantissa, norm_rounding_bits} = 0;

      if (padded_zeros >= sig_op.exponent) begin
        mantissa_container = mantissa_container << sig_op.exponent;
        {normalize.mantissa, norm_rounding_bits} = mantissa_container[NB_MAN+3:1];
        norm_rounding_bits.sticky_bit = mantissa_container[0] | norm_rounding_bits.sticky_bit;
      end else begin
        mantissa_container = mantissa_container << zeros;
        {normalize.mantissa, norm_rounding_bits} = mantissa_container[NB_MAN+2:0];
      end

    end

  end

  always @(*) begin : exponent_path
    normalize.exponent = sig_op.exponent;
    if (overflow) normalize.exponent = normalize.exponent + 1;
    else begin
      normalize.exponent = normalize.exponent - padded_zeros;

      if (padded_zeros >= sig_op.exponent | all_zeros) begin
        normalize.exponent = 0;
      end

    end
  end

  assign normalized_fp = normalize;
  assign output_rounding_bits = norm_rounding_bits;
  assign ovf = normalize.exponent == EMAX;

endmodule

module rounding_fp #(
    parameter int SIZE   = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    fp_number,
    fp_rounding,
    rounding_mode,
    flags1,
    flags2,
    rounded_fp,
    ovf
);

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] BIAS = (1 << (NB_EXP - 1)) - 1, EMAX = (1 << (NB_EXP)) - 1;
  localparam int MAN_PAD_SIZE = NB_MAN * 2 + 2;
  localparam logic [2:0] ROUND_NE = 0, ROUND_TZ = 1, ROUND_DN = 2, ROUND_UP = 3, ROUND_MM = 4;

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

  input floating_point_t fp_number;
  input rounding_bits_t fp_rounding;
  input logic [2:0] rounding_mode;
  input logic [NFLAGS-1:0] flags1;
  input logic [NFLAGS-1:0] flags2;
  output floating_point_t rounded_fp;
  output logic ovf;

  logic RNE, RDN, RUP, shared_rnd, pre_RNE;  //,RMM;
  floating_point_t round_fp;

  assign pre_RNE = (fp_number.mantissa[0] | fp_rounding.sticky_bit | fp_rounding.round_bit);
  assign RNE = pre_RNE & fp_rounding.guard_bit;
  assign shared_rnd = (fp_rounding.sticky_bit | fp_rounding.round_bit | fp_rounding.guard_bit);
  assign RDN = fp_number.sign & shared_rnd;
  assign RUP = ~fp_number.sign & shared_rnd;

  always @(*) begin
    round_fp = fp_number;

    if (RNE & rounding_mode == ROUND_NE) begin
      round_fp[SIZE-2:0] = round_fp[SIZE-2:0] + 1;
      round_fp.sign = fp_number.sign;
    end

    if (RDN & rounding_mode == ROUND_DN) begin
      round_fp[SIZE-2:0] = round_fp[SIZE-2:0] + 1;
      round_fp.sign = fp_number.sign;
    end

    if (RUP & rounding_mode == ROUND_UP) begin
      round_fp[SIZE-2:0] = round_fp[SIZE-2:0] + 1;
      round_fp.sign = fp_number.sign;
    end

  end

  assign rounded_fp = round_fp;

endmodule

module output_decider #(
    parameter int SIZE   = 32,
    parameter int NB_EXP = 8,
    parameter int NB_MAN = 23
) (
    fp_number,
    op1,
    op2,
    flags1,
    flags2,
    round_ovf,
    normalize_ovf,
    output_fp
);

  localparam int NORMAL = 0, DENORMAL = 1, INFINITY = 2, QNAN = 3;
  localparam int NFLAGS = QNAN + 1;
  localparam logic [NB_EXP-1:0] BIAS = (1 << (NB_EXP - 1)) - 1, EMAX = (1 << (NB_EXP)) - 1;
  localparam int MAN_PAD_SIZE = NB_MAN * 2 + 2;
  localparam logic [1:0] ROUND_NE = 0, ROUND_TI = 1, ROUND_TNI = 2;


  typedef struct packed {
    logic sign;
    logic [NB_EXP-1:0] exponent;
    logic [NB_MAN-1:0] mantissa;
  } floating_point_t;

  input floating_point_t fp_number;
  input floating_point_t op1;
  input floating_point_t op2;
  input [NFLAGS-1:0] flags1;
  input [NFLAGS-1:0] flags2;
  input logic round_ovf;
  input logic normalize_ovf;

  output floating_point_t output_fp;

  logic [NB_MAN-1:0] intermediate_mantissa;
  logic emax_condition, qnan_condition, one_is_nan;
  logic overflow;

  assign one_is_nan = flags1[QNAN] | flags2[QNAN];

  assign overflow = round_ovf | normalize_ovf;

  assign emax_condition = one_is_nan | flags1[INFINITY] | flags2[INFINITY] | overflow;

  assign output_fp.sign = fp_number.sign;

  assign qnan_condition = (op1.sign ^ op2.sign) | one_is_nan;

  assign intermediate_mantissa[NB_MAN-2:0] = 0;

  assign intermediate_mantissa[NB_MAN-1] = qnan_condition ? 1 : 0;

  assign output_fp.exponent = emax_condition ? EMAX : fp_number.exponent;

  assign output_fp.mantissa = emax_condition ? intermediate_mantissa : fp_number.mantissa;

endmodule

