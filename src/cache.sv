module Cache (
  input wire CLK,
  inout wire[ADDR1_BUS_SIZE-1:0] A1_WIRE,
  inout wire[DATA_BUS_SIZE-1:0] D1_WIRE,
  inout wire[CTR1_BUS_SIZE-1 :0] C1_WIRE,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire C_DUMP
);
  `map_bus1; `map_bus2;  // Initialize wires

  // Cache system
  reg[7:0] data [CACHE_SETS_COUNT] [CACHE_WAY] [CACHE_LINE_SIZE];
  reg[7:0] tags [CACHE_SETS_COUNT] [CACHE_WAY];
  bit LRU_bit [CACHE_SETS_COUNT] [CACHE_WAY],
      valid   [CACHE_SETS_COUNT] [CACHE_WAY],
      dirty   [CACHE_SETS_COUNT] [CACHE_WAY];

  // For storing A1 parts
  reg[CACHE_TAG_SIZE-1:0] req_tag;
  reg[CACHE_SET_SIZE-1:0] req_set;
  reg[CACHE_OFFSET_SIZE-1:0] req_offset;

  // Internal variables
  bit listening_bus1 = 1;
  int found_line;

  // Initialization & RESET
  task reset_line(int cur_set, int cur_line);
    LRU_bit[cur_set][cur_line] = 0;
    valid[cur_set][cur_line] = 1;  // For testing, should be 0
    dirty[cur_set][cur_line] = 1;  // For testing, should be 0
    tags[cur_set][cur_line] = 0;   // For testing, should be 'x
    for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)  // Optional
      data[cur_set][cur_line][bbyte] = $random(SEED) >> 16;  // For testing, should be 'x
  endtask
  task reset;
    for (int cur_set = 0; cur_set < CACHE_SETS_COUNT; ++cur_set)
      for (int cur_line = 0; cur_line < CACHE_WAY; ++cur_line)
        reset_line(cur_set, cur_line);
  endtask
  initial reset();
  always @(posedge RESET) reset();

  // Dumping
  always @(posedge C_DUMP)
    for (int cur_set = 0; cur_set < CACHE_SETS_COUNT; ++cur_set) begin
      $display("Set #%0d", cur_set);
      for (int found_line = 0; found_line < CACHE_WAY; ++found_line) begin
        $write("Line #%0d (%0d): ", found_line, cur_set * CACHE_WAY + found_line);
        for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)
          $write("%b ", data[cur_set][found_line][bbyte]);
        $display("| TAG:%b | V:%d | D:%d", tags[cur_set][found_line], valid[cur_set][found_line], dirty[cur_set][found_line]);
      end
      $display();
    end

  // --------------------------------------------------- Main logic ----------------------------------------------------
  // Передаём и получаем данные в little-endian, то есть вначале (слева) идёт второй байт ([15:8]), потом (справа) первый ([7:0])
  // Тогда D = (второй байт, первый байт) -> второй байт = D2[15:8], первый байт = D2[7:0]
  task send_bytes_D1(input [7:0] bbyte1, input [7:0] bbyte2);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, bbyte1, bbyte1);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, bbyte2, bbyte2);
    D1[15:8] = bbyte2; D1[7:0] = bbyte1;
  endtask
  task send_bytes_D2(input [7:0] bbyte1, input [7:0] bbyte2);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, bbyte1, bbyte1);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, bbyte2, bbyte2);
    D2[15:8] = bbyte2; D2[7:0] = bbyte1;
  endtask
  task receive_bytes_D1(output [7:0] bbyte1, output [7:0] bbyte2);
    bbyte2 = D1_WIRE[15:8]; bbyte1 = D1_WIRE[7:0];
  endtask
  task receive_bytes_D2(output [7:0] bbyte1, output [7:0] bbyte2);
    bbyte2 = D2_WIRE[15:8]; bbyte1 = D2_WIRE[7:0];
  endtask

  task redirect_address;
    A2[CACHE_TAG_SIZE+CACHE_SET_SIZE-1:CACHE_SET_SIZE] = req_tag;
    A2[CACHE_SET_SIZE-1:0] = req_set;
  endtask

  // Parses A1 bus to A1 parts + finds valid line corresponding to these parts
  task parse_A1;  // Called on CLK = 1
    req_tag = `discard_last_n_bits(A1_WIRE, CACHE_SET_SIZE);
    req_set = `last_n_bits(A1_WIRE, CACHE_SET_SIZE);
    #2 req_offset = A1_WIRE;
    $display("[%3t | CLK=%0d] tag = %b, set = %b, offset = %b", $time, $time % 2, req_tag, req_set, req_offset);

    found_line = -1;
    for (int test_line = 0; test_line < CACHE_WAY; ++test_line)
      if (valid[req_set][test_line] == 1 && tags[req_set][test_line] == req_tag) found_line = test_line;
  endtask

  task invalidate_line(input [CACHE_SET_SIZE-1:0] set, input int line);  // Called on CLK = 0
    $display("Invalidating line: set = %b, line = %0d | D: %0d", set, line, dirty[set][line]);
    // Если линия Dirty, то нужно сдампить её содержимое в Mem
    if (dirty[set][line]) begin
      C2 = C2_WRITE_LINE;
      A2[CACHE_TAG_SIZE+CACHE_SET_SIZE-1:CACHE_SET_SIZE] = tags[set][line];
      A2[CACHE_SET_SIZE-1:0] = set;

      for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += 2) begin
        send_bytes_D2(data[set][line][bbytes_start], data[set][line][bbytes_start + 1]);
        if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
      end

      #1 `close_bus2;
      wait(CLK == 1 && C2_WIRE == C2_RESPONSE);
      $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);

      reset_line(set, line);  // В конце очистить линию
    end
  endtask

  task find_spare_line;  // Called on CLK = 0
    // Сначала ищем не занятую
    for (int test_line = 0; test_line < CACHE_WAY; ++test_line)
      if (valid[req_set][test_line] == 0) found_line = test_line;

    // Если таковой не нашлось, то по LRU берём самую давнюю (LRU_bit = 0) и инвалидируем
    if (found_line == -1) begin
      for (int test_line = 0; test_line < CACHE_WAY; ++test_line)
        if (LRU_bit[req_set][test_line] == 0) found_line = test_line;

      invalidate_line(req_set, found_line);
    end
  endtask

  task handle_c1_read(int read_bits);   // Called on CLK = 1
    $display("[%3t | CLK=%0d] Cache: C1_READ%0d, A1 = %b", $time, $time % 2, read_bits, A1_WIRE);
    listening_bus1 = 0; parse_A1();

    if (found_line == -1) begin
      $display("Line not found, finding spare one");
      // Надо найти свободную линию, пойти в Mem, прочитать строчку и сохранить её
      #1 C1 = C1_NOP;
      #(CACHE_MISS_DELAY - 4);

      find_spare_line();
      tags[req_set][found_line] = req_tag;

      #1 C2 = C2_READ_LINE; redirect_address();
      #2 `close_bus2;
      wait(CLK == 1 && C2_WIRE == C2_RESPONSE);
      $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);

      for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += 2) begin
        receive_bytes_D2(data[req_set][found_line][bbytes_start], data[req_set][found_line][bbytes_start + 1]);
        $display(
          "[%3t | CLK=%0d] Cache: Wrote byte %d = %b to data[%0d][%0d][%0d]", $time, $time % 2,
          data[req_set][found_line][bbytes_start], data[req_set][found_line][bbytes_start], req_set, found_line, bbytes_start
        );
        $display(
          "[%3t | CLK=%0d] Cache: Wrote byte %d = %b to data[%0d][%0d][%0d]", $time, $time % 2,
          data[req_set][found_line][bbytes_start + 1], data[req_set][found_line][bbytes_start + 1], req_set, found_line, bbytes_start + 1
        );
        if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
      end
    end else begin
      $display("Found line #%0d", found_line);
      #1 C1 = C1_NOP;
      #(CACHE_HIT_DELAY - 5);
    end

    LRU_bit[req_set][found_line] = 1;
    LRU_bit[req_set][!found_line] = 0;

    #1 C1 = C1_RESPONSE;
    case (read_bits)
      8: send_bytes_D1(data[req_set][found_line][req_offset], 0);
      16: send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
      32: begin
        send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
        #2 send_bytes_D1(data[req_set][found_line][req_offset + 2], data[req_set][found_line][req_offset + 3]);
      end
    endcase
    #2 `close_bus1; listening_bus1 = 1;
  endtask

  task handle_c1_write(int write_bits);   // Called on CLK = 1
    $display("[%3t | CLK=%0d] Cache: C1_WRITE%0d, A1 = %b", $time, $time % 2, write_bits, A1_WIRE);
    listening_bus1 = 0; parse_A1();
    // TODO
  endtask

  always @(posedge CLK) begin
    if (listening_bus1) case (C1_WIRE)
      C1_NOP: $display("[%3t | CLK=%0d] Cache: C1_NOP", $time, $time % 2);

      C1_READ8: handle_c1_read(8);
      C1_READ16: handle_c1_read(16);
      C1_READ32: handle_c1_read(32);

      C1_WRITE8: handle_c1_write(8);
      C1_WRITE16: handle_c1_write(16);
      C1_WRITE32: handle_c1_write(32);

      C1_INVALIDATE_LINE: begin
        $display("[%3t | CLK=%0d] Cache: C1_INVALIDATE_LINE, A1 = %b", $time, $time % 2, A1_WIRE);
        listening_bus1 = 0; parse_A1();
        #1 C1 = C1_NOP;

        if (found_line == -1) begin
          $display("Line not found");
          #(CACHE_HIT_DELAY - 5);  // Для реалистичности поставим задежку между C1_INVALIDATE_LINE и отправкой данных/C1_RESPONSE равную CACHE_HIT_DELAY тактов
        end else begin
          $display("Found line #%0d", found_line);
          invalidate_line(req_set, found_line);
        end

        #1 C1 = C1_RESPONSE;
        $display("[%3t | CLK=%0d] Cache: Sending C1_RESPONSE", $time, $time % 2);
        #2 `close_bus1; listening_bus1 = 1;
      end
    endcase
  end
endmodule
