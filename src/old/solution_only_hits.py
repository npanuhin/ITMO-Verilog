from parameters import *

TIME = cache_hits = cache_misses = 0


class Cache:
    def __init__(self):
        self.tags = [[None, None] for _ in range(CACHE_SETS_COUNT)]
        self.LRU_bit = [[0, 0] for _ in range(CACHE_SETS_COUNT)]
        self.valid = [[0, 0] for _ in range(CACHE_SETS_COUNT)]
        self.dirty = [[0, 0] for _ in range(CACHE_SETS_COUNT)]

    def read_line_from_MEM(self, tag, sset, line):
        self.tags[sset][line] = tag
        self.valid[sset][line] = 1
        self.dirty[sset][line] = 0

    def find_valid_line(self, tag, sset):
        found_line = -1
        for line in range(CACHE_WAY):
            if self.valid[sset][line] == 1 and self.tags[sset][line] == tag:
                found_line = line
        return found_line

    def invalidate_line(self, sset, line):
        self.valid[sset][line] = 0

    def find_spare_line(self, sset):
        found_line = -1
        for line in range(CACHE_WAY):
            if self.valid[sset][line] == 0:
                found_line = line

        if found_line == -1:
            for line in range(CACHE_WAY):
                if self.LRU_bit[sset][line] == 0:
                    found_line = line
            self.invalidate_line(sset, found_line)
        return found_line

    def read8(self, addr):
        global cache_hits, cache_misses

        addr = addr >> CACHE_OFFSET_SIZE  # Убираем offset
        req_tag = addr >> CACHE_SET_SIZE
        req_set = addr % (2 ** CACHE_SET_SIZE)
        found_line = self.find_valid_line(req_tag, req_set)

        if found_line == -1:
            cache_misses += 1
            found_line = self.find_spare_line(req_set)
            self.read_line_from_MEM(req_tag, req_set, found_line)
        else:
            cache_hits += 1

        self.LRU_bit[req_set][found_line] = 1
        self.LRU_bit[req_set][not found_line] = 0


cache = Cache()
# ---------------------------------------------------- Actual task -----------------------------------------------------

M = 64              # #define M 64
N = 60              # #define N 60
K = 32              # #define K 32

a = 0               # int8 a[M][K];
b = M * K           # int16 b[K][N];
c = b + 2 * K * N   # int32 c[M][N];

pa = a
pc = c
for y in range(M):
    for x in range(N):
        pb = b
        for k in range(K):
            cache.read8(pa + k)
            cache.read16(pb + 2 * x)
            pb += 2 * N
        cache.write32(pc + 4 * x)
    pa += K
    pc += 4 * N

print("Cache hits: {}/{} = {}%".format(
    cache_hits, cache_hits + cache_misses,
    round(cache_hits * 100 / (cache_hits + cache_misses), 2) if cache_hits + cache_misses else 0
))
