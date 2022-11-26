### Полезные ссылки:
- Habr: [Имплементация кэша на Verilog](https://habr.com/ru/post/461611/)
- [Simple direct-mapped cache simulation on FPGA](https://github.com/psnjk/SimpleCache)
- YouTube: [Как работает Кэш](https://youtu.be/7n_8cOBpQrg)

### Рассчёт констант
**Все уравнения:**
```
CACHE_SIZE = CACHE_LINE_SIZE × CACHE_LINE_COUNT
CACHE_SETS_COUNT = CACHE_LINE_COUNT / CACHE_WAY
CACHE_SET_SIZE = log2(CACHE_SETS_COUNT)
CACHE_OFFSET_SIZE = log2(CACHE_LINE_SIZE)
CACHE_ADDR_SIZE = log2(MEM_SIZE) = CACHE_TAG_SIZE + CACHE_SET_SIZE
```

**Размеры шин:**
```
ADDR1_BUS_SIZE = min(CACHE_TAG_SIZE + CACHE_SET_SIZE, CACHE_OFFSET_SIZE)
ADDR2_BUS_SIZE = CACHE_TAG_SIZE + CACHE_SET_SIZE
CTR1_BUS_SIZE = 3, потому что коды команд 0..7
CTR2_BUS_SIZE = 2, потому что коды команд 0..3
```
