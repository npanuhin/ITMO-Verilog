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

  // Internal cache variables
  reg[7:0] data [CACHE_SETS_COUNT] [CACHE_WAY] [CACHE_LINE_SIZE];
  reg[7:0] tags [CACHE_SETS_COUNT] [CACHE_WAY];
  bit LRU_bit [CACHE_SETS_COUNT] [CACHE_WAY],
      valid   [CACHE_SETS_COUNT] [CACHE_WAY],
      dirty   [CACHE_SETS_COUNT] [CACHE_WAY];

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

  reg[CACHE_TAG_SIZE-1:0] req_tag;
  reg[CACHE_SET_SIZE-1:0] req_set;
  reg[CACHE_OFFSET_SIZE-1:0] req_offset;
  // reg[CACHE_TAG_SIZE + CACHE_SET_SIZE - 1:0] mem_address;
  // reg[DATA_BUS_SIZE-1:0] bus2_data;

  bit listening_bus1 = 1;

  int found_line;

  // Initialization & RESET
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
  // Передать данные в little-endian, то есть вначале (слева) идёт второй байт ([15:8]), потом (справа) первый ([7:0])
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

  task parse_A1;  // duration: 2 tacts
    req_tag = `discard_last_n_bits(A1_WIRE, CACHE_SET_SIZE);
    req_set = `last_n_bits(A1_WIRE, CACHE_SET_SIZE);
    #2 req_offset = A1_WIRE;
    $display("[%3t | CLK=%0d] tag = %b, set = %b, offset = %b", $time, $time % 2, req_tag, req_set, req_offset);

    found_line = -1;
    for (int test_line = 0; test_line < CACHE_WAY; ++test_line)
      if (valid[req_set][test_line] == 1 && tags[req_set][test_line] == req_tag) found_line = test_line;
  endtask

  // // Searches valid lines
  // function int find_line();
  //   find_line = -1;
  //   for (int found_line = 0; found_line < CACHE_WAY; ++found_line)
  //     if (valid[set][found_line] == 0 && tags[set][found_line] == tag) find_line = found_line;
  // endfunction

  // Searches all lines and find LRU one
  // function int find_substitution_line();
  //   find_line = -1;
  //   for (int found_line = 0; found_line < CACHE_WAY; ++found_line)
  //     if (valid_dirty[set][found_line][1] == 0 && tags[set][found_line] == tag) find_line = found_line;
  // endfunction

  task invalidate_line(input [CACHE_SET_SIZE-1:0] set, input int line);
    $display("Invalidating line: set = %b, line = %0d | D: %0d", set, line, dirty[set][line]);
    // Если линия Dirty, то нужно сдампить её содержимое в Mem
    if (dirty[set][line]) begin
      fork
        begin
          #1; C1 = C1_NOP; #1;
        end
        #CACHE_HIT_DELAY;  // Минимум ждём столько времени, для реалистичности
        begin  // Отправка данных в Mem
          C2 = C2_WRITE_LINE;
          A2[CACHE_TAG_SIZE+CACHE_SET_SIZE-1:CACHE_SET_SIZE] = tags[set][line];
          A2[CACHE_SET_SIZE-1:0] = set;

          for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += 2) begin
            send_bytes_D2(data[set][line][bbytes_start], data[set][line][bbytes_start + 1]);
            if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
          end

          #1;
          `close_bus2;
          wait(C2_WIRE == C2_RESPONSE);
          $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);
        end
      join

      reset_line(set, line);  // В конце очистить линию
    end
  endtask

  task find_spare_line();  // duration: TODO tacts
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

  task handle_c1_read(int read_bits);
    $display("[%3t | CLK=%0d] Cache: C1_READ%0d, A1 = %b", $time, $time % 2, read_bits, A1_WIRE);
    listening_bus1 = 0; parse_A1();

    if (found_line == -1) begin
      $display("Line not found, reading from Mem");
      fork
        begin
          #1; C1 = C1_NOP; #1;
        end
        begin // Надо найти свободную линию, пойти в Mem, прочитать строчку и сохранить её
          #CACHE_MISS_DELAY;

          find_spare_line();
          tags[req_set][found_line] = req_tag;

          #2;  // Надо подождать 1 такт, так как на текущем такте MemCTR ещё только послал RESPONSE, владение к нам перейдёт через пол такта
          C2 = C2_READ_LINE; redirect_address();
          #1;
          `close_bus2;
          wait(C2_WIRE == C2_RESPONSE);
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
        end
      join
    end else begin
      $display("Found line #%0d", found_line);
      fork
        begin
          #1; C1 = C1_NOP; #1;
        end
        #CACHE_HIT_DELAY;
      join
    end

    LRU_bit[req_set][found_line] = 1;
    LRU_bit[req_set][!found_line] = 0;

    // Оправляем данные в CPU, помня про little-endian, то есть сначала идёт третий байт, потом второй, потом первый
    C1 = C1_RESPONSE;
    case (read_bits)
      8: send_bytes_D1(data[req_set][found_line][req_offset], 0);
      16: send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
      32: begin
        send_bytes_D1(data[req_set][found_line][req_offset], data[req_set][found_line][req_offset + 1]);
        #2 send_bytes_D1(data[req_set][found_line][req_offset + 2], data[req_set][found_line][req_offset + 3]);
      end
    endcase
    #1; `close_bus1; listening_bus1 = 1;  // Когда CLK -> 0, закрываем соединения
  endtask

  task handle_c1_write(int write_bits);
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

        if (found_line == -1) begin
          $display("Line not found");
          #1; C1 = C1_NOP; #1;
          #CACHE_HIT_DELAY;  // Для реалистичности
        end else begin
          $display("Found line #%0d", found_line);
          invalidate_line(req_set, found_line);
        end

        // На последнем такте работы отправляем C1_RESPONSE и, когда CLK -> 0, закрываем соединения
        C1 = C1_RESPONSE;
        #1; `close_bus1; listening_bus1 = 1;
      end
    endcase
  end
endmodule
