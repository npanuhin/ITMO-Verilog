class Cache:
    def __init__(self):
        pass

    def read8(self, addr):
        return 0

    def read16(self, addr):
        return 0

    def write32(self, addr, value):
        return 0


cache = Cache()

# ---------------------------------------------------- Actual task -----------------------------------------------------

tacts_passed, cache_hits, cache_misses = 0, 0, 0

M = 64              # #define M 64
N = 60              # #define N 60
K = 32              # #define K 32
a = 0               # int8 a[M][K];
b = M * K           # int16 b[K][N];
c = b + 2 * K * N   # int32 c[M][N];

pa = a
tacts_passed += 1
pc = c
tacts_passed += 1
for y in range(M):
    for x in range(N):
        pb = b
        tacts_passed += 1
        s = 0
        tacts_passed += 1
        for k in range(K):
            s += cache.read8(pa + k) * cache.read16(pb + 2 * x)
            tacts_passed += 5 + 1
            pb += 2 * N
            tacts_passed += 1
            tacts_passed += 1  # end of "for"
        cache.write32(pc + 4 * x, s)
        tacts_passed += 1  # end of "for"
    pa += K
    tacts_passed += 1
    pc += N
    tacts_passed += 1
    tacts_passed += 1  # end of "for"

tacts_passed += 1  # end of function

print(f"Total time: {tacts_passed} tacts")
print("Cache hits: {}/{} = {}%".format(
    cache_hits, cache_hits + cache_misses,
    round(cache_hits / (cache_hits + cache_misses), 2) if cache_hits + cache_misses else 0
))
