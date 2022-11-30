`include "src/parameters.sv"
`include "src/commands.sv"

// Tools
`define discard_last_n_bits(register, n) (register >> n)
`define first_n_bits(register, n) `discard_last_n_bits(register, $size(register) - n)
`define last_n_bits(register, n) (register & ((1 << n) - 1))

// BUSes
`define map_bus1 \
  reg[ADDR1_BUS_SIZE-1:0] A1 = 'z; assign A1_WIRE = A1; \
  reg[DATA_BUS_SIZE-1:0] D1 = 'z; assign D1_WIRE = D1; \
  reg[CTR1_BUS_SIZE-1 :0] C1 = 'z; assign C1_WIRE = C1;
`define map_bus2 \
  reg[ADDR2_BUS_SIZE-1:0] A2 = 'z; assign A2_WIRE = A2; \
  reg[DATA_BUS_SIZE-1:0] D2 = 'z; assign D2_WIRE = D2; \
  reg[CTR2_BUS_SIZE-1 :0] C2 = 'z; assign C2_WIRE = C2;
`define close_bus1 C1 = 'z; A1 = 'z; D1 = 'z;
`define close_bus2 C2 = 'z; A2 = 'z; D2 = 'z;

`include "src/cache.sv"
`include "src/mem.sv"

// `define assert(signal, value) \
//   if (signal !== value) begin \
//     $display("ASSERTION FAILED in %m: signal != value"); \
//     $finish; \
//   end

module test;
  reg CLK = 0,
      RESET = 0,
      C_DUMP = 0,
      M_DUMP = 0;
  always #1 CLK = ~CLK;

  wire[ADDR1_BUS_SIZE-1:0] A1_WIRE;
  wire[ADDR2_BUS_SIZE-1:0] A2_WIRE;
  wire[DATA_BUS_SIZE-1:0] D1_WIRE;
  wire[DATA_BUS_SIZE-1:0] D2_WIRE;
  wire[CTR1_BUS_SIZE-1 :0] C1_WIRE;
  wire[CTR2_BUS_SIZE-1 :0] C2_WIRE;
  `map_bus1; `map_bus2;

  Cache Cache_instance(CLK, A1_WIRE, D1_WIRE, C1_WIRE, A2_WIRE, D2_WIRE, C2_WIRE, RESET, C_DUMP);
  MemCTR Mem_instance(CLK, A2_WIRE, D2_WIRE, C2_WIRE, RESET, M_DUMP);

  // For testing
  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_SET_SIZE-1:0] set;
  reg[CACHE_OFFSET_SIZE-1:0] offset;
  reg[CACHE_ADDR_SIZE-1:0] address;

  task send_bytes_D1(input [7:0] bbyte1, input [7:0] bbyte2);
    $display("[%3t | CLK=%0d] CPU: Sending byte: %d = %b", $time, $time % 2, bbyte1, bbyte1);
    $display("[%3t | CLK=%0d] CPU: Sending byte: %d = %b", $time, $time % 2, bbyte2, bbyte2);
    D1[15:8] = bbyte2; D1[7:0] = bbyte1;
  endtask
  task receive_bytes_D1;
    $display("[%3t | CLK=%0d] CPU: Received byte: %d = %b", $time, $time % 2, D1_WIRE[7:0], D1_WIRE[7:0]);
    $display("[%3t | CLK=%0d] CPU: Received byte: %d = %b", $time, $time % 2, D1_WIRE[15:8], D1_WIRE[15:8]);
  endtask

  initial begin
    // $dumpfile("dump.vcd"); $dumpvars;
    // -------------------------------------------- Test C1_INVALIDATE_LINE --------------------------------------------
    // tag = 0;
    // set = 2;
    // offset = 3;
    // address = tag;
    // address = (((address << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE) + offset;
    // $display("Testbench: sending C1_INVALIDATE_LINE, A1 = %b|%b|%b\n", tag, set, offset);

    // #1;  // CLK -> 1
    // // Передача команды и первой части адреса
    // $display("[%3t | CLK=%0d] <Sending C1 and first half of A1>", $time, $time % 2);
    // C1 = C1_INVALIDATE_LINE;
    // A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    // #2
    // // Передача второй части адреса
    // $display("[%3t | CLK=%0d] <Sending second half of A1>", $time, $time % 2);
    // A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    // #1
    // // Завершение взаимодействия
    // $display("[%3t | CLK=%0d] <Finished sending>", $time, $time % 2);
    // `close_bus1;

    // wait(C1_WIRE == C1_RESPONSE);
    // $display("[%3t | CLK=%0d] CPU received C1_RESPONSE", $time, $time % 2);

    // ---------------------------------------------- Test C1_READ8/16/32 ----------------------------------------------
    tag = 0;
    set = 2;
    offset = 3;
    address = tag;
    address = (((address << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE) + offset;
    $display("Testbench: sending C1_READ32, A1 = %b|%b|%b\n", tag, set, offset);

    #1;  // CLK -> 1
    // Прочитаем один и те же данные два раза - во второй раз не должно быть похода в память
    for (int iteration = 0; iteration < 2; ++iteration) begin
      // Передача команды и первой части адреса
      $display("[%3t | CLK=%0d] <Sending C1 and first half of A1>", $time, $time % 2);
      C1 = C1_READ32;
      A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
      #2
      // Передача второй части адреса
      $display("[%3t | CLK=%0d] <Sending second half of A1>", $time, $time % 2);
      A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
      #1
      // Завершение взаимодействия
      $display("[%3t | CLK=%0d] <Finished sending>", $time, $time % 2);
      `close_bus1;

      wait(C1_WIRE == C1_RESPONSE);
      $display("[%3t | CLK=%0d] CPU received C1_RESPONSE", $time, $time % 2);

      for (int bbytes_start = 0; bbytes_start < 32 / 8; bbytes_start += 2) begin
        receive_bytes_D1();
        if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
      end
      $display("\n---------- Iteration %0d finished ----------\n", iteration);
      #2;
    end

    // -----------------------------------------------------------------------------------------------------------------
    // DUMP everything and finish
    // #3;
    // C_DUMP = 1;
    // M_DUMP = 1;
    #10 $finish;
  end

  always @(CLK)
    $display("[%3t | CLK=%0d] C1_WIRE = %d, C2_WIRE = %d", $time, $time % 2, C1_WIRE, C2_WIRE);
endmodule
