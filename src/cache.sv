module Cache (
  input wire CLK,
  inout wire[ADDR1_BUS_SIZE-1:0] A1,
  inout wire[DATA1_BUS_SIZE-1:0] D1,
  inout wire[CTR1_BUS_SIZE-1 :0] C1,
  inout wire[ADDR2_BUS_SIZE-1:0] A2,
  inout wire[DATA2_BUS_SIZE-1:0] D2,
  inout wire[CTR2_BUS_SIZE-1 :0] C2,
  input wire RESET
);
  always @(RESET) begin

  end
endmodule
