class CacheLine;
  reg valid = 0;
  reg dirty = 1;
  reg[CACHE_TAG_SIZE-1:0] tag;
  reg[CACHE_LINE_SIZE-1:0] data;

  function new();
    this.reset();
  endfunction

  function void reset();
    this.valid = 0;
    this.dirty = 0;
  endfunction
endclass


module Cache (
  input wire CLK,
  inout wire[ADDR1_BUS_SIZE-1:0] A1,
  inout wire[DATA1_BUS_SIZE-1:0] D1,
  inout wire[CTR1_BUS_SIZE-1 :0] C1,
  inout wire[ADDR2_BUS_SIZE-1:0] A2,
  inout wire[DATA2_BUS_SIZE-1:0] D2,
  inout wire[CTR2_BUS_SIZE-1 :0] C2,
  input wire RESET,
  input wire C_DUMP
);
  CacheLine sets [0:CACHE_SETS_COUNT] [0:CACHE_WAY];  // Total 32 * 2 = 64 cache lines (CACHE_LINE_COUNT)
  // integer set_iterator, line_iterator;
  CacheLine tmp_set [0:CACHE_WAY];
  CacheLine tmp_line;

  initial begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; set_iterator = set_iterator + 1) begin
      for (int line_iterator = 0; line_iterator < CACHE_WAY; line_iterator = line_iterator + 1) begin
        sets[set_iterator][line_iterator] = new ();
      end
    end
  end

  always @(posedge C_DUMP) begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; set_iterator = set_iterator + 1) begin
      $display("Set #%0d", set_iterator);
      for (int line_iterator = 0; line_iterator < CACHE_WAY; line_iterator = line_iterator + 1) begin
        tmp_line = sets[set_iterator][line_iterator];
        tmp_line.data = 256;
        $display("Line #%0d (%0d): %16b", line_iterator, set_iterator * CACHE_WAY + line_iterator, tmp_line.data);
      end
      $display();
    end
  end

  always @(posedge RESET) begin
    for (int set_iterator = 0; set_iterator < CACHE_SETS_COUNT; set_iterator = set_iterator + 1) begin
      for (int line_iterator = 0; line_iterator < CACHE_WAY; line_iterator = line_iterator + 1) begin
        tmp_line = sets[set_iterator][line_iterator];
        tmp_line.reset();
      end
    end
  end
endmodule
