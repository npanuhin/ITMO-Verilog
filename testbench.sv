`define reg_to_string(signal, value) \
  if (signal !== value) begin \
    $display("ASSERTION FAILED in %m: signal != value"); \
    $finish; \
  end

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
  integer memory_pointer = 0;

  reg CLK = 0,
      RESET = 0,
      C_DUMP = 0;
  always #1 CLK = ~CLK;

  wire[ADDR1_BUS_SIZE-1:0] A1;
  wire[ADDR2_BUS_SIZE-1:0] A2;
  wire[DATA1_BUS_SIZE-1:0] D1;
  wire[DATA2_BUS_SIZE-1:0] D2;
  wire[CTR1_BUS_SIZE-1 :0] C1;
  wire[CTR2_BUS_SIZE-1 :0] C2;

  Cache Cache_instance(CLK, A1, D1, C1, A2, D2, C2, RESET, C_DUMP);

  initial begin
    // Memory initialization
    for (memory_pointer = 0; memory_pointer < MEM_SIZE; memory_pointer += 1) begin
      ram[memory_pointer] = $random(SEED) >> 16;
    end

//     $display("RAM:");
//     for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1) begin
//       $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
//     end
//     $display();

    // Logic
    // $display("%0d", C2_WRITE_LINE);
    #10 C_DUMP = 1;
    // $monitor("[%2t] CLK = %d", $time, CLK);
    #20 $finish;
  end

//   always @(posedge CLK)
//     $display("[%0t]\tCLK = %d", $time, CLK);
endmodule
