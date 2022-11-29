module Cache (
  input wire CLK,
  inout wire[ADDR1_BUS_SIZE-1:0] A1_WIRE,
  inout wire[DATA1_BUS_SIZE-1:0] D1_WIRE,
  inout wire[CTR1_BUS_SIZE-1 :0] C1_WIRE,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA2_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire C_DUMP
);
  `map_bus1; `map_bus2; // Initialize wires

  // Internal cache variables
  reg[7:0] data        [CACHE_SETS_COUNT] [CACHE_WAY] [CACHE_LINE_SIZE];
  reg[7:0] tags        [CACHE_SETS_COUNT] [CACHE_WAY];
  reg[1:0] valid_dirty [CACHE_SETS_COUNT] [CACHE_WAY];

  task reset_line(int cur_set, int cur_line);
    tags[cur_set][cur_line] = 0;  // For testing, should be 'x
    valid_dirty[cur_set][cur_line] = 1;  // For testing, should be 0
    for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)  // Optional
      data[cur_set][cur_line][bbyte] = $random(SEED) >> 16;  // For testing, should be 'x
  endtask

  task reset();
    for (int cur_set = 0; cur_set < CACHE_SETS_COUNT; ++cur_set)
      for (int cur_line = 0; cur_line < CACHE_WAY; ++cur_line)
        reset_line(cur_set, cur_line);
  endtask

  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_SET_SIZE-1:0] set;
  reg[CACHE_OFFSET_SIZE-1:0] offset;

  reg[CACHE_TAG_SIZE + CACHE_SET_SIZE - 1:0] mem_address;
  // reg[DATA2_BUS_SIZE-1:0] bus2_data;

  bit listening_bus1 = 1, listening_bus2 = 0;

  int found_line, tmp_start;

  // Initialization & RESET
  initial reset();
  always @(posedge RESET) reset();

  // Dumping
  always @(posedge C_DUMP)
    for (int cur_set = 0; cur_set < CACHE_SETS_COUNT; ++cur_set) begin
      $display("Set #%0d", cur_set);
      for (int cur_line = 0; cur_line < CACHE_WAY; ++cur_line) begin
        $write("Line #%0d (%0d): ", cur_line, cur_set * CACHE_WAY + cur_line);
        for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)
          $write("%b ", data[cur_set][cur_line][bbyte]);
        $display(
          "| TAG:%b | V:%d | D:%d",
          tags[cur_set][cur_line], valid_dirty[cur_set][cur_line][1], valid_dirty[cur_set][cur_line][0]
        );
      end
      $display();
    end

  // --------------------------------------------------- Main logic ----------------------------------------------------
  task handle_c1_read(int read_bits);
    // TODO
  endtask

  task handle_c1_write(int write_bits);
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
        listening_bus1 = 0;
        tag = `discard_last_n_bits(A1_WIRE, CACHE_SET_SIZE);
        set = `last_n_bits(A1_WIRE, CACHE_SET_SIZE);
        #2;
        offset = A1_WIRE;
        $display("[%3t | CLK=%0d] tag = %b, set = %b, offset = %b", $time, $time % 2, tag, set, offset);

        // Чтение окончено, приступаем к выполнению:
        // Найти в set-е линию с нужным tag
        found_line = -1;
        for (int cur_line = 0; cur_line < CACHE_WAY; ++cur_line)
          if (tags[set][cur_line] == tag) found_line = cur_line;

        if (found_line == -1) $display("Line not found");
        else begin
          $display("Found line #%0d, dirty = %d", found_line, valid_dirty[set][found_line][0]);
          // Если линия Dirty, то нужно сдампить содержимое в Mem
          if (valid_dirty[set][found_line][0]) begin
            fork
              #1 C1 = C1_NOP;
              begin  // Отправка данных в Mem
                C2 = C2_WRITE_LINE;
                mem_address = tag;
                mem_address = (mem_address << CACHE_SET_SIZE) + set;
                A2 = mem_address;
                for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte)  // Debug
                  $display("Sending byte: %d = %b", data[set][found_line][bbyte], data[set][found_line][bbyte]);
                for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += DATA2_BUS_SIZE_BYTES) begin
                  for (int bbyte = 0; bbyte < DATA2_BUS_SIZE_BYTES; ++bbyte) begin
                    // Передать данные в little-endian, то есть {пример для двух байт} вначале (слева) идёт второй байт ([15:8]), потом (справа) первый ([7:0])
                    // Тогда D1 = (второй байт, первый байт) -> второй байт = D2[15:8], первый байт = D2[7:0]
                    // Примеры:
                    // байт(bbytes_start + bbyte) -> D2[pos_left:pos_right]
                    // 0 + 0 -> [7:0]
                    // 0 + 1 -> [15:8]
                    // 1 + 0 -> [7:0]
                    // 1 + 1 -> [15:8]
                    // 2 + 0 -> [7:0]
                    // 2 + 1 -> [15:8]
                    // Тогда: байт [bbytes_start + bbyte] нужно записать в D2[bbyte * 8 + 7:bbyte * 8]
                    // Пример: отправялем два байта reg byte1 = 236 (11101100); reg byte2 = 122 (01111010)
                    // Тогда отправится reg D2 = 01111010|11101100 - конкатенация двух байтов
                    for (int i = 0; i < 8; ++i) begin
                      // $display("D2[%2d] = data[%0d][%0d][%0d + %0d][%0d] = %b", bbyte * 8 + i, set, found_line, bbytes_start, bbyte, i, data[set][found_line][bbytes_start + bbyte][i]);
                      D2[bbyte * 8 + i] = data[set][found_line][bbytes_start + bbyte][i];
                    end
                  end
                  $display("[%3t | CLK=%0d] D2 <- %b", $time, $time % 2, D2);
                  if (bbytes_start + DATA2_BUS_SIZE_BYTES < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
                end

                #1;
                `close_bus2;
                wait(C2_WIRE == C2_RESPONSE);
                $display("[%3t | CLK=%0d] Cache received C2_RESPONSE", $time, $time % 2);
              end
            join

            reset_line(set, found_line);  // В конце очистить линию
          end
        end

        // На последнем такте работы отправляем C1_RESPONSE и, когда CLK -> 0, закрываем соединения
        C1 = C1_RESPONSE;
        #1; `close_bus1; `close_bus2; listening_bus1 = 1;
      end
    endcase

    // if (listening_bus2) case (C2_WIRE)
    //   C2_NOP: $display("[%3t | CLK=%0d] Cache: C2_NOP", $time, $time % 2);

    //   C2_RESPONSE: begin
    //     $display("[%3t | CLK=%0d] Cache: C2_RESPONSE", $time, $time % 2);
    //     // TODO
    //   end
    // endcase
  end
endmodule
