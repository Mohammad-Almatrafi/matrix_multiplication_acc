module lzc2 (
    input logic [1:0] datain,
    output logic zero_count,
    output logic all_zeros
);
  assign zero_count = ~datain[1];
  assign all_zeros  = ~(|datain);

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


module lzc32 (
    input logic [31:0] datain,
    output logic [4:0] zero_count,
    output logic all_zeros
);

  logic [3:0] temp_zero_count[0:1];
  logic group_sel;
  logic [1:0] temp_all_zeros;

  genvar i;
  generate
    for (i = 0; i < 2; i++) begin : gen_lzc4
      lzc16 lzc_inst (
          .datain(datain[31-(16*i):31-(16*i)-15]),
          .zero_count(temp_zero_count[i]),
          .all_zeros(temp_all_zeros[1-i])
      );
    end
  endgenerate

  lzc2 lzc_inst (
      .datain(~temp_all_zeros),
      .zero_count(group_sel),
      .all_zeros(all_zeros)
  );
  assign zero_count[4]   = group_sel;
  assign zero_count[3:0] = temp_zero_count[group_sel];

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
