class CacheLine;
  reg valid;
  reg dirty;
  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_LINE_SIZE-1:0] data;

  function new();
    this.reset();
  endfunction

  function void reset();
    this.valid = 0;
    this.dirty = 1;
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
  bit working = 0;
  reg[CACHE_TAG_SIZE:0] tag;
  reg[CACHE_SET_SIZE:0] set;
  reg[CACHE_OFFSET_SIZE:0] offset;
  // integer set_iterator, line_iterator;

  // Initialization
  initial begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; ++set_iterator) begin
      for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
        sets[set_iterator][line_iterator] = new ();
      end
    end
  end

  // Dumping
  always @(posedge C_DUMP) begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; ++set_iterator) begin
      $display("Set #%0d", set_iterator);
      for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
        $write("Line #%0d (%0d): ", line_iterator, set_iterator * CACHE_WAY + line_iterator);
        tmp_line = sets[set_iterator][line_iterator];
        tmp_line.display();
        tmp_line = null;
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
        tmp_line = null;
      end
    end
  end

  // Main logic
  always @(C1) begin
    if (!working) begin
      working = 1;
      if (C1 == C1_INVALIDATE_LINE) begin
        $display("Invalidating line");
        // Если линия Dirty, то записать в память
        // Затем очистить линию
        working = 1;

        // Прочитать адрес с A1
        tag = A1 >> CACHE_SET_SIZE;
        set = A1 % CACHE_SET_SIZE;
        #1;
        offset = A1 % CACHE_OFFSET_SIZE;

        // Найти в sets[set] линию с нужным tag
        current_line = null;
        for (int line_iterator = 0; line_iterator < CACHE_WAY; ++line_iterator) begin
          tmp_line = sets[set][line_iterator];
          if (tmp_line.tag == tag) begin
            current_line = tmp_line;
          end
        end
        tmp_line = null;

        // Если линия найдена
        if (current_line != null) begin
          if (current_line.dirty) begin
            // Записать в память
            C2 = C2_WRITE_LINE;
            A2 = tag << CACHE_SET_SIZE + set;
            // TODO D2
          end

          // Очистить линию
          current_line.reset();
        end
      end
      working = 0;
    end
  end
endmodule
