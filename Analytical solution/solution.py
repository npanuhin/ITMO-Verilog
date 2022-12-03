from parameters import *

TIME = cache_hits = cache_misses = 0


class Cache:
    def __init__(self):
        self.tags = [[None] * CACHE_WAY for _ in range(CACHE_SETS_COUNT)]
        self.LRU_bit = [[0] * CACHE_WAY for _ in range(CACHE_SETS_COUNT)]
        self.valid = [[0] * CACHE_WAY for _ in range(CACHE_SETS_COUNT)]
        self.dirty = [[0] * CACHE_WAY for _ in range(CACHE_SETS_COUNT)]

        self.read8 = self.read16 = lambda addr: self.access(addr)
        self.write32 = lambda addr: self.access(addr, True)

    def wait_clk(self, clk_value):
        global TIME
        if (TIME % 1) * 2 != clk_value:
            TIME += 0.5

    def read_line_from_MEM(self, tag, sset, line):
        global TIME
        self.tags[sset][line] = tag
        self.wait_clk(1)
        TIME += MEM_CTR_DELAY
        for bbytes_start in range(0, CACHE_LINE_SIZE, 2):
            TIME += 1
        TIME -= 1
        self.valid[sset][line] = 1
        self.dirty[sset][line] = 0

    def write_line_to_MEM(self):
        global TIME
        self.wait_clk(1)
        TIME += MEM_CTR_DELAY  # MemCTR

    def find_valid_line(self, tag, sset):
        found_line = None
        for line in range(CACHE_WAY):
            if self.valid[sset][line] == 1 and self.tags[sset][line] == tag:
                found_line = line
        return found_line

    def invalidate_line(self, sset, line):
        if self.dirty[sset][line]:
            self.write_line_to_MEM()
        self.valid[sset][line] = 0

    def find_spare_line(self, sset):
        global TIME
        found_line = None
        for line in range(CACHE_WAY):
            if self.valid[sset][line] == 0:
                found_line = line

        if found_line is None:
            for line in range(CACHE_WAY):
                if self.LRU_bit[sset][line] == 0:
                    found_line = line
            self.invalidate_line(sset, found_line)
        else:
            TIME += 0.5
        return found_line

    def access(self, addr, is_write=False):
        global TIME, cache_hits, cache_misses
        self.wait_clk(0)  # To send command
        self.wait_clk(1)  # To receive command
        # req_offset = addr % (2 ** CACHE_OFFSET_SIZE)
        addr = addr >> CACHE_OFFSET_SIZE
        req_tag = addr >> CACHE_SET_SIZE
        req_set = addr % (2 ** CACHE_SET_SIZE)
        found_line = self.find_valid_line(req_tag, req_set)
        TIME += 1  # parse_A1
        TIME += 0.5  # C1_NOP

        if found_line is None:
            cache_misses += 1
            TIME += CACHE_MISS_DELAY - 2
            found_line = self.find_spare_line(req_set)
            TIME += 0.5
            self.read_line_from_MEM(req_tag, req_set, found_line)
        else:
            cache_hits += 1
            TIME += CACHE_HIT_DELAY - 2.5

        if is_write:
            self.dirty[req_set][found_line] = 1

        self.LRU_bit[req_set][found_line] = 1
        self.LRU_bit[req_set][not found_line] = 0

        TIME += 0.5  # C1_RESPONSE
        # В READ send_bytes не нужен, так как посылаем либо 8, либо 16 бит, одновременно с C1_RESPONSE
        self.wait_clk(1)
        TIME += 0.5  # // Wait for CLK -> 0


cache = Cache()

# ---------------------------------------------------- Actual task -----------------------------------------------------


def assign(value):
    global TIME
    TIME += 1
    return value


def add(target, value):
    global TIME
    TIME += 1
    return target + value


M = 64              # #define M 64
N = 60              # #define N 60
K = 32              # #define K 32

a = 0               # int8 a[M][K];
b = M * K           # int16 b[K][N];
c = b + 2 * K * N   # int32 c[M][N];

pa = assign(a)
pc = assign(c)
for y in range(M):
    for x in range(N):
        pb = assign(b)
        s = assign(0)
        for k in range(K):
            cache.read8(pa + k)
            cache.read16(pb + 2 * x)
            TIME += 5 + 1  # 1 умножение и 1 сложение
            pb = add(pb, 2 * N)
            TIME += 1  # end of "for"
        cache.write32(pc + 4 * x)
        TIME += 1  # end of "for"
    pa = add(pa, K)
    pc = add(pc, 4 * N)
    TIME += 1  # end of "for"

TIME += 1  # end of function

print(f"Total time: {TIME} tacts")
print("Cache hits: {}/{} = {}%".format(
    cache_hits, cache_hits + cache_misses,
    round(cache_hits * 100 / (cache_hits + cache_misses), 2) if cache_hits + cache_misses else 0
))
