from parameters import *

TIME = 0


class CacheLine:
    tag = None
    LRU_bit = 0
    valid = dirty = False


class Cache:
    def __init__(self):
        self.lines = [[CacheLine() for _ in range(CACHE_WAY)] for _ in range(CACHE_SETS_COUNT)]
        self.hits = self.misses = 0

        self.read8 = self.read16 = lambda addr: self.access(addr)
        self.write32 = lambda addr: self.access(addr, True)

    def wait_clk(self, clk_value):
        global TIME
        if (TIME % 1) * 2 != clk_value:
            TIME += 0.5

    def read_line_from_MEM(self, tag, sset, line):
        global TIME
        self.lines[sset][line].tag = tag
        self.wait_clk(1)
        TIME += MEM_CTR_DELAY
        for bbytes_start in range(0, CACHE_LINE_SIZE, 2):
            TIME += 1
        TIME -= 1
        self.lines[sset][line].valid = True
        self.lines[sset][line].dirty = False

    def write_line_to_MEM(self):
        global TIME
        self.wait_clk(1)
        TIME += MEM_CTR_DELAY  # MemCTR

    def find_valid_line(self, tag, sset):
        for line in range(CACHE_WAY):
            if self.lines[sset][line].valid and self.lines[sset][line].tag == tag:
                return line

    def invalidate_line(self, sset, line):
        if self.lines[sset][line].dirty:
            self.write_line_to_MEM()
        self.lines[sset][line].valid = False

    def find_spare_line(self, sset):
        global TIME
        for line in range(CACHE_WAY):
            if not self.lines[sset][line].valid:
                TIME += 0.5
                return line

        for line in range(CACHE_WAY):
            if self.lines[sset][line].LRU_bit == 0:
                self.invalidate_line(sset, line)
                return line

    def access(self, addr, is_write=False):
        global TIME
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
            self.misses += 1
            TIME += CACHE_MISS_DELAY - 2
            found_line = self.find_spare_line(req_set)
            TIME += 0.5
            self.read_line_from_MEM(req_tag, req_set, found_line)
        else:
            self.hits += 1
            TIME += CACHE_HIT_DELAY - 2.5

        if is_write:
            self.lines[req_set][found_line].dirty = True

        self.lines[req_set][found_line].LRU_bit = 1
        self.lines[req_set][not found_line].LRU_bit = 0

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
    cache.hits, cache.hits + cache.misses,
    round(cache.hits * 100 / (cache.hits + cache.misses), 2) if cache.hits + cache.misses else 0
))
