// Given parameters
localparam MEM_SIZE = 512 * 1024;  // 512 Кбайт
localparam CACHE_WAY = 2;
localparam CACHE_TAG_SIZE = 10;
localparam CACHE_LINE_SIZE = 16;
localparam CACHE_LINE_COUNT = 64;
// Calculated parameters
localparam CACHE_SIZE = 1024;      // CACHE_LINE_COUNT * CACHE_LINE_SIZE
localparam CACHE_SETS_COUNT = 32;  // CACHE_LINE_COUNT / CACHE_WAY
localparam CACHE_SET_SIZE = 9;     // log(CACHE_SETS_COUNT)
localparam CACHE_OFFSET_SIZE = 4;  // log(CACHE_LINE_SIZE)
localparam CACHE_ADDR_SIZE = 19;   // log(MEM_SIZE)
// BUS sizes
localparam ADDR1_BUS_SIZE = 19;
localparam ADDR2_BUS_SIZE = 19;
localparam DATA1_BUS_SIZE = 16;
localparam DATA2_BUS_SIZE = 16;
localparam CTR1_BUS_SIZE  = 3;     // 0..7
localparam CTR2_BUS_SIZE  = 2;     // 0..3
