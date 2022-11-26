`include "src/parameters.sv"
`include "src/commands.sv"
`include "src/cache.sv"

`define assert(signal, value) \
  if (signal !== value) begin \
    $display("ASSERTION FAILED in %m: signal != value"); \
    $finish; \
  end

module test #(parameter _SEED = 225526);
  integer SEED = _SEED;

  // Main
  reg[7:0] ram[MEM_SIZE:0];

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

  reg[ADDR1_BUS_SIZE-1:0] A1;
  reg[ADDR2_BUS_SIZE-1:0] A2;
  reg[DATA1_BUS_SIZE-1:0] D1;
  reg[DATA2_BUS_SIZE-1:0] D2;
  reg[CTR1_BUS_SIZE-1 :0] C1;
  reg[CTR2_BUS_SIZE-1 :0] C2;

  assign A1_WIRE = A1;
  assign A2_WIRE = A2;
  assign D1_WIRE = D1;
  assign D2_WIRE = D2;
  assign C1_WIRE = C1;
  assign C2_WIRE = C2;

  Cache Cache_instance(CLK, A1_WIRE, D1_WIRE, C1_WIRE, A2_WIRE, D2_WIRE, C2_WIRE, RESET, C_DUMP);

  task intialize_ram();
    for (int i = 0; i < MEM_SIZE; ++i) begin
      ram[i] = $random(SEED) >> 16;
    end
  endtask

  always @(RESET) begin
    intialize_ram();
  end

  initial begin
    intialize_ram();

//     $display("RAM:");
//     for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1) begin
//       $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
//     end
//     $display();

    // ----------------------------------------------------- Logic -----------------------------------------------------
    // $display("%0d", C2_WRITE_LINE);
    // $monitor("[%2t] CLK = %d", $time, CLK);

    #1;
    C1 = C1_INVALIDATE_LINE;
    A1 = 0;
    #2
    C1 = C1_NOP;

    // DUMP everything and finish
    // #20 C_DUMP = 1;
    // #20 M_DUMP = 1;
    #20 $finish;
  end

//   always @(posedge CLK)
//     $display("[%0t]\tCLK = %d", $time, CLK);
endmodule
