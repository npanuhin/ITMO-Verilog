<h1 align="center">CPU-Cache-Mem on Verilog</h1>
<h4 align="center">Homework on CPU-Cache-Mem modeling in Verilog for the Computer Architecture course at ITMO University</h4>

- [Report (in Russian)](https://github.com/npanuhin/ITMO-Verilog/blob/master/report/report.pdf?raw=true)


### Полезные ссылки:

**Общее про кеш на Verilog:**
- Habr: [Имплементация кэша на Verilog](https://habr.com/ru/post/461611/)
- [Simple direct-mapped cache simulation on FPGA](https://github.com/psnjk/SimpleCache)
- YouTube: [Как работает Кэш](https://youtu.be/7n_8cOBpQrg)

**Разное:**
- Как работать с `inout`: https://www.fpga4student.com/2017/05/how-to-write-verilog-testbench-for.html


### Рассчёт констант
**Все уравнения:**
```
CACHE_SIZE = CACHE_LINE_SIZE × CACHE_LINE_COUNT
CACHE_SETS_COUNT = CACHE_LINE_COUNT / CACHE_WAY
CACHE_SET_SIZE = log2(CACHE_SETS_COUNT)
CACHE_OFFSET_SIZE = log2(CACHE_LINE_SIZE)
CACHE_ADDR_SIZE = log2(MEM_SIZE) = CACHE_TAG_SIZE + CACHE_SET_SIZE + CACHE_OFFSET_SIZE
```

**Размеры шин:**
```
ADDR1_BUS_SIZE = max(CACHE_TAG_SIZE + CACHE_SET_SIZE, CACHE_OFFSET_SIZE)
ADDR2_BUS_SIZE = CACHE_TAG_SIZE + CACHE_SET_SIZE
CTR1_BUS_SIZE = 3 | потому что коды команд 0..7
CTR2_BUS_SIZE = 2 | потому что коды команд 0..3
```
