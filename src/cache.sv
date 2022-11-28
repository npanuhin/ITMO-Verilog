class CacheLine;
  reg valid;
  reg dirty;
  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[7:0] data[CACHE_LINE_SIZE-1:0];

  function new();
    reg[7:0] tmp_elem;
    for (int i = 0; i < CACHE_LINE_SIZE; ++i) begin // Weird array initialization
      tmp_elem = this.data[i];
      tmp_elem = $random(SEED) >> 16; // random is for testing, should be 'x
    end
    this.reset();
  endfunction

  function void reset();
    this.valid = 0;
    this.dirty = 0;
    this.tag = '0;  // '0 is for testing, should be 'x
  endfunction

  function void display();
    $display("%b | TAG:%b | V:%d | D:%d", this.data, this.tag, this.valid, this.dirty);
  endfunction
endclass


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
  CacheLine sets [0:CACHE_SETS_COUNT] [0:CACHE_WAY];  // Total 32 * 2 = 64 cache lines (CACHE_LINE_COUNT)
  CacheLine tmp_set [0:CACHE_WAY];
  CacheLine tmp_line = null, current_line = null;

  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_SET_SIZE-1:0] set;
  reg[CACHE_OFFSET_SIZE-1:0] offset;

  reg[CACHE_TAG_SIZE + CACHE_SET_SIZE - 1:0] mem_address;
  reg[DATA2_BUS_SIZE-1:0] bus2_data;

  bit listening_bus1 = 1, listening_bus2 = 0;
  // integer set_iterator, line_iterator;

  // Initialization
  initial begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; ++set_iterator)
      for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator)
        sets[set_iterator][line_iterator] = new ();
  end

  // Dumping
  always @(posedge C_DUMP) begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; ++set_iterator) begin
      $display("Set #%0d", set_iterator);
      for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
        $write("Line #%0d (%0d): ", line_iterator, set_iterator * CACHE_WAY + line_iterator);
        tmp_line = sets[set_iterator][line_iterator];
        tmp_line.display();
      end
      $display();
    end
  end

  // Reset
  always @(posedge RESET) begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; ++set_iterator) begin
      for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
        tmp_line = sets[set_iterator][line_iterator];
        tmp_line.reset();
      end
    end
  end

  // Main logic
  always @(posedge CLK) begin
    if (listening_bus1) case (C1_WIRE)
        C1_NOP: $display("[%2t | CLK=%0d] Cache: C1_NOP", $time, $time % 2);

        C1_INVALIDATE_LINE: begin
          $display("[%2t | CLK=%0d] Cache: C1_INVALIDATE_LINE, A1 = %b", $time, $time % 2, A1_WIRE);
          listening_bus1 = 0;

          // Прочитать адрес с A1
          tag = A1_WIRE >> CACHE_SET_SIZE;
          set = A1_WIRE % CACHE_SET_SIZE;
          #2;
          offset = A1_WIRE % CACHE_OFFSET_SIZE;

          $display("tag = %b, set = %b, offset = %b", tag, set, offset);

          // Найти в sets[set] линию с нужным tag
          current_line = null;
          for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
            tmp_line = sets[set][line_iterator];
            if (tmp_line.tag == tag) current_line = tmp_line;
          end

          if (current_line == null) $display("Line not found");
          else begin
            // Если линия Dirty, то нужно сдампить содержимое в Mem
            $display("Found line, dirty = %d", current_line.dirty);
            // if (current_line.dirty) begin  // Записать в память
              C2 = C2_WRITE_LINE;
              mem_address = tag;
              mem_address = (mem_address << CACHE_SET_SIZE) + set;
              A2 = mem_address;
              for (int bbyte = 0; bbyte < CACHE_LINE_SIZE; ++bbyte) begin
                $display("Sending byte: %d", current_line.data[bbyte]);
              end
              // Передать данные в little-endian
              // DATA2_BUS_SIZE - ширина шины в байтах
              for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += DATA2_BUS_SIZE / 8) begin
                for (int bbyte = 0; bbyte < DATA2_BUS_SIZE / 8; ++bbyte) begin
                  // Little-endian, то есть (пример для двух байт) надо сначала отправить второй байт, потом первый
                  // D1 = (первый байт, второй байт) -> первый байт: [15:8], второй байт [7:0]
                  // Байт [bbytes_start + bbyte] нужно записать в bus2_data[8 * (bbyte + 1) - 1: 8 * bbyte]
                  // 0 + 0 -> [7:0]
                  // 0 + 1 -> [15:8]
                  // 1 + 0 -> [7:0]
                  // 1 + 1 -> [15:8]
                  // 2 + 0 -> [7:0]
                  // 2 + 1 -> [15:8]
                  // Гипотетичиски: 100 + 2 = [23:16], 100 + 3 = [31:24]
                  for (int i = 8 * (bbyte + 1) - 1; i < 8 * bbyte; ++i) begin
                    bus2_data[i] = current_line.data[bbytes_start + bbyte][i];
                  end
                  // integer bla = 8 * (bbyte + 1) - 1;
                  // integer blabla = 8 * bbyte;
                  // bus2_data[bla:blabla] = current_line.data[bbytes_start + bbyte];
                end
                D2 = bus2_data;
                if (bbytes_start + DATA2_BUS_SIZE / 8 < CACHE_LINE_SIZE) #2;
              end
            // end

            current_line.reset(); // В конце очистить линию
          end
          #1 listening_bus1 = 1;  // Finish when CLK -> 0
        end

        // TODO: Other commands
      endcase

    if (listening_bus2) case (C2_WIRE)
        C2_NOP: $display("[%2t | CLK=%0d] Cache: C2_NOP", $time, $time % 2);

        C2_RESPONSE: begin
          $display("[%2t | CLK=%0d] Cache: C2_RESPONSE", $time, $time % 2);
          // TODO
        end
      endcase
  end
endmodule
