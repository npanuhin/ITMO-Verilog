module MemCTR (
  input wire CLK,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA2_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire M_DUMP
);
  `map_bus2; // Initialize wires

  reg[7:0] ram [MEM_SIZE];
  reg[CACHE_ADDR_SIZE-1:0] address;

  int accum_delay;

  bit listening_bus2 = 1;

  // Initialization & RESET
  task intialize_ram();
    // for (int i = 0; i < MEM_SIZE; ++i) ram[i] = $random(SEED) >> 16;
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
    if (listening_bus2) case (C2_WIRE)
        C2_NOP: $display("[%3t | CLK=%0d] MemCTR: C2_NOP", $time, $time % 2);

        C2_READ_LINE: begin
          $display("[%3t | CLK=%0d] MemCTR: C2_READ_LINE", $time, $time % 2);
          // TODO
        end

        C2_WRITE_LINE: begin
          $display("[%3t | CLK=%0d] MemCTR: C2_WRITE_LINE, A2 = %b", $time, $time % 2, A2_WIRE);
          address = A2_WIRE;
          accum_delay = 0;

          #(MEM_CTR_DELAY * 2 - accum_delay);

          // TODO
        end
      endcase
  end

endmodule
