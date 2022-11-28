// Given parameters
localparam CACHE_WAY = 2;
localparam CACHE_TAG_SIZE = 10;    // [бит]
localparam CACHE_LINE_SIZE = 16;   // [байт]  16 байт
localparam CACHE_LINE_COUNT = 64;
localparam MEM_SIZE = 512 * 1024;  // [байт] 512 Кбайт
// Calculated parameters
localparam CACHE_SIZE = 1024;      // [байт] CACHE_LINE_SIZE × CACHE_LINE_COUNT
localparam CACHE_SETS_COUNT = 32;  //        CACHE_LINE_COUNT / CACHE_WAY
localparam CACHE_SET_SIZE = 5;     // [бит]  log(CACHE_SETS_COUNT)
localparam CACHE_OFFSET_SIZE = 7;  // [бит]  log(CACHE_LINE_SIZE)
localparam CACHE_ADDR_SIZE = 22;   // [бит]  log(MEM_SIZE)
// BUS sizes
localparam ADDR1_BUS_SIZE = 15;
localparam ADDR2_BUS_SIZE = 15;
localparam DATA1_BUS_SIZE = 16;
localparam DATA2_BUS_SIZE = 16;
localparam CTR1_BUS_SIZE  = 3;  // 0..7
localparam CTR2_BUS_SIZE  = 2;  // 0..3

// Memory initialization seed
integer SEED = 225526;

// Delays
localparam MEM_CTR_DELAY = 100;
