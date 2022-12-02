`include "src/common.sv"
`include "src/parameters.sv"
`include "src/commands.sv"
`include "src/statistics.sv"

`include "src/cache.sv"
`include "src/mem.sv"

// `define assert(signal, value) \
//   if (signal !== value) begin \
//     $display("ASSERTION FAILED in %m: signal != value"); \
//     $finish; \
//   end

module cache_test;
  reg CLK = 0,
      RESET = 0,
      C_DUMP = 0,
      M_DUMP = 0;
  always #1 CLK = ~CLK;

  wire[ADDR1_BUS_SIZE-1:0] A1_WIRE;
  wire[ADDR2_BUS_SIZE-1:0] A2_WIRE;
  wire[DATA_BUS_SIZE-1:0] D1_WIRE;
  wire[DATA_BUS_SIZE-1:0] D2_WIRE;
  wire[CTR1_BUS_SIZE-1:0] C1_WIRE;
  wire[CTR2_BUS_SIZE-1:0] C2_WIRE;
  `map_bus1;  // Initialize wires

  Cache Cache_instance(CLK, A1_WIRE, D1_WIRE, C1_WIRE, A2_WIRE, D2_WIRE, C2_WIRE, RESET, C_DUMP);
  MemCTR Mem_instance(CLK, A2_WIRE, D2_WIRE, C2_WIRE, RESET, M_DUMP);

  task wait_response;
    #2 `close_bus1;
    wait(CLK == 1 && C1_WIRE == C1_RESPONSE);
  endtask

  // For testing
  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_SET_SIZE-1:0] set;
  reg[CACHE_OFFSET_SIZE-1:0] offset;
  reg[CACHE_ADDR_SIZE-1:0] address;
  task send_bytes_D1(input [7:0] byte1, input [7:0] byte2);
    `log $display("CPU: Sending byte: %d = %b", byte1, byte1);
    `log $display("CPU: Sending byte: %d = %b", byte2, byte2);
    D1[15:8] = byte2; D1[7:0] = byte1;
  endtask
  task receive_bytes_D1;
    `log $display("CPU: Received byte: %d = %b", D1_WIRE[7:0], D1_WIRE[7:0]);
    `log $display("CPU: Received byte: %d = %b", D1_WIRE[15:8], D1_WIRE[15:8]);
  endtask

  // initial begin
    // $dumpfile("dump.vcd"); $dumpvars;
    // -------------------------------------------- Test C1_INVALIDATE_LINE --------------------------------------------
    // tag = 1;  // 0 — found, 1 — not found
    // set = 2;
    // offset = 3;
    // address = tag;
    // address = (((address << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE) + offset;
    // $display("Testbench: sending C1_INVALIDATE_LINE, A1 = %b|%b|%b\n", tag, set, offset);

    // // Передача команды и первой части адреса
    // `log $display("<Sending C1 and first half of A1>");
    // C1 = C1_INVALIDATE_LINE;
    // A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    // #2;
    // // Передача второй части адреса
    // `log $display("<Sending second half of A1>");
    // A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    // // Завершение взаимодействия
    // wait_response();
    // `log $display("CPU received C1_RESPONSE");

    // ---------------------------------------------- Test C1_READ8/16/32 ----------------------------------------------
    // tag = 1;
    // set = 2;
    // offset = 3;
    // address = tag;
    // address = (((address << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE) + offset;
    // $display("Testbench: sending C1_READ32, A1 = %b|%b|%b\n", tag, set, offset);

    // // Прочитаем один и те же данные два раза - во второй раз не должно быть похода в память
    // for (int iteration = 0; iteration < 2; ++iteration) begin
    //   // Передача команды и первой части адреса
    //   `log $display("<Sending C1 and first half of A1>");
    //   C1 = C1_READ32;
    //   A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    //   #2
    //   // Передача второй части адреса
    //   `log $display("<Sending second half of A1>");
    //   A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    //   // Завершение взаимодействия
    //   wait_response();
    //   `log $display("CPU received C1_RESPONSE");

    //   for (int bbytes_start = 0; bbytes_start < 32 / 8; bbytes_start += 2) begin
    //     receive_bytes_D1();
    //     if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
    //   end
    //   $display("\n---------- Iteration %0d finished ----------\n", iteration);
    //   #3;
    // end

    // ---------------------------------------------- Test C1_WRITE8/16/32 ----------------------------------------------
    // tag = 1;
    // set = 2;
    // offset = 3;
    // address = tag;
    // address = (((address << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE) + offset;
    // $display("Testbench: sending C1_WRITE32, A1 = %b|%b|%b\n", tag, set, offset);

    // // Прочитаем один и те же данные два раза - во второй раз не должно быть похода в память
    // for (int iteration = 0; iteration < 2; ++iteration) begin
    //   // Передача команды, первой части адреса и первой части данных
    //   `log $display("<Sending C1 and first half of A1>");
    //   C1 = C1_WRITE32;
    //   A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    //   D1[15:8] = 200; D1[7:0] = 124;
    //   #2
    //   // Передача второй части адреса и второй части данных
    //   `log $display("<Sending second half of A1>");
    //   A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    //   D1[15:8] = 37; D1[7:0] = 5;
    //   // Завершение взаимодействия
    //   wait_response();
    //   `log $display("CPU received C1_RESPONSE");

    //   $display("\n---------- Iteration %0d finished ----------\n", iteration);
    //   #3;
    // end

    // -----------------------------------------------------------------------------------------------------------------
    // DUMP everything and finish
    // #3;
    // C_DUMP = 1;
    // M_DUMP = 1;
    // #3 $finish;
  // end

  // --------------------------------------------------- Actual task ---------------------------------------------------
  // ---------- READ8/16/32 ----------
  task common_read(input int address, input int command);
    // `log $display("CPU sending READ command");
    C1 = command;
    A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    #2 A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    wait_response();
  endtask
  task read8(input int address, output [7:0] result);
    common_read(address, C1_READ8);
    result = D1;  // byte 1
    #1; // Wait for CLK -> 0
  endtask
  task read16(input int address, output [15:0] result);
    common_read(address, C1_READ16);
    result[15:8] = D1[7:0];  // byte 1
    result[7:0] = D1[15:8];  // byte 2
    #1; // Wait for CLK -> 0
  endtask
  task read32(input int address, output [31:0] result);
    common_read(address, C1_READ32);
    result[31:24] = D1[7:0];   // byte 1
    result[23:16] = D1[15:8];  // byte 2
    #2;
    result[15:8] = D1[7:0];  // byte 3
    result[7:0] = D1[15:8];  // byte 4
    #1; // Wait for CLK -> 0
  endtask
  // ---------- WRITE8/16/32 ----------
  task common_write(input int address, input int command);
    // `log $display("CPU sending WRITE command");
    C1 = command;
    A1 = `discard_last_n_bits(address, CACHE_OFFSET_SIZE);
    #2 A1 = `last_n_bits(address, CACHE_OFFSET_SIZE);
    wait_response();
    #1; // Wait for CLK -> 0
  endtask
  task write8(input int address, input [7:0] data);
    fork
      common_write(address, C1_WRITE8);
      D1 = data;  // byte 1
    join
  endtask
  task write16(input int address, input [15:0] data);
    fork
      common_write(address, C1_WRITE16);
      begin
        D1[7:0] = data[15:8];  // byte 1
        D1[15:8] = data[7:0];  // byte 2
      end
    join
  endtask
  task write32(input int address, input [31:0] data);
    fork
      common_write(address, C1_WRITE32);
      begin
        D1[7:0] = data[31:24];   // byte 1
        D1[15:8] = data[23:16];  // byte 2
        #2;
        D1[7:0] = data[15:8];  // byte 3
        D1[15:8] = data[7:0];  // byte 4
      end
    join
  endtask

  localparam M = 64;
  localparam N = 60;
  localparam K = 32;

  // reg[7:0]  a[M][K];  // int8  a[M][K]; — 1 byte
  // reg[15:0] b[K][N];  // int16 b[K][N]; — 2 bytes
  // reg[31:0] c[M][N];  // int32 b[K][N]; — 4 bytes
  int pa, pb, pc, s, tmp_mul, tmp_pa_k, tmp_pb_x;
  int a = 0,
      b = M * K,
      c = pb + 2 * K * N;

  initial begin
    #2 pa = a;                                // int8 *pa = a;
    #2 pc = c;                                // int32 *pc = c;
    for (int y = 0; y < M; ++y) begin         // for (int y = 0; y < M; y++) {
      for (int x = 0; x < N; ++x) begin       //   for (int x = 0; x < N; x++) {
        #2 pb = b;                            //     int16 *pb = b;
        #2 s = 0;                             //     int32 s = 0;
        for (int k = 0; k < K; ++k) begin     //     for (int k = 0; k < K; k++) {
          read8(pa + k, tmp_pa_k);
          read16(pb + 2 * x, tmp_pb_x);
          #12 s += tmp_pa_k * tmp_pb_x;       //       s += pa[k] * pb[x];
          #2 pb += 2 * N;                     //       pb += N;
        #2; end                               //     }
        write32(pc + 4 * x, s);               //     pc[x] = s;
      #2; end                                 //   }
      #2 pa += K;                             //   pa += K;
      #2 pc += 4 * N;                         //   pc += N;
    #2; end                                   // }

    #2; // Выход из функции
    $display("Total time: %0d tacts", $time / 2);
    $display("Cache hits: %0d/%0d = %0.2t%%", cache_hits, cache_hits + cache_misses, real'(cache_hits) * 100 / (cache_hits + cache_misses));
    $finish;

    // $display();
    // #10 C_DUMP = 1;
    // #10 M_DUMP = 1;
    // #10 $finish;
  end

  // initial #1000 $finish;

  always @(CLK) begin
    `log $display("C1_WIRE = %d, C2_WIRE = %d", C1_WIRE, C2_WIRE);
  end
endmodule
