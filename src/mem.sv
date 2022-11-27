module MemCTR (
  input wire CLK,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA2_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire M_DUMP
);
  `map_bus2; // Initialize wires

  reg[7:0] ram[MEM_SIZE:0];
  bit working = 0;

  // Initialization & RESET
  task intialize_ram();
    for (int i = 0; i < MEM_SIZE; ++i) begin
      ram[i] = $random(SEED) >> 16;
    end
  endtask
  always @(RESET) intialize_ram();
  initial begin
    intialize_ram();
    // $display("RAM:");
    // for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1) begin
    //   $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
    // end
    // $display();
  end

  // Main logic
  always @(posedge CLK) begin
    if (!working) begin

    end
  end

endmodule
