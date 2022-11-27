`include "src/parameters.sv"
`include "src/commands.sv"

// BUSes
`define map_bus1 \
  reg[ADDR1_BUS_SIZE-1:0] A1 = 'z; assign A1_WIRE = A1; \
  reg[DATA1_BUS_SIZE-1:0] D1 = 'z; assign D1_WIRE = D1; \
  reg[CTR1_BUS_SIZE-1 :0] C1 = 'z; assign C1_WIRE = C1;
`define map_bus2 \
  reg[ADDR2_BUS_SIZE-1:0] A2 = 'z; assign A2_WIRE = A2; \
  reg[DATA2_BUS_SIZE-1:0] D2 = 'z; assign D2_WIRE = D2; \
  reg[CTR2_BUS_SIZE-1 :0] C2 = 'z; assign C2_WIRE = C2;

`include "src/cache.sv"
`include "src/mem.sv"

`define assert(signal, value) \
  if (signal !== value) begin \
    $display("ASSERTION FAILED in %m: signal != value"); \
    $finish; \
  end

module test;
  reg CLK = 0,
      RESET = 0,
      C_DUMP = 0,
      M_DUMP = 0;
  always #1 CLK = ~CLK;

  wire[ADDR1_BUS_SIZE-1:0] A1_WIRE;
  wire[ADDR2_BUS_SIZE-1:0] A2_WIRE;
  wire[DATA1_BUS_SIZE-1:0] D1_WIRE;
  wire[DATA2_BUS_SIZE-1:0] D2_WIRE;
  wire[CTR1_BUS_SIZE-1 :0] C1_WIRE;
  wire[CTR2_BUS_SIZE-1 :0] C2_WIRE;
  `map_bus1; `map_bus2;

  Cache Cache_instance(CLK, A1_WIRE, D1_WIRE, C1_WIRE, A2_WIRE, D2_WIRE, C2_WIRE, RESET, C_DUMP);
  MemCTR Mem_instance(CLK, A2_WIRE, D2_WIRE, C2_WIRE, RESET, M_DUMP);

  initial begin
    // ----------------------------------------------------- Logic -----------------------------------------------------
    // $monitor("[%2t] CLK = %d, C1_WIRE = %d", $time, CLK, C1_WIRE);

    #1; // CLK -> 1
    // Передача команды и первой части адреса
    C1 = C1_INVALIDATE_LINE;
    A1 = 0;
    #2
    // Передача второй части адреса
    #1
    // Завершение взаимодействия
    C1 = 'bz;

    // DUMP everything and finish
    #10;
    C_DUMP = 1;
    M_DUMP = 1;
    #1 $finish;
  end

  always @(posedge CLK) begin
    $display("\n[%2t] CLK = %d, C1_WIRE = %d", $time, CLK, C1_WIRE);
  end
endmodule
