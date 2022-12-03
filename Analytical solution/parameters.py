# Copy of src/parameters.sv

# Given parameters
CACHE_WAY = 2
CACHE_TAG_SIZE = 10
CACHE_LINE_SIZE = 16
CACHE_LINE_COUNT = 64
MEM_SIZE = 512 * 1024
# Calculated parameters
CACHE_SIZE = 1024
CACHE_SETS_COUNT = 32
CACHE_SET_SIZE = 5
CACHE_OFFSET_SIZE = 4
CACHE_ADDR_SIZE = 19
# BUS sizes
ADDR1_BUS_SIZE = 15
ADDR2_BUS_SIZE = 15
DATA_BUS_SIZE = 16
CTR1_BUS_SIZE = 3
CTR2_BUS_SIZE = 2

# Memory initialization seed
SEED = 225526

# Delays
CACHE_HIT_DELAY = 4
CACHE_MISS_DELAY = 6
MEM_CTR_DELAY = 100