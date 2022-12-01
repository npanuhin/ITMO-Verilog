module Cache (
  input CLK,
  inout[ADDR1_BUS_SIZE-1:0] A1_WIRE,
  inout[DATA_BUS_SIZE-1:0] D1_WIRE,
  inout[CTR1_BUS_SIZE-1 :0] C1_WIRE,
  inout[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout[DATA_BUS_SIZE-1:0] D2_WIRE,
  inout[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input RESET,
  input C_DUMP
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
  reg[7:0] write_buffer [4]; // Max is WRITE32 = 4 bytes
  int found_line;

  // Initialization & RESET
  task reset_line(int set, int line);
    LRU_bit[set][line] = 0;
    valid[set][line] = 1;  // For testing, should be 0
    dirty[set][line] = 1;  // For testing, should be 0
    tags[set][line] = 0;   // For testing, should be 'x
    for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)  // Optional
      data[set][line][bbyte] = $random(SEED) >> 16;  // For testing, should be 'x
  endtask
  task reset;
    for (int set = 0; set < CACHE_SETS_COUNT; ++set)
      for (int line = 0; line < CACHE_WAY; ++line)
        reset_line(set, line);
  endtask
  initial reset();
  always @(posedge RESET) reset();

  // Dumping
  always @(posedge C_DUMP)
    for (int set = 0; set < CACHE_SETS_COUNT; ++set) begin
      $display("Set #%0d", set);
      for (int line = 0; line < CACHE_WAY; ++line) begin
        $write("Line #%0d (%0d): ", line, set * CACHE_WAY + line);
        for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte) $write("%b ", data[set][line][bbyte]);
        $display("| TAG:%b | V:%d | D:%d", tags[set][line], valid[set][line], dirty[set][line]);
      end
      $display();
    end

  // --------------------------------------------------- Main logic ----------------------------------------------------
  // Передаём и получаем данные в little-endian, то есть вначале (слева) идёт второй байт ([15:8]), потом (справа) первый ([7:0])
  // Тогда D = (второй байт, первый байт) -> второй байт = D2[15:8], первый байт = D2[7:0]
  task send_bytes_D1(input [7:0] byte1, input [7:0] byte2);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, byte1, byte1);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, byte2, byte2);
    D1[15:8] = byte2; D1[7:0] = byte1;
  endtask
  task send_bytes_D2(input [7:0] byte1, input [7:0] byte2);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, byte1, byte1);
    $display("[%3t | CLK=%0d] Cache: Sending byte: %d = %b", $time, $time % 2, byte2, byte2);
    D2[15:8] = byte2; D2[7:0] = byte1;
  endtask
  task receive_bytes_D1(output [7:0] byte1, output [7:0] byte2);
    byte2 = D1_WIRE[15:8]; byte1 = D1_WIRE[7:0];
  endtask
  task receive_bytes_D2(output [7:0] byte1, output [7:0] byte2);
    byte2 = D2_WIRE[15:8]; byte1 = D2_WIRE[7:0];
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

  task read_line_from_MEM(input [CACHE_TAG_SIZE-1:0] tag, input [CACHE_SET_SIZE-1:0] set, input int line);  // Called on CLK = 0
    tags[req_set][found_line] = req_tag;

    C2 = C2_READ_LINE;
    A2[CACHE_TAG_SIZE+CACHE_SET_SIZE-1:CACHE_SET_SIZE] = tag;
    A2[CACHE_SET_SIZE-1:0] = set;
    #2 `close_bus2;
    wait(CLK == 1 && C2_WIRE == C2_RESPONSE);
    $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);

    for (int bytes_start = 0; bytes_start < CACHE_LINE_SIZE; bytes_start += 2) begin
      receive_bytes_D2(data[set][line][bytes_start], data[set][line][bytes_start + 1]);
      $display(
        "[%3t | CLK=%0d] Cache: Wrote byte %d = %b to data[%0d][%0d][%0d]", $time, $time % 2,
        data[set][line][bytes_start], data[set][line][bytes_start], set, line, bytes_start
      );
      $display(
        "[%3t | CLK=%0d] Cache: Wrote byte %d = %b to data[%0d][%0d][%0d]", $time, $time % 2,
        data[set][line][bytes_start + 1], data[set][line][bytes_start + 1], set, line, bytes_start + 1
      );
      if (bytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
    end
    valid[set][line] = 1;
    dirty[set][line] = 0;
  endtask

  task write_line_to_MEM(input [CACHE_SET_SIZE-1:0] set, input int line);  // Called on CLK = 0
    C2 = C2_WRITE_LINE;
    A2[CACHE_TAG_SIZE+CACHE_SET_SIZE-1:CACHE_SET_SIZE] = tags[set][line];
    A2[CACHE_SET_SIZE-1:0] = set;

    for (int bytes_start = 0; bytes_start < CACHE_LINE_SIZE; bytes_start += 2) begin
      send_bytes_D2(data[set][line][bytes_start], data[set][line][bytes_start + 1]);
      if (bytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
    end

    #1 `close_bus2;
    wait(CLK == 1 && C2_WIRE == C2_RESPONSE);
    $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);
  endtask

  task invalidate_line(input [CACHE_SET_SIZE-1:0] set, input int line);  // Called on CLK = 0
    $display("Invalidating line: set = %b, line = %0d | D: %0d", set, line, dirty[set][line]);
    // Если линия Dirty, то нужно сдампить её содержимое в Mem
    if (dirty[set][line]) write_line_to_MEM(set, line);

    // reset_line(set, line);  // Правильнее будет сделать valid[set][line] = 0, но так проще тестировать
    valid[set][line] = 0;
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

  task handle_c1_read(int read_bits);  // Called on CLK = 1
    $display("[%3t | CLK=%0d] Cache: C1_READ%0d, A1 = %b", $time, $time % 2, read_bits, A1_WIRE);
    listening_bus1 = 0; parse_A1();

    if (found_line == -1) begin
      $display("Line not found, finding spare one");
      #1 C1 = C1_NOP;
      #(CACHE_MISS_DELAY - 4);

      find_spare_line();
      #1 read_line_from_MEM(req_tag, req_set, found_line);

    end else begin
      $display("Found line #%0d", found_line);
      #1 C1 = C1_NOP;
      #(CACHE_HIT_DELAY - 5);
    end

    LRU_bit[req_set][found_line] = 1;
    LRU_bit[req_set][!found_line] = 0;

    #1 C1 = C1_RESPONSE;
    case (read_bits)
      8:  send_bytes_D1(data[req_set][found_line][req_offset], 0);
      16: send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
      32: begin
        send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
        #2 send_bytes_D1(data[req_set][found_line][req_offset + 2], data[req_set][found_line][req_offset + 3]);
      end
    endcase
    #2 `close_bus1; listening_bus1 = 1;
  endtask

  task handle_c1_write(int write_bits);  // Called on CLK = 1
    $display("[%3t | CLK=%0d] Cache: C1_WRITE%0d, A1 = %b", $time, $time % 2, write_bits, A1_WIRE);
    listening_bus1 = 0;

    // WARNING, UNTESTED, TODO

    fork
      parse_A1();
      case (write_bits)
        8:  receive_bytes_D1(write_buffer[0], write_buffer[1]);  // Second byte is just a placeholder
        16: receive_bytes_D1(write_buffer[0], write_buffer[1]);
        32: begin
          receive_bytes_D1(write_buffer[0], write_buffer[1]);
          #2 receive_bytes_D1(write_buffer[2], write_buffer[3]);
        end
      endcase
    join

    if (found_line == -1) begin
      $display("Line not found, finding spare one");
      // TODO
    end else begin
      $display("Found line #%0d", found_line);
      #1 C1 = C1_NOP;
      #(CACHE_HIT_DELAY - 5);
    end

    LRU_bit[req_set][found_line] = 1;
    LRU_bit[req_set][!found_line] = 0;

    for (int i = 0; i < 8; i += 1) begin
      data[req_set][found_line][req_offset + i] = write_buffer[i];
      $display(
        "[%3t | CLK=%0d] Cache: Wrote byte %d = %b to data[%0d][%0d][%0d]",
        $time, $time % 2, write_buffer[i], write_buffer[i], req_set, found_line, req_offset + i
      );
    end

    #1 C1 = C1_RESPONSE;
    #2 `close_bus1; listening_bus1 = 1;
  endtask

  always @(posedge CLK) begin
    if (listening_bus1) case (C1_WIRE)
      C1_NOP: $display("[%3t | CLK=%0d] Cache: C1_NOP", $time, $time % 2);

      C1_READ8:  handle_c1_read(8);
      C1_READ16: handle_c1_read(16);
      C1_READ32: handle_c1_read(32);

      C1_WRITE8:  handle_c1_write(8);
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
