`include "cache.sv"

`define assert(signal, value) \
  if (signal !== value) begin \
    $display("ASSERTION FAILED in %m: signal != value"); \
    $finish; \
  end

module test #(parameter _SEED = 225526);
  integer SEED = _SEED;

  // Given parameters
  localparam MEM_SIZE = 512 * 1024;
  localparam CACHE_WAY = 2;  // TODO
  localparam CACHE_TAG_SIZE = 10;
  localparam CACHE_LINE_SIZE = 16;
  localparam CACHE_LINE_COUNT = 64;
  // Calculated parameters
  localparam CACHE_SIZE = -1;
  localparam CACHE_SETS_COUNT = -1;
  localparam CACHE_SET_SIZE = -1;
  localparam CACHE_OFFSET_SIZE = -1;
  localparam CACHE_ADDR_SIZE = -1;

  // Commands defenition
  typedef enum {
    C1_NOP,
    C1_READ8,
    C1_READ16,
    C1_READ32,
    C1_INVALIDATE_LINE,
    C1_WRITE8,
    C1_WRITE16,
    C1_WRITE32,
    C1_RESPONSE
  } C1_COMMANDS;
  // Commands
  typedef enum {
    C2_NOP,
    C2_READ_LINE,
    C2_WRITE_LINE,
    C2_RESPONSE
  } C2_COMMANDS;

  // Main
  reg[7:0] ram[0:MEM_SIZE];
  integer memory_pointer = 0;

  reg CLK;
  reg RESET;
  always #1 CLK = ~CLK;

  wire A1, D1, C1, A2, D2, C2;

  Cache #(3) Cache_instance(CLK, A1, D1, C1, A2, D2, C2, RESET);

  initial begin
    // Memory initialization
    for (memory_pointer = 0; memory_pointer < MEM_SIZE; memory_pointer += 1) begin
      ram[memory_pointer] = $random(SEED)>>16;
    end

//     $display("RAM:");
//     for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1) begin
//       $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
//     end
//     $display();

    // Logic
    CLK = 0;
    RESET = 0;
    $monitor("[%2t] CLK = %d", $time, CLK);
    #20 $finish;
  end

//   always @(posedge CLK)
//     $display("[%0t]\tCLK = %d", $time, CLK);
endmodule
